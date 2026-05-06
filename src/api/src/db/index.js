/**
 * Postgres pool + small query helpers.
 *
 * The pool is lazy: nothing connects until the first query, and tests can
 * supply their own pool (e.g. pg-mem's adapter) via setPool() so we don't
 * need a real Postgres for unit/integration tests.
 */

import pg from 'pg';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { config } from '../config/index.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SCHEMA_PATH = join(__dirname, 'schema.sql');

let _pool = null;

export function setPool(pool) {
  _pool = pool;
}

export function getPool() {
  if (!_pool) {
    if (!config.database.databaseUrl) {
      throw new Error('DATABASE_URL is not set; call setPool() in tests or set the env var.');
    }
    _pool = new pg.Pool({ connectionString: config.database.databaseUrl, max: 10 });
  }
  return _pool;
}

export async function query(text, params = []) {
  return getPool().query(text, params);
}

export async function tx(fn) {
  const client = await getPool().connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
}

export async function applySchema(pool = getPool()) {
  const sql = readFileSync(SCHEMA_PATH, 'utf8');
  await pool.query(sql);
}
