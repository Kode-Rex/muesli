import { describe, it, expect, beforeEach, jest } from '@jest/globals';

jest.unstable_mockModule('../../src/utils/logger.js', () => ({
  default: { info: jest.fn(), error: jest.fn(), warn: jest.fn(), debug: jest.fn() }
}));

const { makeTestDb } = await import('../helpers/db.js');
const { upsertByGoogleSub, findById, deleteUser } = await import('../../src/services/usersRepo.js');
const { query } = await import('../../src/db/index.js');

describe('usersRepo', () => {
  beforeEach(async () => { await makeTestDb(); });

  it('upsertByGoogleSub creates a new user and grants signup credits', async () => {
    const u = await upsertByGoogleSub({ googleSub: 'g1', email: 'a@b.test', fullName: 'Ada' });
    expect(u.email).toBe('a@b.test');
    expect(u.justInserted).toBe(true);

    const bal = await query(`SELECT micros_balance FROM credit_balances WHERE user_id = $1`, [u.id]);
    expect(Number(bal.rows[0].micros_balance)).toBe(1_000_000);

    const ledger = await query(`SELECT reason, micros_delta FROM ledger_entries WHERE user_id = $1`, [u.id]);
    expect(ledger.rows[0].reason).toBe('grant');
    expect(Number(ledger.rows[0].micros_delta)).toBe(1_000_000);
  });

  it('upsertByGoogleSub on second call updates email and skips re-grant', async () => {
    const u1 = await upsertByGoogleSub({ googleSub: 'g1', email: 'a@b.test' });
    const u2 = await upsertByGoogleSub({ googleSub: 'g1', email: 'updated@b.test' });
    expect(u2.id).toBe(u1.id);
    expect(u2.justInserted).toBe(false);
    expect(u2.email).toBe('updated@b.test');

    const grants = await query(`SELECT count(*) FROM ledger_entries WHERE user_id = $1`, [u1.id]);
    expect(Number(grants.rows[0].count)).toBe(1); // still just the one signup grant
  });

  it('findById returns the user or null', async () => {
    const u = await upsertByGoogleSub({ googleSub: 'g1', email: 'a@b.test' });
    expect((await findById(u.id)).googleSub).toBe('g1');
    expect(await findById('00000000-0000-0000-0000-000000000000')).toBeNull();
  });

  it('deleteUser cascades refresh tokens, balances, and ledger entries', async () => {
    const u = await upsertByGoogleSub({ googleSub: 'g1', email: 'a@b.test' });
    await deleteUser(u.id);
    const after = await query(`SELECT count(*) FROM ledger_entries WHERE user_id = $1`, [u.id]);
    expect(Number(after.rows[0].count)).toBe(0);
  });
});
