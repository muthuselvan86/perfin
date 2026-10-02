import { config } from 'dotenv';
import { defineConfig, env } from 'prisma/config';
config({ path: '../../.env' });

export default defineConfig({
  schema: 'schema.prisma',
  migrations: { path: 'prisma/migrations', seed: 'tsx prisma/seed.ts' },
  datasource: { url: env('MIGRATION_DATABASE_URL') },
});