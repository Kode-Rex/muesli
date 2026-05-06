/**
 * Integration test — end-to-end sessions flow with all SDKs mocked
 * Tests: POST /sessions → /audio → /photos → /blend → GET /:id
 */

import { describe, it, expect, jest } from '@jest/globals';
import request from 'supertest';

// Mock logger to prevent file system operations
jest.unstable_mockModule('../../src/utils/logger.js', () => ({
  default: {
    info: jest.fn(),
    error: jest.fn(),
    warn: jest.fn(),
    debug: jest.fn(),
    health: jest.fn(),
    transcription: jest.fn(),
    websocket: jest.fn(),
    request: jest.fn()
  }
}));

// Mock config to provide all required values
jest.unstable_mockModule('../../src/config/index.js', () => ({
  config: {
    server: {
      apiVersion: 'v1',
      environment: 'test',
      isDevelopment: false,
      isProduction: false,
      port: 3001
    },
    health: { timeoutMs: 5000 },
    logging: { level: 'error' },
    deepgram: { model: 'nova-2', language: 'en', apiKey: 'test-key' },
    anthropic: { apiKey: 'test-key' },
    security: {
      corsOrigin: 'http://localhost:3000',
      rateLimiting: {
        windowMs: 15 * 60 * 1000,
        maxRequests: 1000,
        transcriptionMaxRequests: 1000
      }
    },
    upload: {
      maxFileSizeMB: 50,
      maxFileSizeBytes: 50 * 1024 * 1024,
      allowedMimeTypes: ['audio/wav', 'audio/mpeg', 'audio/mp3', 'audio/mp4', 'audio/m4a', 'audio/ogg', 'audio/webm', 'image/jpeg', 'image/png']
    },
    websocket: {
      heartbeatIntervalMs: 30000,
      connectionTimeoutMs: 60000
    },
    auth: { enabled: false, jwtSecret: 'x'.repeat(32), devUserId: 'local-dev', accessTokenTtlMin: 15, refreshTokenTtlDays: 30, googleClientId: '' },
    credits: { enforced: false, pricingVersion: 1, newUserGrantMicros: 0 },
    database: { databaseUrl: '' }
  }
}));

// Mock Deepgram service to avoid real API calls
jest.unstable_mockModule('../../src/services/deepgramService.js', () => ({
  default: {
    transcribeBuffer: jest.fn().mockResolvedValue({
      transcript: 'Hello this is a test talk',
      words: [
        { word: 'Hello', start: 0, end: 0.5 },
        { word: 'this', start: 0.6, end: 0.8 },
        { word: 'is', start: 0.9, end: 1.0 },
        { word: 'a', start: 1.1, end: 1.2 },
        { word: 'test', start: 1.3, end: 1.5 },
        { word: 'talk', start: 1.6, end: 2.0 }
      ]
    }),
    healthCheck: jest.fn().mockResolvedValue({ healthy: true, latency: 10 }),
    cleanupStaleConnections: jest.fn(),
    isConnected: true,
    getStats: jest.fn().mockReturnValue({ activeConnections: 0, isConnected: true })
  }
}));

// Mock the Anthropic singleton used by all AI services
jest.unstable_mockModule('../../src/services/anthropic.js', () => {
  const createMock = jest.fn().mockImplementation(async ({ model, messages }) => {
    const hasImage = messages?.some?.(m =>
      Array.isArray(m.content) && m.content.some(c => c.type === 'image')
    );

    // Image extract: haiku + image block
    if (model.includes('haiku') && hasImage) {
      return {
        content: [{ type: 'text', text: JSON.stringify({ ocrText: 'Slide text', description: 'A slide' }) }],
        usage: { input_tokens: 100, output_tokens: 30 }
      };
    }

    // Chapterize: haiku without image
    if (model.includes('haiku')) {
      return {
        content: [{ type: 'text', text: JSON.stringify({ chapters: [{ start: 0, title: 'Opening', summary: 'intro' }] }) }],
        usage: { input_tokens: 200, output_tokens: 50 }
      };
    }

    // Blend: sonnet
    return {
      content: [{ type: 'text', text: JSON.stringify({
        blendedMarkdown: 'Hello this is a test talk.\n\ncool',
        userNoteSpans: [{ start: 28, end: 32 }],
        quoteSpans: [],
        imagePlacements: [],
        citations: []
      }) }],
      usage: { input_tokens: 500, output_tokens: 100 }
    };
  });

  return {
    anthropic: { messages: { create: createMock } },
    HAIKU_MODEL: 'claude-haiku-4-5-20251001',
    SONNET_MODEL: 'claude-sonnet-4-6'
  };
});

// Import app AFTER all mocks are registered
const { app } = await import('../../src/server.js');

describe('Sessions flow E2E', () => {
  it('runs the full pipeline and returns a blended note', async () => {
    // Step 1: Create session
    const create = await request(app).post('/v1/sessions').send();
    expect(create.status).toBe(200);
    const sessionId = create.body.sessionId;
    expect(sessionId).toBeTruthy();

    // Step 2: Upload audio
    const audio = await request(app)
      .post(`/v1/sessions/${sessionId}/audio`)
      .field('durationSeconds', '60')
      .attach('audio', Buffer.from('fakeaudio'), { filename: 't.m4a', contentType: 'audio/mp4' });
    expect(audio.status).toBe(200);

    // Step 3: Upload photo
    const photo = await request(app)
      .post(`/v1/sessions/${sessionId}/photos`)
      .field('photoId', 'p1')
      .field('capturedAt', String(Date.now()))
      .attach('photo', Buffer.from('fakejpg'), { filename: 's.jpg', contentType: 'image/jpeg' });
    expect(photo.status).toBe(200);
    expect(photo.body.ocrText).toBe('Slide text');

    // Step 4: Blend
    const blend = await request(app)
      .post(`/v1/sessions/${sessionId}/blend`)
      .send({ userNotes: 'cool' });
    expect(blend.status).toBe(200);
    expect(blend.body.blendedMarkdown).toContain('Hello');
    expect(blend.body.chapters).toHaveLength(1);
    expect(blend.body.costMicros).toBeGreaterThan(0);

    // Step 5: Get final session state
    const get = await request(app).get(`/v1/sessions/${sessionId}`);
    expect(get.status).toBe(200);
    expect(get.body.status).toBe('complete');
  });

  it('returns 400 when blending without transcript', async () => {
    // Create a fresh session with no audio uploaded
    const create = await request(app).post('/v1/sessions').send();
    expect(create.status).toBe(200);
    const id = create.body.sessionId;

    const blend = await request(app)
      .post(`/v1/sessions/${id}/blend`)
      .send({ userNotes: '' });
    expect(blend.status).toBe(400);
    expect(blend.body.error).toBe('no_transcript');
  });
});
