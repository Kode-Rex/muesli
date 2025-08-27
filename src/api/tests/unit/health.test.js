/**
 * Unit tests for health check endpoints
 */

import { jest } from '@jest/globals';
import request from 'supertest';
import express from 'express';

// Create the mocks
const mockDeepgramService = {
  healthCheck: jest.fn().mockResolvedValue({
    healthy: true,
    latency: 50
  }),
  isConnected: true,
  getStats: jest.fn().mockReturnValue({
    activeConnections: 0,
    isConnected: true,
    connectionDetails: {}
  }),
  cleanupStaleConnections: jest.fn()
};

const mockConfig = {
  server: {
    apiVersion: 'v1',
    environment: 'test'
  },
  health: {
    timeoutMs: 5000
  },
  logging: {
    level: 'error'
  },
  deepgram: {
    model: 'nova-2',
    language: 'en'
  },
  security: {
    rateLimiting: {
      windowMs: 15 * 60 * 1000,
      maxRequests: 100
    }
  },
  upload: {
    maxFileSizeMB: 25
  }
};

// Mock the logger to prevent file system operations
jest.unstable_mockModule('../../src/utils/logger.js', () => ({
  default: {
    info: jest.fn(),
    error: jest.fn(),
    warn: jest.fn(),
    debug: jest.fn(),
    health: jest.fn()
  }
}));

// Mock the modules before importing
jest.unstable_mockModule('../../src/services/deepgramService.js', () => ({
  default: mockDeepgramService
}));

jest.unstable_mockModule('../../src/config/index.js', () => ({
  config: mockConfig
}));

// Now import the routes after mocking
const { default: healthRoutes } = await import('../../src/routes/health.js');

const mockRequestId = 'test-req-12345';
const testHeaders = {
  'Content-Type': 'application/json',
  'User-Agent': 'Muesli-Test/1.0.0'
};

describe('Health Routes', () => {
  let app;

  beforeEach(() => {
    app = express();
    app.use(express.json());
    
    // Mock request ID middleware
    app.use((req, res, next) => {
      req.id = mockRequestId;
      next();
    });
    
    app.use(healthRoutes);
    jest.clearAllMocks();
  });

  describe('GET /health', () => {
    test('should return healthy status', async () => {
      const response = await request(app)
        .get('/health')
        .set(testHeaders)
        .expect(200);

      expect(response.body).toMatchObject({
        status: 'healthy',
        version: 'v1',
        environment: 'test',
        requestId: mockRequestId
      });

      expect(response.body).toHaveProperty('timestamp');
      expect(response.body).toHaveProperty('uptime');
      expect(typeof response.body.uptime).toBe('number');
    });

    test('should handle errors gracefully', async () => {
      // Mock an error condition
      const originalUptime = process.uptime;
      process.uptime = jest.fn().mockImplementation(() => {
        throw new Error('System error');
      });

      const response = await request(app)
        .get('/health')
        .set(testHeaders)
        .expect(503);

      expect(response.body).toMatchObject({
        status: 'unhealthy',
        error: 'System error',
        requestId: mockRequestId
      });

      // Restore original function
      process.uptime = originalUptime;
    });
  });

  describe('GET /health/detailed', () => {
    test('should return detailed health information', async () => {
      const response = await request(app)
        .get('/health/detailed')
        .set(testHeaders);

      expect(response.status).toBe(200);
      
      expect(response.body).toMatchObject({
        status: 'healthy',
        requestId: mockRequestId
      });

      expect(response.body.checks).toHaveProperty('api');
      expect(response.body.checks).toHaveProperty('deepgram');
      expect(response.body.checks).toHaveProperty('system');
      expect(response.body.checks).toHaveProperty('config');

      expect(response.body.checks.api).toMatchObject({
        status: 'healthy'
      });

      expect(response.body.checks.deepgram).toMatchObject({
        status: 'healthy',
        connected: true
      });
      // Don't check exact latency since it might vary slightly
      expect(response.body.checks.deepgram.latency).toBeGreaterThan(0);
    });

    test('should return degraded status when Deepgram is unhealthy', async () => {
      mockDeepgramService.healthCheck.mockResolvedValueOnce({
        healthy: false,
        error: 'Connection failed',
        latency: null
      });

      const response = await request(app)
        .get('/health/detailed')
        .set(testHeaders)
        .expect(200); // Still 200 but degraded status

      expect(response.body.status).toBe('degraded');
      expect(response.body.checks.deepgram).toMatchObject({
        status: 'unhealthy',
        error: 'Connection failed',
        connected: true // From our mock service
      });
    });

    test('should handle Deepgram timeout', async () => {
      mockDeepgramService.healthCheck.mockImplementation(() => 
        new Promise(resolve => setTimeout(() => resolve({ healthy: true }), 6000))
      );

      const response = await request(app)
        .get('/health/detailed')
        .set(testHeaders)
        .expect(200);

      expect(response.body.status).toBe('degraded');
      expect(response.body.checks.deepgram.error).toContain('timeout');
    });
  });

  describe('GET /health/ready', () => {
    test('should return ready status when all services are healthy', async () => {
      const response = await request(app)
        .get('/health/ready')
        .set(testHeaders)
        .expect(200);

      expect(response.body).toMatchObject({
        status: 'ready',
        requestId: mockRequestId
      });

      expect(mockDeepgramService.healthCheck).toHaveBeenCalled();
    });

    test('should return not-ready when Deepgram is unhealthy', async () => {
      mockDeepgramService.healthCheck.mockResolvedValueOnce({
        healthy: false,
        error: 'Service unavailable'
      });

      const response = await request(app)
        .get('/health/ready')
        .set(testHeaders)
        .expect(503);

      expect(response.body).toMatchObject({
        status: 'not-ready',
        error: 'Deepgram service not ready: Service unavailable',
        requestId: mockRequestId
      });
    });
  });

  describe('GET /health/live', () => {
    test('should always return alive status', async () => {
      const response = await request(app)
        .get('/health/live')
        .set(testHeaders)
        .expect(200);

      expect(response.body).toMatchObject({
        status: 'alive',
        requestId: mockRequestId
      });

      expect(response.body).toHaveProperty('timestamp');
      expect(response.body).toHaveProperty('uptime');
    });
  });

  describe('GET /health/metrics', () => {
    test('should return system metrics', async () => {
      const response = await request(app)
        .get('/health/metrics')
        .set(testHeaders)
        .expect(200);

      expect(response.body).toHaveProperty('timestamp');
      expect(response.body).toHaveProperty('requestId', mockRequestId);
      expect(response.body).toHaveProperty('api');
      expect(response.body).toHaveProperty('deepgram');
      expect(response.body).toHaveProperty('system');

      expect(response.body.api).toHaveProperty('uptime');
      expect(response.body.api).toHaveProperty('memory');
      expect(response.body.system).toHaveProperty('platform');
      expect(response.body.system).toHaveProperty('nodeVersion');
    });

    test('should handle metrics error gracefully', async () => {
      mockDeepgramService.getStats.mockImplementationOnce(() => {
        throw new Error('Stats unavailable');
      });

      const response = await request(app)
        .get('/health/metrics')
        .set(testHeaders)
        .expect(500);

      expect(response.body).toMatchObject({
        error: 'Failed to retrieve metrics',
        requestId: mockRequestId
      });
    });
  });
});
