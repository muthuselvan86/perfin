> Historical session plan: schema details and bootstrap snippets below are superseded by [the ERD](../architecture/db-erd.md), [command reference](../commands.md), and `docker/postgres/init/01-roles.sql`. Do not execute these old setup snippets.

# perfin v2 — Session 1: Database schema (pair-programming, lead instructions)

## Context
We are rebuilding perfin as a new sibling repo `../perfin-v2`: React + TS + Redux Toolkit/RTK Query → Node/TS REST API → TS services → Prisma + PostgreSQL, deployed to AWS later (Lambda + RDS + Cognito). The current Next.js app in `perfin-manager` stays frozen as the functional reference. Reverted commit `b28a3ce` is **reference only**.

Working mode: I lead and give instructions; you run them and report back at each **Checkpoint**. This session covers only the database: repo skeleton, local Postgres with two roles, Prisma schema, first migration with DB-level guards, and seed data.

### Problems in the legacy schema this design fixes
| Legacy (`perfin-manager/prisma/schema.prisma`) | v2 decision |
|---|---|
| `Ledger`/`Goal` have no owner, so any logged-in user can see all of them | Every financial row has a required `userId`. Goal↔account links carry `userId` in **composite FKs**, so the DB itself rejects linking another user's account |
| Globally unique `assetName`, `bankAcctNo`, goal `name` | Unique **per user** |
| `NetworthHistory` has one column per category (`totalRetirementAccounts`…), matched by name string | `net_worth_snapshots` header + `net_worth_snapshot_lines` (one row per top-level category). Adding a category needs no migration |
| Duplicate snapshots per day | `UNIQUE(user_id, snapshot_date)` with a `DATE` column |
| `OwnerShip.share Decimal(3,2)` (1/3 → 0.33, loses cents) | Account-level `ownership_share DECIMAL(5,4)` (0 < s ≤ 1), preserved as a financial fact, **not** an access grant |
| Goal↔ledger link has no amount | `goal_allocations.amount` |
| No optimistic locking | `version INT` on mutable records |
| Category matched by display name; `ORG_NAMES` hard-coded enum | Stable category `code`; institution is free text |
| Auto-increment int IDs in URLs | UUIDv7 for user-owned records (small reference tables keep ints) |
| One DB user does everything | `perfin_migrator` (DDL) and `perfin_app` (DML only) |
| Passwords stored in the `user` table | No password column. Identity comes from Cognito (AWS) or a local dev issuer via `auth_subject` |

Deferred (not in this schema): `Investment`/holdings (portfolio/stocks pages), sharing tables, audit log. Legacy data ETL from the old DB is a later session.

---

## Step 1 — Repo skeleton
```bash
cd ~/Code/react-projects && mkdir perfin-v2 && cd perfin-v2 && git init
echo "22" > .nvmrc            # Node 22 LTS (Lambda nodejs22.x)
mkdir -p apps packages/db docker/postgres/init
```
Root `package.json`:
```json
{
  "name": "perfin-v2",
  "private": true,
  "workspaces": ["apps/*", "packages/*"],
  "scripts": {
    "db:up": "docker compose up -d db",
    "db:down": "docker compose down",
    "db:migrate": "npm -w @perfin/db run migrate:dev",
    "db:seed": "npm -w @perfin/db run seed",
    "db:studio": "npm -w @perfin/db run studio"
  }
}
```
`.gitignore`: `node_modules/`, `.env`, `*.backup`, `*.sql.gz`, `dist/`, `packages/db/src/generated/`.
`tsconfig.base.json`:
```json
{
  "compilerOptions": {
    "strict": true,
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "noUncheckedIndexedAccess": true,
    "skipLibCheck": true,
    "esModuleInterop": true
  }
}
```

