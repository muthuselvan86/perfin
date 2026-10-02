import { config } from 'dotenv';
import { fileURLToPath } from 'node:url';
import { createPrismaClient, type Prisma } from '../src/client.js';

// Resolve relative to this file, not the caller's working directory.
config({ path: fileURLToPath(new URL('../../../.env', import.meta.url)), quiet: true });

const catalog = [
  { code: 'CASH', name: 'Cash', kind: 'ASSET', types: [
    ['CHECKING', 'Checking'], ['SAVINGS', 'Savings'], ['FIXED_DEPOSIT', 'Fixed deposit'],
    ['MONEY_MARKET', 'Money market account'], ['CERTIFICATE_OF_DEPOSIT', 'Certificate of deposit'],
    ['CASH_ON_HAND', 'Cash on hand'], ['HIGH_YIELD_SAVINGS', 'High-yield savings'],
    ['BROKERAGE_SAVINGS', 'Brokerage savings'],
  ] },
  { code: 'INVESTMENTS', name: 'Investments', kind: 'ASSET', types: [
    ['BROKERAGE', 'Brokerage'], ['MUTUAL_FUNDS', 'Mutual funds'],
    ['STOCKS', 'Stocks'], ['BONDS', 'Bonds'], ['REITS', 'REITs'],
    ['ALTERNATIVE_INVESTMENTS', 'Alternative investments'], ['EDUCATION_529', '529 education savings'],
  ] },
  { code: 'RETIREMENT', name: 'Retirement', kind: 'ASSET', types: [
    ['RETIREMENT_401K', '401(k)'], ['IRA', 'IRA'], ['EPF', 'EPF'], ['PPF', 'PPF'],
    ['TRADITIONAL_IRA', 'Traditional IRA'], ['ROTH_IRA', 'Roth IRA'], ['PENSION', 'Pension'],
  ] },
  { code: 'REAL_ESTATE', name: 'Real estate', kind: 'ASSET', types: [
    ['HOME', 'Home'], ['LAND', 'Land'],
    ['PRIMARY_RESIDENCE', 'Primary residence'], ['RENTAL_PROPERTY', 'Rental property'],
  ] },
  { code: 'PERSONAL_PROPERTY', name: 'Personal property', kind: 'ASSET', types: [
    ['VEHICLE', 'Vehicle'], ['VALUABLES', 'Valuables'],
    ['JEWELRY', 'Jewelry'], ['COLLECTIBLES', 'Collectibles'],
    ['ELECTRONICS', 'Electronics'], ['FURNITURE', 'Furniture'],
  ] },
  { code: 'LOANS', name: 'Loans', kind: 'LIABILITY', types: [
    ['MORTGAGE', 'Mortgage'], ['AUTO_LOAN', 'Auto loan'], ['PERSONAL_LOAN', 'Personal loan'],
    ['STUDENT_LOAN', 'Student loan'],
  ] },
  { code: 'CREDIT', name: 'Credit', kind: 'LIABILITY', types: [
    ['CREDIT_CARD', 'Credit card'], ['LINE_OF_CREDIT', 'Line of credit'],
  ] },
] as const;

async function seedReferenceData(tx: Prisma.TransactionClient) {
  for (const [sortOrder, entry] of catalog.entries()) {
    const category = await tx.category.upsert({
      where: { code: entry.code },
      create: { code: entry.code, name: entry.name, kind: entry.kind, sortOrder },
      update: {}, // Preserve existing labels, activation, and classification.
    });
    if (category.kind !== entry.kind) throw new Error('SEED_REFERENCE_CONFLICT');
    for (const [typeOrder, [code, name]] of entry.types.entries()) {
      const type = await tx.accountType.upsert({
        where: { code },
        create: { code, name, categoryId: category.id, sortOrder: typeOrder },
        update: {},
      });
      if (type.categoryId !== category.id) throw new Error('SEED_REFERENCE_CONFLICT');
    }
  }
}

