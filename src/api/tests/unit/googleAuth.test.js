import { describe, it, expect, jest } from '@jest/globals';

jest.unstable_mockModule('../../src/config/index.js', () => ({
  config: { auth: { googleClientId: 'gci.test' } }
}));

const { verifyIdToken } = await import('../../src/services/googleAuth.js');

function fakeClient(payload) {
  return { verifyIdToken: jest.fn().mockResolvedValue({ getPayload: () => payload }) };
}

describe('googleAuth.verifyIdToken', () => {
  it('returns sub/email/name on a verified payload', async () => {
    const r = await verifyIdToken('tok', { client: fakeClient({ sub: 'g1', email: 'a@b.test', email_verified: true, name: 'Ada' }) });
    expect(r).toEqual({ sub: 'g1', email: 'a@b.test', emailVerified: true, name: 'Ada' });
  });

  it('throws unverified_email when email_verified is false', async () => {
    await expect(
      verifyIdToken('tok', { client: fakeClient({ sub: 'g1', email: 'a@b.test', email_verified: false }) })
    ).rejects.toMatchObject({ code: 'unverified_email' });
  });

  it('throws when payload is missing', async () => {
    const client = { verifyIdToken: jest.fn().mockResolvedValue({ getPayload: () => null }) };
    await expect(verifyIdToken('tok', { client })).rejects.toThrow(/invalid_id_token/);
  });
});
