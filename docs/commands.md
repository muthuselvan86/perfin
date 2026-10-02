# Development command reference

Living reference for perfin-v2. Last checked: 2026-10-01. Update this document in the same change that adds, renames, or removes an npm script, changes Prisma/Compose configuration, or introduces a new development workflow.

## Working directories and current status

Project root:

```bash
cd /Users/muthuselvan/Code/react-projects/perfin-v2
```

Database package:

```bash
cd /Users/muthuselvan/Code/react-projects/perfin-v2/packages/db
```

Commands below specify their working directory. npm workspace commands run the package script from its package directory. This matters because `prisma.config.ts` loads the root `.env` using `../../.env`.

Current configuration:

- Prisma CLI, Client, and PostgreSQL adapter: pinned to 7.10.0.
- Schema: `packages/db/schema.prisma` (not `packages/db/prisma/schema.prisma`).
- Config: `packages/db/prisma.config.ts`.
- Migration directory configured as `packages/db/prisma/migrations`.
- Seed command configured as `tsx prisma/seed.ts`.
- The initial migration and `prisma/seed.ts` exist. Apply reviewed migrations before seeding. See [seeding instructions](seeding.md).
- The DB package has type checking and a read-only connection check. No application dev/build/lint/test scripts exist yet. Add their commands here when implemented.

## Root npm scripts

Run from the project root.

| Command | What it does | Effect |
|---|---|---|
| `npm run db:check` | Checks application-role connectivity, public-schema CREATE privilege and table counts | Read-only database transaction; no financial values printed |
| `npm run db:up` | Starts PostgreSQL in the background | Starts container; first use initializes a new empty volume |
| `npm run db:down` | Runs `docker compose down` | Stops/removes the default Compose stack; preserves named volumes; use the explicit tools-profile command below to include pgAdmin |
| `npm run db:migrate` | Runs DB package `prisma migrate dev` | Applies pending migrations and may generate/apply schema changes; not a preview command |
| `npm run db:seed` | Runs the configured Prisma seed | Writes missing reference data; optional synthetic demo |
| `npm run db:studio` | Opens Prisma Studio | Database viewer/editor; edits write to the database |
| `npm run pgadmin:up` | Starts pgAdmin and its PostgreSQL dependency | Starts containers; console at http://localhost:5050 |
| `npm run pgadmin:down` | Stops pgAdmin only | Preserves console settings and PostgreSQL |
| `npm run pgadmin:status` | Shows pgAdmin container status | Inspection only |
| `npm run pgadmin:logs` | Follows the latest 100 log lines | Inspection only; Ctrl+C stops following logs |

## Database package npm scripts

Run these forms from the project root, or run `npm run SCRIPT` inside `packages/db`.

| Root command | Prisma command | Effect |
|---|---|---|
| `npm -w @perfin/db run typecheck` | `tsc -p tsconfig.json` | Strict TypeScript check; no files emitted |
| `npm -w @perfin/db run check:connection` | `tsx scripts/check-connection.ts` | Same read-only check as root `db:check` |
| `npm -w @perfin/db run validate` | `prisma validate` | Validates schema/config; no table changes |
| `npm -w @perfin/db run generate` | `prisma generate` | Writes generated client files; no table changes |
| `npm -w @perfin/db run migrate:dev` | `prisma migrate dev` | Development schema migration; may prompt for reset on drift |
| `npm -w @perfin/db run migrate:deploy` | `prisma migrate deploy` | Applies existing pending migration files; does not generate a new migration |
| `npm -w @perfin/db run seed` | `prisma db seed` | Executes the seed implementation using DATABASE_URL |
| `npm -w @perfin/db run studio` | `prisma studio` | Starts an interactive database viewer/editor |

Prisma CLI commands use `MIGRATION_DATABASE_URL` in the current config, including Studio. Therefore Studio currently opens with migration-role privileges. pgAdmin's preconfigured connection uses `perfin_app` instead. A future application client should explicitly use `DATABASE_URL`.

## Direct Prisma commands

Run from `packages/db` using the installed, pinned CLI.

| Command | Purpose | Changes |
|---|---|---|
| `npx prisma --version` | Show installed Prisma versions | None |
| `npx prisma format` | Format schema | Schema file |
| `npx prisma validate` | Validate Prisma schema | None to database |
| `npx prisma generate` | Generate typed client | Generated files |
| `npx prisma migrate status` | Compare migration files with migration history | Inspection only |
| `npx prisma migrate dev --name family_networth_core --create-only` | Generate the initial migration for review | Migration files; development/shadow DB work may occur, but the newly generated migration is not applied |
| `npx prisma migrate dev` | Apply development migrations and reconcile schema | Database and possibly migration files |
| `npx prisma migrate deploy` | Apply committed pending migrations | Database |
| `npx prisma db seed` | Run the configured seed | Data according to seed implementation |
| `npx prisma studio` | Open database UI | Edits in UI can change data |

Prisma 7 does not automatically run client generation or seeding during `migrate dev`. Run them explicitly when needed. `generate` writes to the generator output directory, relative to the schema file; the intended package-local path is `./src/generated/prisma` for the current schema location.

## Schema change workflow: pause at each review checkpoint

1. Edit `packages/db/schema.prisma` according to [the ERD](architecture/db-erd.md).
2. From `packages/db`, validate the source:

   ```bash
   npx prisma format
   npm run validate
   ```

   Checkpoint A: review models, relation behavior, unique keys, and indexes. Schema validation does not test financial calculations or database constraints.