## Step 2 — Local Postgres with two roles
`compose.yaml`:
```yaml
services:
  db:
    image: postgres:17-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: REPLACE_WITH_POSTGRES_PASSWORD
    ports: ["5432:5432"]
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./docker/postgres/init:/docker-entrypoint-initdb.d:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
volumes:
  pgdata:
```
`docker/postgres/init/01-roles.sql` runs only when the volume is first created:
```sql
CREATE ROLE perfin_migrator LOGIN CREATEDB PASSWORD 'REPLACE_WITH_PERFIN_MIGRATOR_PASSWORD'; -- CREATEDB: Prisma shadow DB
CREATE ROLE perfin_app      LOGIN PASSWORD 'REPLACE_WITH_PERFIN_APP_PASSWORD';
CREATE DATABASE perfin OWNER perfin_migrator;
\connect perfin
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO perfin_app;
ALTER DEFAULT PRIVILEGES FOR ROLE perfin_migrator IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO perfin_app;
ALTER DEFAULT PRIVILEGES FOR ROLE perfin_migrator IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO perfin_app;
```
`.env.example` (copy it to `.env`):
```
MIGRATION_DATABASE_URL=postgresql://perfin_migrator:REPLACE_WITH_PERFIN_MIGRATOR_PASSWORD@localhost:5432/perfin
DATABASE_URL=postgresql://perfin_app:REPLACE_WITH_PERFIN_APP_PASSWORD@localhost:5432/perfin
```
The Prisma CLI (migrations and seed) uses `MIGRATION_DATABASE_URL`. The running API uses only `DATABASE_URL`. The same split applies on RDS later.

**Checkpoint A:** `npm run db:up`, then `docker compose exec db psql -U postgres -c '\du'` should list both roles.

## Step 3 — `@perfin/db` package (Prisma 7)
```bash
cd packages/db && npm init -y   # set "name": "@perfin/db"
npm i @prisma/client @prisma/adapter-pg
npm i -D prisma tsx typescript dotenv @types/node
npx prisma --version            # expect 7.x; tell me if it prints 6.x
```
Scripts: `"generate": "prisma generate"`, `"migrate:dev": "prisma migrate dev"`, `"migrate:deploy": "prisma migrate deploy"`, `"seed": "prisma db seed"`, `"studio": "prisma studio"`, `"validate": "prisma validate"`.

`packages/db/prisma.config.ts`:
```ts
import { config } from 'dotenv';
import { defineConfig, env } from 'prisma/config';
config({ path: '../../.env' });
export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: { path: 'prisma/migrations', seed: 'tsx prisma/seed.ts' },
  datasource: { url: env('MIGRATION_DATABASE_URL') },
});
```

