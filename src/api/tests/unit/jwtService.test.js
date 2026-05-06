import { describe, it, expect, jest } from '@jest/globals';

jest.unstable_mockModule('../../src/config/index.js', () => ({
  config: {
    auth: { jwtSecret: 'x'.repeat(64), accessTokenTtlMin: 15 }
  }
}));

const { signAccessToken, verifyAccessToken } = await import('../../src/services/jwtService.js');

describe('jwtService', () => {
  it('signs and verifies a token round-trip', () => {
    const token = signAccessToken('user-uuid-1');
    const payload = verifyAccessToken(token);
    expect(payload.sub).toBe('user-uuid-1');
    expect(payload.iss).toBe('muesli-api');
    expect(payload.aud).toBe('muesli-ios');
  });

  it('rejects tokens signed with the wrong secret', () => {
    const token = signAccessToken('u');
    const tampered = token.slice(0, -1) + (token.slice(-1) === 'a' ? 'b' : 'a');
    expect(() => verifyAccessToken(tampered)).toThrow();
  });
});