3. Verify `.env` targets the isolated V2 database and that the migrator has suitable shadow-database access. Start PostgreSQL from the root with `npm run db:up`.
4. From `packages/db`, generate a migration for review:

   ```bash
   npx prisma migrate dev --name family_networth_core --create-only
   ```

   For later changes, use a descriptive new migration name. Inspect generated SQL and add the reviewed CHECK constraints. This command may interact with a shadow database and apply earlier pending migrations; it is not a general read-only command. If Prisma requests a reset, stop and investigate rather than accepting it automatically.

   Checkpoint B: review migration SQL before applying the new migration.

5. After review, from `packages/db`:

   ```bash
   npx prisma migrate dev
   npm run generate
   npx prisma migrate status
   ```

6. Run `npm run db:seed` from the root for reference data only. Optionally use `SEED_DEMO=true npm run db:seed` for a synthetic family. See [seeding instructions](seeding.md).
7. Run the relevant tests once test scripts exist. Review and commit schema, migration SQL, and documentation together. Do not commit credentials or generated client output.

In deployment, use `migrate deploy` from a dedicated migration job, not `migrate dev` or application startup.

## Docker inspection and shutdown

Run from the project root:

```bash
# Validate Compose without printing expanded credentials.
docker compose --profile tools config --quiet

# Inspect containers and PostgreSQL logs.
docker compose --profile tools ps
docker compose logs --tail=100 db

# Stop just PostgreSQL, retaining its container and volume.
docker compose stop db

# Stop/remove both services, preserving named volumes.
docker compose --profile tools down
```

Do not use `docker compose down -v` as a normal stop command: it removes named volumes, including database data and pgAdmin settings.

## Inspect tables using psql

From the project root:

```bash
docker compose exec db psql -U perfin_app -d perfin -W
```

Enter the database password when prompted. Inside psql:

```sql
\conninfo
SELECT current_database(), current_user, current_schema();
\dn
\dt public.*
\d+ public.accounts
\d+ public.account_ownerships
\d+ public.net_worth_snapshots
\dp public.*
\q
```

New tables appear only after their migration is applied. These inspection commands do not create or modify tables.

## pgAdmin console

See [pgAdmin setup and login instructions](pgadmin.md).

- Console: http://localhost:5050 (bound to the Mac's loopback interface).
- Console login: `PGADMIN_DEFAULT_EMAIL` and `PGADMIN_DEFAULT_PASSWORD` in local `.env`.
- Preconfigured server: `Perfin V2 Local`, host `db`, port `5432`, database `perfin`, user `perfin_app`.
- Enter the application database password when connecting. It is separate from the console password.
- The persistent console account is initialized on first startup; editing `.env` later does not reset its password.

## Environment and connection contexts

| Variable | Used by |
|---|---|
| `MIGRATION_DATABASE_URL` | Prisma CLI via `prisma.config.ts`; migration-role credentials |
| `DATABASE_URL` | Intended application client; application-role credentials |
| `PGADMIN_DEFAULT_EMAIL` | Initial pgAdmin console login |
| `PGADMIN_DEFAULT_PASSWORD` | Initial pgAdmin console password |

From the Mac, PostgreSQL is reached through the published host port, currently `localhost:5432`. From pgAdmin on the Compose network, use `db:5432`. Recheck port ownership if the original application is also started.

Keep `.env` local. Do not print expanded Compose config or paste connection strings with passwords into logs or review discussions. URL-encode special password characters in database URLs.

## Commands outside the normal workflow

- `prisma migrate reset`: destroys data in the target development database before rebuilding it. Use only for an explicitly disposable database.
- `prisma db push`: changes the database without creating migration history. Do not use for this project's reviewed migration workflow.
- `prisma db pull`: introspects a database and can rewrite the local Prisma schema. It is not merely a status check.
- `docker compose down -v`: deletes persistent volumes.

## Maintaining this reference

Whenever a command changes:

1. Compare this reference against root and DB-package `package.json` scripts, Prisma config, and Compose config.
2. Record the working directory, purpose, required environment, and whether it changes files, data, or infrastructure.
3. Label configured-but-unimplemented commands honestly.
4. Validate harmless commands directly; validate mutation commands only against the intended development/test environment.
5. Update the verification date and include documentation in the same commit as the command change.

## Official references

- [Prisma 7 CLI](https://docs.prisma.io/docs/cli/v7)
- [Prisma migrate dev](https://docs.prisma.io/docs/cli/v7/migrate/dev)
- [Generating Prisma Client](https://docs.prisma.io/docs/orm/v7/prisma-client/setup-and-configuration/generating-prisma-client)
- [pgAdmin container deployment](https://www.pgadmin.org/docs/pgadmin4/9.17/container_deployment.html)

## Credentials and pre-commit review

Copy `.env.example` to `.env` for a new checkout and replace the placeholders. The PostgreSQL bootstrap reads POSTGRES_PASSWORD, PERFIN_MIGRATOR_PASSWORD, and PERFIN_APP_PASSWORD from local environment configuration. Keep role passwords consistent with the corresponding URL passwords; URL-encode the URL values. The bootstrap only runs when initializing an empty volume. Changing `.env` does not rotate passwords in an existing database.

Never reset a database volume to update credentials. Existing local credentials were preserved when removing hardcoded values from source. Database initialization now uses `docker/postgres/init/01-roles.sql`.

Before committing, inspect candidates and the staged diff:

```bash
git status --short
git check-ignore .env .env.local packages/db/src/generated/prisma/client.ts
git diff --cached --stat
git diff --cached
```

`.env.example` is intentionally eligible for commit and must contain placeholders only. `.gitignore` does not protect files already tracked or files added with `git add -f`. Check staged changes for secrets on every commit.