// Synthetic identities are fixture identifiers, not working login credentials.
const demoHouseholdId = '10000000-0000-4000-8000-000000000001';
const aliceMemberId = '20000000-0000-4000-8000-000000000001';
const bobMemberId = '20000000-0000-4000-8000-000000000002';
const fixtureDate = new Date('2026-01-01T00:00:00.000Z');

async function seedDemo(tx: Prisma.TransactionClient) {
  // Never reset balances or repair partial fixtures over user edits on a rerun.
  if (await tx.household.findUnique({ where: { id: demoHouseholdId } })) return;
  const identities = [];
  for (const name of ['alice', 'bob']) {
    identities.push(await tx.user.upsert({
      where: { authIssuer_authSubject: { authIssuer: 'urn:perfin:synthetic', authSubject: name } },
      create: { authIssuer: 'urn:perfin:synthetic', authSubject: name, email: `${name}@example.test` },
      update: {},
    }));
  }
  await tx.household.create({ data: {
    id: demoHouseholdId, name: 'Synthetic demo family', reportingCurrency: 'USD',
    timeZone: 'America/New_York',
    householdMembers: { create: [
      { id: aliceMemberId, userId: identities[0]!.id, displayName: 'Alice (demo)' },
      { id: bobMemberId, userId: identities[1]!.id, displayName: 'Bob (demo)' },
    ] },
  } });

  const accounts = [
    { name: 'Demo US checking', type: 'CHECKING', currency: 'USD', countryCode: 'US', balance: '10000.00', owners: [[aliceMemberId, '100.00']] },
    { name: 'Demo India joint savings', type: 'SAVINGS', currency: 'INR', countryCode: 'IN', balance: '850000.00', owners: [[aliceMemberId, '50.00'], [bobMemberId, '50.00']] },
    { name: 'Demo credit card', type: 'CREDIT_CARD', currency: 'USD', countryCode: 'US', balance: '1000.00', owners: [[bobMemberId, '100.00']] },
  ] as const;
  for (const entry of accounts) {
    const type = await tx.accountType.findUniqueOrThrow({ where: { code: entry.type } });
    await tx.account.create({ data: {
      householdId: demoHouseholdId, accountTypeId: type.id,
      name: entry.name, currency: entry.currency, countryCode: entry.countryCode,
      balance: entry.balance, balanceAsOf: fixtureDate,
      ownerships: { create: entry.owners.map(([memberId, ownershipPercent]) => ({ memberId, ownershipPercent })) },
    } });
  }
  // Illustrative fixture rate, not a real historical or current quote.
  await tx.exchangeRate.create({ data: {
    householdId: demoHouseholdId, baseCurrency: 'USD', quoteCurrency: 'INR',
    rate: '85.00', effectiveDate: fixtureDate, source: 'SYNTHETIC',
  } });
}

async function main() {
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) throw new Error('SEED_DATABASE_URL_REQUIRED');
  if (process.env.SEED_DEMO && !['true', 'false'].includes(process.env.SEED_DEMO)) {
    throw new Error('SEED_DEMO_MUST_BE_TRUE_OR_FALSE');
  }
  const demo = process.env.SEED_DEMO === 'true';
  if (demo && process.env.NODE_ENV === 'production') throw new Error('SEED_DEMO_DISABLED_IN_PRODUCTION');
  const prisma = createPrismaClient(connectionString, 1);
  try {
    await prisma.$transaction(async (tx) => {
      await seedReferenceData(tx);
      if (demo) await seedDemo(tx);
    }, { timeout: 30_000 });
    console.info(`Seed complete: reference data ensured; synthetic demo ${demo ? 'enabled' : 'disabled'}.`);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch(() => {
  // Raw Prisma/driver errors can contain SQL, connection details, or financial values.
  console.error('Seed failed. Check DATABASE_URL, applied migrations, application-role grants, SEED_DEMO, and reference-code conflicts. No raw database error was logged.');
  process.exitCode = 1;
});
