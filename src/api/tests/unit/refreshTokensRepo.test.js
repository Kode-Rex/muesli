import { describe, it, expect, beforeEach, jest } from '@jest/globals';

jest.unstable_mockModule('../../src/utils/logger.js', () => ({
  default: { info: jest.fn(), error: jest.fn(), warn: jest.fn(), debug: jest.fn() }
}));

const { makeTestDb } = await import('../helpers/db.js');
const { upsertByGoogleSub } = await import('../../src/services/usersRepo.js');
const { create, rotate, revoke, findByToken } = await import('../../src/services/refreshTokensRepo.js');
const { query } = await import('../../src/db/index.js');

describe('refreshTokensRepo', () => {
  let userId;
  beforeEach(async () => {
    await makeTestDb();
    const u = await upsertByGoogleSub({ googleSub: 'g1', email: 'a@b.test' });
    userId = u.id;
  });

  it('create returns an opaque token; findByToken resolves it', async () => {
    const r = await create(userId);
    expect(r.token).toMatch(/^[A-Za-z0-9_-]+$/);
    const found = await findByToken(r.token);
    expect(found.user_id).toBe(userId);
  });

  it('rotate issues a fresh token, marks old as rotated_to', async () => {
    const orig = await create(userId);
    const rot = await rotate(orig.token);
    expect(rot.token).not.toBe(orig.token);
    expect(rot.userId).toBe(userId);

    const oldRow = await findByToken(orig.token);
    expect(oldRow.rotated_to).not.toBeNull();
  });

  it('rotate detects reuse of an already-rotated token and revokes the chain', async () => {
    const orig = await create(userId);
    await rotate(orig.token); // first rotation succeeds
    const reuse = await rotate(orig.token); // re-using the original
    expect(reuse).toBeNull();

    const stillActive = await query(
      `SELECT count(*) FROM refresh_tokens WHERE user_id = $1 AND revoked_at IS NULL`,
      [userId]
    );
    expect(Number(stillActive.rows[0].count)).toBe(0);
  });

  it('revoke marks the token revoked', async () => {
    const r = await create(userId);
    await revoke(r.token);
    const row = await findByToken(r.token);
    expect(row.revoked_at).not.toBeNull();
  });
});
