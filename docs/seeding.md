# Database seed

From the project root, after applying the reviewed migration:

```bash
npm -w @perfin/db run generate
npm run db:seed
```

The default seed creates missing reference rows: 7 categories and 38 account types. It does not create users, family members, accounts, balances, or exchange rates. Existing reference rows are preserved. Conflicting category kinds or type/category mappings cause the transaction to roll back instead of reclassifying existing accounts.

The seed uses DATABASE_URL (application role), not MIGRATION_DATABASE_URL. Both variables remain required by the normal Prisma CLI configuration and seed workflow. No schema privileges are required by the seed itself.

Optional synthetic demo:

```bash
SEED_DEMO=true npm run db:seed
```

This creates a synthetic family with Alice and Bob, three accounts (USD checking, joint INR savings, USD credit-card liability), complete ownership shares, and an illustrative 85 INR/USD rate dated 2026-01-01. It creates no real login credentials or snapshots. Demo mode is rejected when NODE_ENV=production. Use only a development/test database; this environment check is not a deployment authorization boundary.

Each invocation is atomic. Stable reference codes and a fixed demo household ID make sequential reruns idempotent. If the demo household already exists, demo creation is skipped completely, preserving edited balances and ownership. The seed is not a fixture-repair/reset tool. Run only one seed process at a time.

Run the same command twice and inspect counts in pgAdmin:

```sql
SELECT count(*) FROM categories; -- 7 in a fresh database
SELECT count(*) FROM account_types; -- 38 in a fresh database
SELECT count(*) FROM households; -- 0 by default; 1 with demo
SELECT count(*) FROM accounts; -- 0 by default; 3 with demo
```

An existing database may have additional rows. Repeated seeding should not increase counts for this catalog or demo family.

Next: implement and test household access and account services, then decimal net-worth calculations and snapshots. No API authorization is implemented by seeding.

Reference: https://www.prisma.io/docs/orm/v7/prisma-migrate/workflows/seeding

## V1 reference-data compatibility

See [the complete V1-to-V2 mapping](architecture/v1-v2-account-type-mapping.md). The catalog preserves V1 distinctions and retains the initial V2 codes for compatibility. Re-run `npm run db:seed` to add the 20 new account types; no schema migration is needed. Existing IDs, labels, activation flags, sort orders, balances, ownership, and account-type assignments are preserved.

The generic IRA, Home, Brokerage, and Valuables types remain available. Existing accounts using them are not automatically reclassified. Foreign-asset records need country, native currency, and type review during a separate data import. No V1 financial data is copied by this seed.
