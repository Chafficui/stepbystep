import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import pg from 'pg';

export async function migrate(connectionString: string, migrationsDir: string): Promise<void> {
  const pool = new pg.Pool({ connectionString });
  try {
    const client = await pool.connect();
    try {
      await client.query(
        'CREATE TABLE IF NOT EXISTS schema_migrations (name text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())'
      );
      const files = (await readdir(migrationsDir))
        .filter((f) => f.endsWith('.sql'))
        .sort();
      const { rows } = await client.query<{ name: string }>('SELECT name FROM schema_migrations');
      const applied = new Set(rows.map((r) => r.name));
      for (const file of files) {
        if (applied.has(file)) continue;
        const sql = await readFile(path.join(migrationsDir, file), 'utf8');
        await client.query('BEGIN');
        try {
          await client.query(sql);
          await client.query('INSERT INTO schema_migrations (name) VALUES ($1)', [file]);
          await client.query('COMMIT');
        } catch (err) {
          await client.query('ROLLBACK');
          throw err;
        }
      }
    } finally {
      client.release();
    }
  } finally {
    await pool.end();
  }
}
