/**
 * Test database helper: spins up an in-memory pg-mem instance and applies
 * the schema so tests can hit a real-ish Postgres surface without Docker.
 */

import { newDb, DataType } from 'pg-mem';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { randomUUID } from 'crypto';
import { setPool } from '../../src/db/index.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SCHEMA_PATH = join(__dirname, '..', '..', 'src', 'db', 'schema.sql');

export async function makeTestDb() {
  const db = newDb({ autoCreateForeignKeyIndices: true });
  // pg-mem doesn't ship gen_random_uuid; register it as IMPURE so each row
  // gets a fresh UUID (the default-pure assumption caches the first value).
  db.public.registerFunction({
    name: 'gen_random_uuid',
    returns: DataType.uuid,
    impure: true,
    implementation: () => randomUUID(),
  });
  const adapter = db.adapters.createPg();
  const pool = new adapter.Pool();
  setPool(pool);
  const sql = readFileSync(SCHEMA_PATH, 'utf8');
  await pool.query(sql);
  return { db, pool };
}
