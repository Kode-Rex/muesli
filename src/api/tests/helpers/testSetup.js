/**
 * Test setup and helper functions for Muesli API tests
 */

import { jest } from '@jest/globals';

// Mock environment variables for testing
process.env.NODE_ENV = 'test';
process.env.DEEPGRAM_API_KEY = 'test-key-mock';
process.env.PORT = '0'; // Use random port for testing
process.env.LOG_LEVEL = 'error'; // Reduce log noise in tests

// Mock Deepgram service for tests
export const mockDeepgramService = {
  healthCheck: jest.fn().mockResolvedValue({
    healthy: true,
    latency: 50
  }),
  transcribeFile: jest.fn().mockResolvedValue({
    transcript: 'This is a test transcription.',
    confidence: 0.95,
    model: 'nova-2',
    language: 'en',
    metadata: {
      duration: 10.5,
      channels: 1
    }
  }),
  createRealtimeConnection: jest.fn().mockResolvedValue({
    connection: {
      on: jest.fn(),
      send: jest.fn()
    },
    close: jest.fn()
  }),
  isConnected: true,
  getStats: jest.fn().mockReturnValue({
    activeConnections: 0,
    isConnected: true,
    connectionDetails: {}
  }),
  cleanupStaleConnections: jest.fn()
};

// Test utilities
export const createTestAudioBuffer = () => {
  // Create a small test audio buffer (simulated WAV header + data)
  const buffer = Buffer.alloc(1024);
  buffer.write('RIFF', 0);
  buffer.writeUInt32LE(1016, 4);
  buffer.write('WAVE', 8);
  return buffer;
};

export const createLargeTestAudioBuffer = (sizeMB = 50) => {
  // Create a buffer larger than the upload limit for testing
  return Buffer.alloc(sizeMB * 1024 * 1024);
};

// Mock request ID for consistent testing
export const mockRequestId = 'test-req-12345';

// Common test headers
export const testHeaders = {
  'Content-Type': 'application/json',
  'User-Agent': 'Muesli-Test/1.0.0'
};

// Test configuration override
export const testConfig = {
  server: {
    port: 0,
    environment: 'test',
    apiVersion: 'v1',
    isDevelopment: false,
    isProduction: false
  },
  upload: {
    maxFileSizeMB: 25,
    maxFileSizeBytes: 25 * 1024 * 1024,
    allowedMimeTypes: [
      'audio/wav',
      'audio/mpeg',
      'audio/mp3',
      'audio/mp4',
      'audio/m4a',
      'audio/ogg',
      'audio/webm'
    ]
  },
  security: {
    rateLimiting: {
      windowMs: 15 * 60 * 1000,
      maxRequests: 1000, // Higher limit for tests
      transcriptionMaxRequests: 100
    }
  }
};

// Jest setup
beforeAll(() => {
  // Suppress console logs during tests unless debugging
  if (!process.env.DEBUG_TESTS) {
    console.log = jest.fn();
    console.warn = jest.fn();
    console.error = jest.fn();
  }
});

afterAll(() => {
  // Cleanup any resources
  jest.clearAllMocks();
});
