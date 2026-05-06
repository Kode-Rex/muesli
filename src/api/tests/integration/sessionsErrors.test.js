/**
 * Integration tests — failure paths for /v1/sessions
 * Covers: transcribe failure, photo extract failure, blend failure,
 * 404 on unknown session, 400 on missing payloads.
 */

import { describe, it, expect, jest, beforeEach } from '@jest/globals';
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
    upload: {
      maxFileSizeMB: 50, maxFileSizeBytes: 50 * 1024 * 1024,
      allowedMimeTypes: ['audio/wav', 'audio/mpeg', 'audio/mp4', 'image/jpeg']
    },
    websocket: { heartbeatIntervalMs: 30000, connectionTimeoutMs: 60000 },
    auth: { enabled: false, jwtSecret: 'x'.repeat(32), devUserId: 'local-dev', accessTokenTtlMin: 15, refreshTokenTtlDays: 30, googleClientId: '' },
    credits: { enforced: false, pricingVersion: 1, newUserGrantMicros: 0 },
    database: { databaseUrl: '' }
  }
}));

const transcribeMock = jest.fn();

jest.unstable_mockModule('../../src/services/deepgramService.js', () => ({
  default: {
    transcribeBuffer: transcribeMock,
    healthCheck: jest.fn().mockResolvedValue({ healthy: true, latency: 10 }),
    cleanupStaleConnections: jest.fn(),
    isConnected: true,
    getStats: jest.fn().mockReturnValue({ activeConnections: 0, isConnected: true })
  }
}));

const anthropicCreate = jest.fn();
jest.unstable_mockModule('../../src/services/anthropic.js', () => ({
  anthropic: { messages: { create: anthropicCreate } },
  HAIKU_MODEL: 'claude-haiku-4-5-20251001',
  SONNET_MODEL: 'claude-sonnet-4-6'
}));

const { app } = await import('../../src/server.js');

