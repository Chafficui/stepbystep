import pg from 'pg';
import { config } from './config.js';

const pool = new pg.Pool({ connectionString: config.databaseUrl });

export async function query<T extends pg.QueryResultRow = pg.QueryResultRow>(
  sql: string,
  params?: unknown[]
): Promise<pg.QueryResult<T>> {
  return pool.query<T>(sql, params as never[]);
}

export async function closePool(): Promise<void> {
  await pool.end();
}

export default pool;
