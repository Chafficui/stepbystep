import { execSync, spawn, type ChildProcess } from 'node:child_process';
import { setTimeout as sleep } from 'node:timers/promises';
import { Pool } from 'pg';

export const DOCKER_PORT = 5433;
export const DATABASE_URL =
  process.env.DATABASE_URL ??
  `postgres://postgres:test@localhost:${DOCKER_PORT}/stepbystep_test`;

export function dockerAvailable(): boolean {
  if (process.env.DATABASE_URL !== undefined) return true; // assume externally provided DB
  try {
    execSync('docker info', { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

let containerProc: ChildProcess | null = null;

export async function startPostgres(): Promise<void> {
  if (process.env.DATABASE_URL !== undefined) return;
  execSync(
    `docker run --rm -d --name stepbystep-test-pg -p ${DOCKER_PORT}:5432 -e POSTGRES_PASSWORD=test -e POSTGRES_DB=stepbystep_test postgres:16`,
    { stdio: 'ignore' }
  );
  const pool = new Pool({ connectionString: DATABASE_URL, connectionTimeoutMillis: 2000 });
  for (let i = 0; i < 30; i++) {
    try {
      await pool.query('SELECT 1');
      await pool.end();
      return;
    } catch {
      await sleep(500);
    }
  }
  await pool.end();
  throw new Error('Postgres test container did not become ready');
}

export function stopPostgres(): void {
  try {
    execSync('docker rm -f stepbystep-test-pg', { stdio: 'ignore' });
  } finally {
    containerProc = null;
  }
}

export async function truncateAll(connectionString = DATABASE_URL): Promise<void> {
  const pool = new Pool({ connectionString });
  await pool.query(
    'TRUNCATE location_point, checkin, alert, ranking_snapshot, participant, team, event RESTART IDENTITY CASCADE'
  );
  await pool.query('INSERT INTO event (id) VALUES (1)');
  await pool.end();
}
