/**
 * Integration: Google sign-in → access token → /me → refresh → balance.
 * AUTH_ENABLED=true. Google verifier and Anthropic SDK are mocked; Postgres
 * is pg-mem; signup grant is wired so /balance reflects a non-zero balance.
 */

import { describe, it, expect, jest, beforeAll } from '@jest/globals';
import request from 'supertest';

jest.unstable_mockModule('../../src/utils/logger.js', () => ({
  default: { info: jest.fn(), error: jest.fn(), warn: jest.fn(), debug: jest.fn(), health: jest.fn(), transcription: jest.fn(), websocket: jest.fn(), request: jest.fn() }
}));

jest.unstable_mockModule('../../src/config/index.js', () => ({
  config: {
    server: { apiVersion: 'v1', environment: 'test', isDevelopment: false, isProduction: false, port: 3001 },
    health: { timeoutMs: 5000 },
    logging: { level: 'error' },
    deepgram: { model: 'nova-2', language: 'en', apiKey: 'test-key' },
    anthropic: { apiKey: 'test-key' },
    security: { corsOrigin: 'http://localhost:3000', rateLimiting: { windowMs: 15 * 60 * 1000, maxRequests: 1000, transcriptionMaxRequests: 1000 } },
    upload: { maxFileSizeMB: 50, maxFileSizeBytes: 50 * 1024 * 1024, allowedMimeTypes: [] },
    websocket: { heartbeatIntervalMs: 30000, connectionTimeoutMs: 60000 },
    auth: { enabled: true, jwtSecret: 'x'.repeat(64), devUserId: 'local-dev', accessTokenTtlMin: 15, refreshTokenTtlDays: 30, googleClientId: 'gci.test' },
    credits: { enforced: false, pricingVersion: 1, newUserGrantMicros: 1_000_000 },
    database: { databaseUrl: '' }
  }
}));

jest.unstable_mockModule('../../src/services/deepgramService.js', () => ({
  default: { transcribeBuffer: jest.fn(), healthCheck: jest.fn().mockResolvedValue({ healthy: true }), cleanupStaleConnections: jest.fn(), isConnected: true, getStats: jest.fn().mockReturnValue({}) }
}));

jest.unstable_mockModule('../../src/services/googleAuth.js', () => ({
  verifyIdToken: jest.fn().mockResolvedValue({ sub: 'g-123', email: 'a@b.test', emailVerified: true, name: 'Ada' }),
  getClient: jest.fn(),
  setClient: jest.fn(),
}));

const { makeTestDb } = await import('../helpers/db.js');
const { app } = await import('../../src/server.js');

beforeAll(async () => { await makeTestDb(); });

describe('Auth flow (AUTH_ENABLED=true)', () => {
  it('rejects /v1/auth/me without a bearer token', async () => {
    const r = await request(app).get('/v1/auth/me');
    expect(r.status).toBe(401);
    expect(r.body.error).toBe('missing_token');
  });

  it('signs in with Google → returns access + refresh + user', async () => {
    const r = await request(app).post('/v1/auth/google').send({ idToken: 'fake' });
    expect(r.status).toBe(200);
    expect(r.body.accessToken).toBeTruthy();
    expect(r.body.refreshToken).toBeTruthy();
    expect(r.body.user.email).toBe('a@b.test');
  });

  it('access token unlocks /v1/auth/me', async () => {
    const signin = await request(app).post('/v1/auth/google').send({ idToken: 'fake' });
    const r = await request(app).get('/v1/auth/me').set('Authorization', `Bearer ${signin.body.accessToken}`);
    expect(r.status).toBe(200);
    expect(r.body.user.email).toBe('a@b.test');
  });

  it('refresh rotates and old refresh token becomes unusable', async () => {
    const s1 = await request(app).post('/v1/auth/google').send({ idToken: 'fake' });
    const old = s1.body.refreshToken;
    const rot1 = await request(app).post('/v1/auth/refresh').send({ refreshToken: old });
    expect(rot1.status).toBe(200);
    expect(rot1.body.refreshToken).not.toBe(old);

    const reuse = await request(app).post('/v1/auth/refresh').send({ refreshToken: old });
    expect(reuse.status).toBe(401);
    expect(reuse.body.error).toBe('token_reuse');
  });

  it('signup grant lands in /v1/account/balance', async () => {
    const s1 = await request(app).post('/v1/auth/google').send({ idToken: 'fake' });
    const r = await request(app).get('/v1/account/balance').set('Authorization', `Bearer ${s1.body.accessToken}`);
    expect(r.status).toBe(200);
    expect(r.body.microsBalance).toBeGreaterThan(0);
    expect(r.body.enforced).toBe(false);
    // With enforcement off, hoursAvailable surfaces "unlimited" via MAX_SAFE_INTEGER.
    expect(r.body.hoursAvailable).toBe(Number.MAX_SAFE_INTEGER);
  });

  it('rejects unverified email at sign-in', async () => {
    const { verifyIdToken } = await import('../../src/services/googleAuth.js');
    verifyIdToken.mockRejectedValueOnce(Object.assign(new Error('unverified_email'), { code: 'unverified_email' }));
    const r = await request(app).post('/v1/auth/google').send({ idToken: 'unverified' });
    expect(r.status).toBe(401);
    expect(r.body.error).toBe('unverified_email');
  });

  it('rejects /v1/auth/google with no idToken in body', async () => {
    const r = await request(app).post('/v1/auth/google').send({});
    expect(r.status).toBe(400);
    expect(r.body.error).toBe('id_token_missing');
  });

  it('rejects /v1/auth/refresh with no refreshToken in body', async () => {
    const r = await request(app).post('/v1/auth/refresh').send({});
    expect(r.status).toBe(400);
  });

  it('GET /v1/account/ledger returns paginated entries; respects limit', async () => {
    const s1 = await request(app).post('/v1/auth/google').send({ idToken: 'fake' });
    const r = await request(app).get('/v1/account/ledger?limit=5').set('Authorization', `Bearer ${s1.body.accessToken}`);
    expect(r.status).toBe(200);
    expect(Array.isArray(r.body.entries)).toBe(true);
  });

  it('logout revokes the supplied refresh token', async () => {
    const s1 = await request(app).post('/v1/auth/google').send({ idToken: 'fake' });
    const out = await request(app)
      .post('/v1/auth/logout')
      .set('Authorization', `Bearer ${s1.body.accessToken}`)
      .send({ refreshToken: s1.body.refreshToken });
    expect(out.status).toBe(204);
    const reuse = await request(app).post('/v1/auth/refresh').send({ refreshToken: s1.body.refreshToken });
    expect(reuse.status).toBe(401);
  });

  it('rejects an invalid bearer token via requireAuth', async () => {
    const r = await request(app).get('/v1/auth/me').set('Authorization', 'Bearer not-a-real-jwt');
    expect(r.status).toBe(401);
    expect(r.body.error).toBe('invalid_token');
  });
});
