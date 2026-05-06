import { describe, it, expect, beforeEach, jest } from '@jest/globals';

jest.unstable_mockModule('../../src/utils/logger.js', () => ({
  default: { info: jest.fn(), error: jest.fn(), warn: jest.fn(), debug: jest.fn() }
}));

const { makeTestDb } = await import('../helpers/db.js');
const { upsertByGoogleSub } = await import('../../src/services/usersRepo.js');
const { recordBlend, getBalance, listEntries, blendIdempotencyKey, checkBalance } =
  await import('../../src/services/ledgerService.js');

describe('ledgerService', () => {
  let userId;
  beforeEach(async () => {
    await makeTestDb();
    const u = await upsertByGoogleSub({ googleSub: 'g1', email: 'a@b.test' });
    userId = u.id;
  });

  it('recordBlend debits the balance and inserts a ledger entry', async () => {
    const before = await getBalance(userId);
    const r = await recordBlend({
      userId, sessionId: '00000000-0000-0000-0000-000000000001',
      microsCost: 50_000,
      idempotencyKey: 'blend:s1:abc',
      metadata: { actualMicros: 50_000 }
    });
    expect(r.alreadyRecorded).toBe(false);
    expect(r.microsDelta).toBe(-50_000);
    expect(await getBalance(userId)).toBe(before - 50_000);

    const entries = await listEntries(userId, { limit: 10 });
    expect(entries.find(e => e.reason === 'blend')).toBeTruthy();
  });

  it('recordBlend is idempotent on retry with the same key', async () => {
    const args = { userId, sessionId: '00000000-0000-0000-0000-000000000001', microsCost: 50_000, idempotencyKey: 'blend:s1:abc' };
    const first = await recordBlend(args);
    const before = await getBalance(userId);
    const second = await recordBlend(args);
    expect(second.alreadyRecorded).toBe(true);
    expect(second.entryId).toBe(first.entryId);
    expect(await getBalance(userId)).toBe(before); // no double-debit
  });

  it('blendIdempotencyKey changes when inputs change', () => {
    const a = blendIdempotencyKey({ sessionId: 's', audioHash: 'a', photoHashes: ['p1'], userNotes: 'x' });
    const b = blendIdempotencyKey({ sessionId: 's', audioHash: 'a', photoHashes: ['p1', 'p2'], userNotes: 'x' });
    expect(a).not.toBe(b);
  });

  it('checkBalance returns ok when enforcement is off (v1 default)', async () => {
    expect(await checkBalance(userId, 999_999_999)).toEqual({ ok: true });
  });
});
