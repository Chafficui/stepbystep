import { defineConfig } from 'vitest/config';

process.env.DATABASE_URL =
  process.env.DATABASE_URL ?? 'postgres://postgres:test@localhost:5433/stepbystep_test';
process.env.ORGA_PASSWORD = process.env.ORGA_PASSWORD ?? 'test-orga-password';
process.env.ORGA_SESSION_SECRET = process.env.ORGA_SESSION_SECRET ?? 's'.repeat(40);

export default defineConfig({
  test: {
    include: ['test/**/*.test.ts'],
    testTimeout: 30_000,
    hookTimeout: 60_000,
    globalSetup: 'test/global-setup.ts',
  },
});
