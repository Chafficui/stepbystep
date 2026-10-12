// Global setup: start a disposable Postgres in Docker if available, run migrations.
// If Docker is unavailable and no DATABASE_URL is provided, integration tests are skipped.
import { execSync } from 'node:child_process';
import { Pool } from 'pg';
import { migrate } from '../src/migrate.js';
import path from 'node:path';

const PORT = 5433;
const DATABASE_URL =
  process.env.DATABASE_URL ?? `postgres://postgres:test@localhost:${PORT}/stepbystep_test`;
const MIGRATIONS_DIR = path.resolve(process.cwd(), 'migrations');

async function waitForDb(url: string): Promise<boolean> {
  const pool = new Pool({ connectionString: url, connectionTimeoutMillis: 2000 });
  for (let i = 0; i < 40; i++) {
    try {
      await pool.query('SELECT 1');
      await pool.end();
      return true;
    } catch {
      await new Promise((r) => setTimeout(r, 500));
    }
  }
  await pool.end();
  return false;
}

export async function setup(): Promise<void> {
  let docker = false;
  try {
    execSync('docker info', { stdio: 'ignore' });
    docker = true;
  } catch {
    docker = false;
  }
  if (!docker) {
    console.warn(
      '[skip] Docker not available — integration tests will be skipped.'
    );
    process.env.SKIP_INTEGRATION = '1';
    return;
  }
  try {
    execSync(
      `docker run --rm -d --name stepbystep-test-pg -p ${PORT}:5432 -e POSTGRES_PASSWORD=test -e POSTGRES_DB=stepbystep_test postgres:16`,
      { stdio: 'ignore' }
    );
  } catch (err) {
    console.warn(`[skip] Could not start Postgres container: ${String(err)}`);
    process.env.SKIP_INTEGRATION = '1';
    return;
  }
  process.env.SKIP_INTEGRATION = '';
  process.env.DATABASE_URL = DATABASE_URL;
  const ready = await waitForDb(DATABASE_URL);
  if (!ready) {
    console.warn('[skip] Postgres test container did not become ready in time.');
    process.env.SKIP_INTEGRATION = '1';
    return;
  }
  await migrate(DATABASE_URL, MIGRATIONS_DIR);
}

export async function teardown(): Promise<void> {
  if (process.env.SKIP_INTEGRATION === '1') return;
  try {
    execSync('docker rm -f stepbystep-test-pg', { stdio: 'ignore' });
  } catch {
    // ignore
  }
}
