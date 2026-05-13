/**
 * Integration tests for chat routes.
 * Mocks Anthropic and Deepgram so no real network calls occur.
 */

import { describe, it, expect, beforeEach, jest } from '@jest/globals';
import request from 'supertest';

jest.unstable_mockModule('../../src/utils/logger.js', () => ({
  default: {
    info: jest.fn(), error: jest.fn(), warn: jest.fn(), debug: jest.fn(),
    health: jest.fn(), transcription: jest.fn(), websocket: jest.fn(), request: jest.fn()
  }
}));

jest.unstable_mockModule('../../src/config/index.js', () => ({
  config: {
    server: { apiVersion: 'v1', environment: 'test', isDevelopment: false, isProduction: false, port: 3001 },
    health: { timeoutMs: 5000 },
    logging: { level: 'error' },
    deepgram: { model: 'nova-2', language: 'en', apiKey: 'test-key' },
    anthropic: { apiKey: 'test-key' },
    security: {
      corsOrigin: 'http://localhost:3000',
      rateLimiting: { windowMs: 15 * 60 * 1000, maxRequests: 1000, transcriptionMaxRequests: 1000 }
    },
    upload: { maxFileSizeMB: 50, maxFileSizeBytes: 50 * 1024 * 1024, allowedMimeTypes: ['audio/mp4'] },
    websocket: { heartbeatIntervalMs: 30000, connectionTimeoutMs: 60000 },
    auth: { enabled: false, jwtSecret: 'x'.repeat(32), devUserId: 'local-dev', accessTokenTtlMin: 15, refreshTokenTtlDays: 30, googleClientId: '' },
    credits: { enforced: false, pricingVersion: 1, newUserGrantMicros: 0 },
    database: { databaseUrl: '' }
  }
}));

jest.unstable_mockModule('../../src/services/deepgramService.js', () => ({
  default: {
    transcribeBuffer: jest.fn().mockResolvedValue({ transcript: 't', words: [] }),
    healthCheck: jest.fn().mockResolvedValue({ healthy: true, latency: 10 }),
    cleanupStaleConnections: jest.fn(),
    isConnected: true,
    getStats: jest.fn().mockReturnValue({ activeConnections: 0, isConnected: true })
  }
}));

const anthropicMock = {
  messages: {
    create: jest.fn().mockResolvedValue({
      content: [{ type: 'text', text: JSON.stringify({ answer: 'mocked answer', references: [] }) }],
      usage: { input_tokens: 100, output_tokens: 20 }
    })
  }
};

jest.unstable_mockModule('../../src/services/anthropic.js', () => ({
  anthropic: anthropicMock,
  HAIKU_MODEL: 'claude-haiku-4-5-20251001',
  SONNET_MODEL: 'claude-sonnet-4-6'
}));

const { app } = await import('../../src/server.js');
const { sessionsRepo } = await import('../../src/services/sessionsRepo.js');

describe('POST /v1/sessions/:id/chat', () => {
  let sessionId;

  beforeEach(async () => {
    anthropicMock.messages.create.mockClear();
    anthropicMock.messages.create.mockResolvedValue({
      content: [{ type: 'text', text: JSON.stringify({ answer: 'mocked answer', references: [] }) }],
      usage: { input_tokens: 100, output_tokens: 20 }
    });
    sessionId = await sessionsRepo.createSession({ userId: 'local-dev' });
    await sessionsRepo.saveTranscript(sessionId, { text: 'Sarah said hello.', words: [] });
  });

  it('returns the assistant message and empty citations on a fresh session', async () => {
    const res = await request(app)
      .post(`/v1/sessions/${sessionId}/chat`)
      .send({ messages: [{ role: 'user', content: 'What did Sarah say?' }] });
    expect(res.status).toBe(200);
    expect(res.body.message.role).toBe('assistant');
    expect(res.body.message.content).toBe('mocked answer');
    expect(res.body.citations).toEqual([]);
    expect(res.body.usage.tokensIn).toBe(100);
  });

  it('404s for unknown session', async () => {
    const res = await request(app)
      .post('/v1/sessions/00000000-0000-0000-0000-000000000000/chat')
      .send({ messages: [{ role: 'user', content: 'q' }] });
    expect(res.status).toBe(404);
  });

  it('400s when messages is missing', async () => {
    const res = await request(app)
      .post(`/v1/sessions/${sessionId}/chat`)
      .send({});
    expect(res.status).toBe(400);
  });

  it('502s when chatService throws', async () => {
    anthropicMock.messages.create.mockRejectedValueOnce(new Error('Sonnet down'));
    const res = await request(app)
      .post(`/v1/sessions/${sessionId}/chat`)
      .send({ messages: [{ role: 'user', content: 'q' }] });
    expect(res.status).toBe(502);
  });
});

describe('POST /v1/chat (multi-session scope)', () => {
  let sess1;
  let sess2;

  beforeEach(async () => {
    anthropicMock.messages.create.mockClear();
    anthropicMock.messages.create.mockResolvedValue({
      content: [{ type: 'text', text: JSON.stringify({ answer: 'mocked answer', references: [] }) }],
      usage: { input_tokens: 100, output_tokens: 20 }
    });
    sess1 = await sessionsRepo.createSession({ userId: 'local-dev' });
    sess2 = await sessionsRepo.createSession({ userId: 'local-dev' });
    await sessionsRepo.saveTranscript(sess1, { text: 'talk one', words: [] });
    await sessionsRepo.saveTranscript(sess2, { text: 'talk two', words: [] });
  });

  it('aggregates two sessions and returns assistant message', async () => {
    const res = await request(app)
      .post('/v1/chat')
      .send({ sessionIds: [sess1, sess2], messages: [{ role: 'user', content: 'across talks' }] });
    expect(res.status).toBe(200);
    expect(res.body.message.role).toBe('assistant');
  });

  it('400s when sessionIds is missing or empty', async () => {
    const res = await request(app)
      .post('/v1/chat')
      .send({ messages: [{ role: 'user', content: 'q' }] });
    expect(res.status).toBe(400);
  });

  it('400s when messages is missing', async () => {
    const res = await request(app)
      .post('/v1/chat')
      .send({ sessionIds: [sess1] });
    expect(res.status).toBe(400);
  });

  it('404s when any session is unknown', async () => {
    const res = await request(app)
      .post('/v1/chat')
      .send({ sessionIds: [sess1, '00000000-0000-0000-0000-000000000000'], messages: [{ role: 'user', content: 'q' }] });
    expect(res.status).toBe(404);
  });
});
