// Shared vitest setup: skip integration tests when neither Docker nor a
// DATABASE_URL-backed Postgres is available.
import { beforeAll, afterAll } from 'vitest';
import {
  DATABASE_URL,
  dockerAvailable,
  startPostgres,
  stopPostgres,
  truncateAll,
} from './helpers.js';

process.env.DATABASE_URL = DATABASE_URL;
process.env.ORGA_PASSWORD = process.env.ORGA_PASSWORD ?? 'test-orga-password';
process.env.ORGA_SESSION_SECRET = process.env.ORGA_SESSION_SECRET ?? 'x'.repeat(40);

export const DB_UNAVAILABLE_MESSAGE =
  'Docker unavailable and no DATABASE_URL provided — skipping integration tests.';

export function integrationAvailable(): boolean {
  return dockerAvailable();
}

export function setupDb(hooks: 'all' | 'none' = 'all'): void {
  if (hooks === 'all') {
    beforeAll(async () => {
      await startPostgres();
    });
    afterAll(() => {
      stopPostgres();
    });
  }
}

export { truncateAll };
