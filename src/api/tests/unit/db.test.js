/**
 * Smoke test: pg-mem + schema.sql apply cleanly and round-trip a row.
 * If this passes, the rest of the repo/service tests can rely on makeTestDb().
 */

import { describe, it, expect, jest } from '@jest/globals';

jest.unstable_mockModule('../../src/utils/logger.js', () => ({
  default: { info: jest.fn(), error: jest.fn(), warn: jest.fn(), debug: jest.fn() }
}));

const { makeTestDb } = await import('../helpers/db.js');
const { query } = await import('../../src/db/index.js');

describe('db schema bootstrap (pg-mem)', () => {
  it('applies the schema and round-trips a user row', async () => {
    await makeTestDb();
    const r = await query(
      `INSERT INTO users (google_sub, email, full_name) VALUES ($1, $2, $3) RETURNING id, email`,
      ['google-sub-1', 'a@b.test', 'Ada']
    );
    expect(r.rows[0].email).toBe('a@b.test');
    expect(r.rows[0].id).toMatch(/^[0-9a-f-]{36}$/);
  });

  it('enforces unique google_sub', async () => {
    await makeTestDb();
    await query(`INSERT INTO users (google_sub, email) VALUES ('s1', 'a@b.test')`);
    await expect(
      query(`INSERT INTO users (google_sub, email) VALUES ('s1', 'c@d.test')`)
    ).rejects.toThrow();
  });

  it('credit_balances FK cascades on user delete', async () => {
    await makeTestDb();
    const u = await query(`INSERT INTO users (google_sub, email) VALUES ('s2', 'a@b.test') RETURNING id`);
    const uid = u.rows[0].id;
    await query(`INSERT INTO credit_balances (user_id, micros_balance) VALUES ($1, 100000)`, [uid]);
    await query(`DELETE FROM users WHERE id = $1`, [uid]);
    const remaining = await query(`SELECT * FROM credit_balances WHERE user_id = $1`, [uid]);
    expect(remaining.rows).toHaveLength(0);
  });
});
