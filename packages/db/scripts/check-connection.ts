import { config } from 'dotenv';
import { fileURLToPath } from 'node:url';
import { createPrismaClient } from '../src/client.js';

config({ path: fileURLToPath(new URL('../../../.env', import.meta.url)), quiet: true });

async function main() {
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) throw new Error('DATABASE_URL is required');
  const prisma = createPrismaClient(connectionString, 1);
  try {
    const summary = await prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SET TRANSACTION READ ONLY`;
      const roles = await tx.$queryRaw<Array<{ role: string; can_create: boolean }>>`
        SELECT current_user::text AS role,
               has_schema_privilege(current_user, 'public', 'CREATE') AS can_create
      `;
      const role = roles[0];
      if (!role || role.role !== 'perfin_app' || role.can_create) {
        throw new Error('Expected restricted perfin_app role');
      }
      return {
        categories: await tx.category.count(),
        accountTypes: await tx.accountType.count(),
        households: await tx.household.count(),
        members: await tx.householdMember.count(),
        accounts: await tx.account.count(),
      };
    });
    console.info('Application-role connection and table reads passed. Public-schema CREATE is denied.');
    console.info(JSON.stringify(summary));
  } finally {
    await prisma.$disconnect();
  }
}

main().catch(() => {
  console.error('Database check failed. Verify DATABASE_URL, migrations, application-role grants, and local PostgreSQL availability. Raw database errors are suppressed.');
  process.exitCode = 1;
});