## Step 4 — `packages/db/prisma/schema.prisma`
```prisma
generator client {
  provider = "prisma-client"
  output   = "../src/generated/prisma"
}

datasource db {
  provider = "postgresql"
}

enum CategoryKind {
  ASSET
  LIABILITY
}

enum GoalStatus {
  NOT_STARTED
  IN_PROGRESS
  COMPLETED
  CANCELLED
}

enum ImportStatus {
  PREVIEWED
  APPLIED
  FAILED
  EXPIRED
}

enum ImportRowStatus {
  WILL_UPDATE
  UNCHANGED
  UNMATCHED
}

model User {
  id          String   @id @default(uuid(7)) @db.Uuid
  authSubject String   @unique @map("auth_subject") @db.VarChar(255) // Cognito `sub` or "local|alice"
  email       String   @unique @db.VarChar(320) // stored lower-cased by the service
  displayName String?  @map("display_name") @db.VarChar(120)
  createdAt   DateTime @default(now()) @map("created_at") @db.Timestamptz(3)
  updatedAt   DateTime @updatedAt @map("updated_at") @db.Timestamptz(3)

  accounts   Account[]
  goals      Goal[]
  snapshots  NetWorthSnapshot[]
  importJobs ImportJob[]

  @@map("users")
}

/// Global, seeded reference data. Top-level rows carry `kind`; accounts attach to children.
model Category {
  id        Int           @id @default(autoincrement())
  code      String        @unique @db.VarChar(40)
  name      String        @db.VarChar(80)
  kind      CategoryKind?
  parentId  Int?          @map("parent_id")
  sortOrder Int           @default(0) @map("sort_order")

  parent        Category?      @relation("CategoryTree", fields: [parentId], references: [id], onDelete: Restrict)
  children      Category[]     @relation("CategoryTree")
  accounts      Account[]
  snapshotLines SnapshotLine[]

  @@unique([parentId, name])
  @@map("categories")
}

model Account {
  id             String   @id @default(uuid(7)) @db.Uuid
  userId         String   @map("user_id") @db.Uuid
  categoryId     Int      @map("category_id")
  name           String   @db.VarChar(120)
  institution    String?  @db.VarChar(80)
  externalRef    String?  @map("external_ref") @db.VarChar(64) // brokerage account number, used by CSV import
  balance        Decimal  @db.Decimal(15, 2) // always >= 0; sign comes from category kind
  ownershipShare Decimal  @default(1) @map("ownership_share") @db.Decimal(5, 4)
  notes          String?  @db.VarChar(500)
  version        Int      @default(1)
  createdAt      DateTime @default(now()) @map("created_at") @db.Timestamptz(3)
  updatedAt      DateTime @updatedAt @map("updated_at") @db.Timestamptz(3)

  user        User             @relation(fields: [userId], references: [id], onDelete: Cascade)
  category    Category         @relation(fields: [categoryId], references: [id], onDelete: Restrict)
  allocations GoalAllocation[]
  importRows  ImportJobRow[]

  @@unique([id, userId]) // target of composite FKs
  @@unique([userId, name])
  @@unique([userId, externalRef])
  @@index([userId, categoryId])
  @@map("accounts")
}

model NetWorthSnapshot {
  id               String   @id @default(uuid(7)) @db.Uuid
  userId           String   @map("user_id") @db.Uuid
  snapshotDate     DateTime @map("snapshot_date") @db.Date
  totalAssets      Decimal  @map("total_assets") @db.Decimal(15, 2)
  totalLiabilities Decimal  @map("total_liabilities") @db.Decimal(15, 2)
  netWorth         Decimal  @map("net_worth") @db.Decimal(15, 2)
  version          Int      @default(1)
  createdAt        DateTime @default(now()) @map("created_at") @db.Timestamptz(3)
  updatedAt        DateTime @updatedAt @map("updated_at") @db.Timestamptz(3)

  user  User           @relation(fields: [userId], references: [id], onDelete: Cascade)
  lines SnapshotLine[]

  @@unique([userId, snapshotDate])
  @@map("net_worth_snapshots")
}

/// One row per top-level category in a snapshot (replaces the legacy total* columns).
model SnapshotLine {
  snapshotId String  @map("snapshot_id") @db.Uuid
  categoryId Int     @map("category_id")
  amount     Decimal @db.Decimal(15, 2)

  snapshot NetWorthSnapshot @relation(fields: [snapshotId], references: [id], onDelete: Cascade)
  category Category         @relation(fields: [categoryId], references: [id], onDelete: Restrict)

  @@id([snapshotId, categoryId])
  @@map("net_worth_snapshot_lines")
}

model Goal {
  id           String     @id @default(uuid(7)) @db.Uuid
  userId       String     @map("user_id") @db.Uuid
  name         String     @db.VarChar(120)
  targetAmount Decimal    @map("target_amount") @db.Decimal(15, 2)
  cashSaved    Decimal    @default(0) @map("cash_saved") @db.Decimal(15, 2)
  startDate    DateTime   @map("start_date") @db.Date
  targetDate   DateTime   @map("target_date") @db.Date
  status       GoalStatus @default(NOT_STARTED)
  version      Int        @default(1)
  createdAt    DateTime   @default(now()) @map("created_at") @db.Timestamptz(3)
  updatedAt    DateTime   @updatedAt @map("updated_at") @db.Timestamptz(3)

  user        User             @relation(fields: [userId], references: [id], onDelete: Cascade)
  allocations GoalAllocation[]

  @@unique([id, userId])
  @@unique([userId, name])
  @@map("goals")
}

/// userId appears in both composite FKs, so goal and account must belong to the same user.
model GoalAllocation {
  goalId    String   @map("goal_id") @db.Uuid
  accountId String   @map("account_id") @db.Uuid
  userId    String   @map("user_id") @db.Uuid
  amount    Decimal  @db.Decimal(15, 2)
  createdAt DateTime @default(now()) @map("created_at") @db.Timestamptz(3)
  updatedAt DateTime @updatedAt @map("updated_at") @db.Timestamptz(3)

  goal    Goal    @relation(fields: [goalId, userId], references: [id, userId], onDelete: Cascade)
  account Account @relation(fields: [accountId, userId], references: [id, userId], onDelete: Cascade)

  @@id([goalId, accountId])
  @@index([accountId])
  @@map("goal_allocations")
}

model ImportJob {
  id         String       @id @default(uuid(7)) @db.Uuid
  userId     String       @map("user_id") @db.Uuid
  status     ImportStatus @default(PREVIEWED)
  fileName   String       @map("file_name") @db.VarChar(255)
  fileSha256 String       @map("file_sha256") @db.Char(64)
  rowCount   Int          @map("row_count")
  errorCode  String?      @map("error_code") @db.VarChar(64)
  createdAt  DateTime     @default(now()) @map("created_at") @db.Timestamptz(3)
  appliedAt  DateTime?    @map("applied_at") @db.Timestamptz(3)
  expiresAt  DateTime     @map("expires_at") @db.Timestamptz(3)

  user User           @relation(fields: [userId], references: [id], onDelete: Cascade)
  rows ImportJobRow[]

  @@index([userId, createdAt(sort: Desc)])
  @@map("import_jobs")
}

/// One row per account number in the file, with amounts already summed.
/// accountVersion is the version seen at preview time; apply fails if it changed.
model ImportJobRow {
  id              String          @id @default(uuid(7)) @db.Uuid
  jobId           String          @map("job_id") @db.Uuid
  externalRef     String          @map("external_ref") @db.VarChar(64)
  accountId       String?         @map("account_id") @db.Uuid
  accountVersion  Int?            @map("account_version")
  previousBalance Decimal?        @map("previous_balance") @db.Decimal(15, 2)
  newBalance      Decimal         @map("new_balance") @db.Decimal(15, 2)
  status          ImportRowStatus

  job     ImportJob @relation(fields: [jobId], references: [id], onDelete: Cascade)
  account Account?  @relation(fields: [accountId], references: [id], onDelete: SetNull)

  @@unique([jobId, externalRef])
  @@map("import_job_rows")
}
```
**Checkpoint B:** `npm run validate -w @perfin/db` should pass. If `uuid(7)` is rejected, tell me your Prisma version.

