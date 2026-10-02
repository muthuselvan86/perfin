import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from './generated/prisma/client.js';

/** Create once per process (or warm Lambda), not once per request.
 * Pass DATABASE_URL from the application's validated configuration.
 * The caller owns shutdown and must await client.$disconnect().
 */
export function createPrismaClient(connectionString: string, poolMax = 5) {
  if (!connectionString.trim()) throw new Error('Database connection string is required');
  if (!Number.isSafeInteger(poolMax) || poolMax < 1) {
    throw new Error('Database pool size must be a positive integer');
  }
  return new PrismaClient({
    adapter: new PrismaPg({ connectionString, max: poolMax, connectionTimeoutMillis: 5000 }),
    log: [],
  });
}

export { PrismaClient, Prisma } from './generated/prisma/client.js';
