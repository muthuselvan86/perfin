# CLAUDE.md

perfin v2 is a rebuild of the personal finance manager at `../perfin-manager`. It tracks net worth (accounts and liabilities), dated net-worth snapshots, savings goals and CSV balance imports.

## How we work
- **Pair programming. Claude is the lead.** Claude gives step-by-step instructions and reviews; the user runs them and reports back at each **Checkpoint**. Don't implement steps unless the user asks. Review the user's files and point out fixes instead.
- Work in sessions. Each session's plan lives in `docs/plan/session-NN-*.md`. Read the current one first.
- Only session 1 has a plan file so far: `docs/plan/session-01-db-schema.md` (DB schema).

## Stack
React + TypeScript + Vite + Redux Toolkit/RTK Query → Node/TS REST API (`/v1`) → TS services → Prisma 7 + PostgreSQL 17. Zod validation and decimal.js money math. Tests: Vitest + RTL + MSW, and Playwright. Local dev runs on Docker Compose. The target is AWS in us-east-1: S3 + CloudFront, API Gateway + Cognito, a Lambda container image built from ECR, and private RDS. Infrastructure uses Terraform and GitHub Actions with OIDC. Deploying to AWS needs separate approval.

## Layout (npm workspaces)
- `packages/db`: Prisma schema, migrations, seed, and the `createPrismaClient` factory (`@perfin/db`)
- `packages/core` (later): finance-domain math, CSV parsing, shared contracts
- `apps/api`, `apps/web` (later)
- `docker/postgres/init`: role bootstrap SQL

## Non-negotiables
- Every financial record has a required `userId`. Every query and mutation is scoped to the verified user. Cross-user links are blocked at the DB by composite FKs.
- `ownershipShare` is financial information only. It never grants access. Sharing features are deferred.
- Money is `Decimal(15,2)`. Do the math with decimal.js, never JS floats. The API sends money as decimal strings, snapshot dates as date-only values, and timestamps in ISO format.
- Mutable records carry a `version` for optimistic concurrency.
- DB roles: `perfin_migrator` runs DDL (the Prisma CLI uses `MIGRATION_DATABASE_URL`). `perfin_app` can only read and write rows (the API uses `DATABASE_URL`).
- No `eval`, no xlsx parser, no secrets or real financial data in Git, logs or seeds. Seeds use only synthetic users (`alice@example.test`, `bob@example.test`).
- Deferred: sharing/roles, holdings/investments, audit log, AI assistant, bank sync.

## Reference
`../perfin-manager` is the frozen Next.js app, kept as the functional reference (UI components, `app/lib/utils.ts` finance math, `app/data/Portfolio_Positions.csv`). Commit `b28a3ce` in that repo contains an earlier, reverted attempt at this migration. Treat it as **reference only**: port pieces selectively after review.

## Command documentation
- Keep [docs/commands.md](docs/commands.md) updated in the same change whenever npm scripts, Prisma/Compose configuration, or development commands change. Include working directories, effects, and implementation status.