describe('Sessions error paths', () => {
  beforeEach(() => {
    transcribeMock.mockReset();
    anthropicCreate.mockReset();
  });

  it('returns 404 when getting an unknown session', async () => {
    const res = await request(app).get('/v1/sessions/does-not-exist');
    expect(res.status).toBe(404);
    expect(res.body.error).toBe('session_not_found');
  });

  it('returns 404 when uploading audio to an unknown session', async () => {
    const res = await request(app)
      .post('/v1/sessions/nope/audio')
      .field('durationSeconds', '10')
      .attach('audio', Buffer.from('x'), { filename: 'a.m4a', contentType: 'audio/mp4' });
    expect(res.status).toBe(404);
  });

  it('returns 400 when audio file is missing', async () => {
    const create = await request(app).post('/v1/sessions').send();
    const id = create.body.sessionId;
    const res = await request(app).post(`/v1/sessions/${id}/audio`).field('durationSeconds', '10');
    expect(res.status).toBe(400);
    expect(res.body.error).toBe('audio_missing');
  });

  it('marks session failed and returns 500 when Deepgram throws', async () => {
    transcribeMock.mockRejectedValueOnce(new Error('deepgram boom'));
    const create = await request(app).post('/v1/sessions').send();
    const id = create.body.sessionId;

    const res = await request(app)
      .post(`/v1/sessions/${id}/audio`)
      .field('durationSeconds', '10')
      .attach('audio', Buffer.from('x'), { filename: 'a.m4a', contentType: 'audio/mp4' });

    expect(res.status).toBe(500);
    expect(res.body.error).toBe('transcribe_failed');

    const get = await request(app).get(`/v1/sessions/${id}`);
    expect(get.body.status).toBe('failed');
    expect(get.body.error).toMatch(/deepgram boom/);
  });

  it('marks the photo as failed (not the session) when Haiku extract throws', async () => {
    transcribeMock.mockResolvedValueOnce({ transcript: 'hi', words: [] });
    anthropicCreate.mockRejectedValueOnce(new Error('haiku boom'));

    const create = await request(app).post('/v1/sessions').send();
    const id = create.body.sessionId;

    await request(app)
      .post(`/v1/sessions/${id}/audio`)
      .field('durationSeconds', '5')
      .attach('audio', Buffer.from('x'), { filename: 'a.m4a', contentType: 'audio/mp4' });

    const photo = await request(app)
      .post(`/v1/sessions/${id}/photos`)
      .field('photoId', 'p1')
      .field('capturedAt', String(Date.now()))
      .attach('photo', Buffer.from('xx'), { filename: 'p.jpg', contentType: 'image/jpeg' });

    expect(photo.status).toBe(500);
    expect(photo.body.error).toBe('extract_failed');

    const get = await request(app).get(`/v1/sessions/${id}`);
    expect(get.body.status).toBe('transcribed');
    expect(get.body.photos).toHaveLength(1);
    expect(get.body.photos[0].extractStatus).toBe('failed');
  });

  it('returns 500 and marks session failed when Sonnet blend throws', async () => {
    transcribeMock.mockResolvedValueOnce({ transcript: 'hi there', words: [] });
    // chapterize call (haiku, no image) succeeds
    anthropicCreate.mockResolvedValueOnce({
      content: [{ type: 'text', text: JSON.stringify({ chapters: [{ start: 0, title: 'A', summary: '' }] }) }],
      usage: { input_tokens: 10, output_tokens: 10 }
    });
    // sonnet blend throws
    anthropicCreate.mockRejectedValueOnce(new Error('sonnet boom'));

    const create = await request(app).post('/v1/sessions').send();
    const id = create.body.sessionId;

    await request(app)
      .post(`/v1/sessions/${id}/audio`)
      .field('durationSeconds', '5')
      .attach('audio', Buffer.from('x'), { filename: 'a.m4a', contentType: 'audio/mp4' });

    const blend = await request(app)
      .post(`/v1/sessions/${id}/blend`)
      .send({ userNotes: '' });

    expect(blend.status).toBe(500);
    expect(blend.body.error).toBe('blend_failed');

    const get = await request(app).get(`/v1/sessions/${id}`);
    expect(get.body.status).toBe('failed');
  });

  it('records a cost entry on successful blend', async () => {
    transcribeMock.mockResolvedValueOnce({ transcript: 'hello world', words: [] });
    // chapterize
    anthropicCreate.mockResolvedValueOnce({
      content: [{ type: 'text', text: JSON.stringify({ chapters: [{ start: 0, title: 'Opening', summary: '' }] }) }],
      usage: { input_tokens: 100, output_tokens: 50 }
    });
    // blend
    anthropicCreate.mockResolvedValueOnce({
      content: [{ type: 'text', text: JSON.stringify({
        blendedMarkdown: 'Hello world.', userNoteSpans: [], quoteSpans: [], imagePlacements: [], citations: []
      }) }],
      usage: { input_tokens: 500, output_tokens: 100 }
    });

    const create = await request(app).post('/v1/sessions').send();
    const id = create.body.sessionId;

    await request(app)
      .post(`/v1/sessions/${id}/audio`)
      .field('durationSeconds', '60')
      .attach('audio', Buffer.from('x'), { filename: 'a.m4a', contentType: 'audio/mp4' });

    const blend = await request(app)
      .post(`/v1/sessions/${id}/blend`)
      .send({ userNotes: '' });

    expect(blend.status).toBe(200);
    expect(blend.body.costMicros).toBeGreaterThan(0);

    const { sessionsRepo } = await import('../../src/services/sessionsRepo.js');
    const entries = await sessionsRepo.listCostEntries('local-dev');
    const entry = entries.find(e => e.sessionId === id);
    expect(entry).toBeTruthy();
    expect(entry.microsDelta).toBe(-blend.body.costMicros);
    expect(entry.reason).toBe('blend');
  });
});