## Step 5 — First migration + CHECK constraints (Prisma can't express CHECKs)
```bash
npx prisma migrate dev --create-only --name init   # from packages/db
```
Append this to the end of the generated `prisma/migrations/<ts>_init/migration.sql`:
```sql
ALTER TABLE categories ADD CONSTRAINT categories_kind_top_level
  CHECK ((parent_id IS NULL) = (kind IS NOT NULL));
ALTER TABLE accounts ADD CONSTRAINT accounts_balance_nonneg CHECK (balance >= 0);
ALTER TABLE accounts ADD CONSTRAINT accounts_share_range
  CHECK (ownership_share > 0 AND ownership_share <= 1);
ALTER TABLE accounts ADD CONSTRAINT accounts_version_pos CHECK (version >= 1);
ALTER TABLE goals ADD CONSTRAINT goals_target_pos CHECK (target_amount > 0);
ALTER TABLE goals ADD CONSTRAINT goals_cash_nonneg CHECK (cash_saved >= 0);
ALTER TABLE goals ADD CONSTRAINT goals_dates CHECK (target_date >= start_date);
ALTER TABLE goal_allocations ADD CONSTRAINT goal_alloc_nonneg CHECK (amount >= 0);
ALTER TABLE net_worth_snapshots ADD CONSTRAINT snapshots_math
  CHECK (total_assets >= 0 AND total_liabilities >= 0
         AND net_worth = total_assets - total_liabilities);
ALTER TABLE import_job_rows ADD CONSTRAINT import_rows_new_nonneg CHECK (new_balance >= 0);
```
Then apply it: `npx prisma migrate dev`. This also runs `generate`.

