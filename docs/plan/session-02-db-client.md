# Checkpoint: reusable database client

The factory in `packages/db/src/client.ts` accepts a connection string and pool limit. It does not load environment variables, authenticate users, or implement household authorization. The application will create one client per process and reuse it. Lambda will use a pool maximum of one per warm environment. Shutdown must disconnect the client.

The seed reuses this factory with a pool size of one. Application queries and the connection checker use DATABASE_URL, never the migration credentials. This package currently runs as TypeScript through tsx; a distributable package build/export setup remains for the API integration step.

From the project root:

```bash
npm -w @perfin/db run typecheck
npm run db:check
```

The checker verifies perfin_app is the connected role, cannot CREATE in public, and can read the expected tables. It runs in a read-only transaction and prints counts only. It is a smoke check, not a complete permission audit or cross-household authorization test.

Review these files and the counts before continuing. Next implement household access using a verified issuer/subject principal, with tests for missing, archived, and other-household memberships; then account operations and atomic ownership/version checks. Do not add account routes until these authorization tests pass. Confirm the proposed shared household access policy before implementing those services.