The API service layer will enforce these (not the DB): accounts may only attach to child categories, snapshot lines only to top-level ones, and a user's total allocations from one account may not exceed `balance × ownership_share`.

**Checkpoint C:** send me the output of `docker compose exec db psql -U postgres -d perfin -c '\dt'` and `... -c '\d goal_allocations'`. I want to see both composite FKs.

## Step 6 — Client factory + seed
`packages/db/src/client.ts`:
```ts
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from './generated/prisma/client.js';

export function createPrismaClient(connectionString: string, poolMax = 5) {
  return new PrismaClient({ adapter: new PrismaPg({ connectionString, max: poolMax }) });
}
export * from './generated/prisma/client.js';
```
(On Lambda we'll pass `poolMax = 1` and cache one client per warm container.)

`packages/db/prisma/seed.ts` must be idempotent (upserts):
1. **Always:** categories. Use the 7 top-level categories from `perfin-manager/app/lib/placeholder-data.js` with codes `CASH, INVESTMENTS, RETIREMENT, PERSONAL_PROPERTY, REAL_ESTATE, FOREIGN, LIABILITIES` (kind ASSET, except LIABILITIES) and their children with codes like `CASH_CHECKING`. Upsert by `code`.
2. **Only when `SEED_DEMO=true`:** synthetic users `alice@example.test` (`local|alice`) and `bob@example.test` (`local|bob`). Give each 3–4 accounts (one liability, one with `ownershipShare 0.5`), one goal with an allocation, and one snapshot. **No real names, emails or account numbers.**

Run it with `SEED_DEMO=true npm run db:seed`, twice, to confirm it's idempotent.

## Verification (Checkpoint D — run these in psql as `perfin_app`)
`docker compose exec db psql "postgresql://perfin_app:REPLACE_WITH_PERFIN_APP_PASSWORD@localhost:5432/perfin"`
1. `SELECT count(*) FROM categories;` returns the seeded count (the app role can read).
2. `CREATE TABLE x(id int);` is rejected: the app role has no DDL.
3. Insert a `goal_allocations` row using Alice's goal id and Bob's account id with Alice's user_id: **FK violation**.
4. `UPDATE accounts SET balance = -1 ...` fails with a **check violation**.
5. Inserting a second snapshot for the same user and date fails with a **unique violation**.
6. `UPDATE accounts SET ownership_share = 1.5 ...` fails with a **check violation**.

Then commit: `git add -A && git commit -m "db: initial v2 schema, roles, seed"`.

## Next sessions (for orientation, not now)
2. `packages/core`: decimal money helpers, net-worth and snapshot math, goal projections (port of `app/lib/utils.ts` FV/PMT), CSV parser. Vitest.
3. `apps/api`: HTTP framework choice, auth middleware (local JWT issuer, later Cognito), `/v1/me`, `/v1/accounts` with user-scoped repository and version checks. Integration tests against disposable Postgres.
4. Remaining endpoints → 5. Vite + RTK Query frontend → 6. Legacy data ETL from the old DB → 7. Terraform/Lambda image.
