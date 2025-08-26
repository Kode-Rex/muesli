/**
 * Health check routes for Muesli Transcription API
 * Comprehensive health monitoring and service status
 */

import express from 'express';
import { config } from '../config/index.js';
import deepgramService from '../services/deepgramService.js';
import Logger from '../utils/logger.js';

const router = express.Router();

/**
 * Basic health check endpoint
 * GET /health
 */
router.get('/health', async (req, res) => {
  const startTime = Date.now();
  
  try {
    const healthStatus = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      version: config.server.apiVersion,
      environment: config.server.environment,
      uptime: process.uptime(),
      requestId: req.id
    };

    const duration = Date.now() - startTime;
    Logger.health('api', 'healthy', { duration, requestId: req.id });

    res.status(200).json(healthStatus);
    
  } catch (error) {
    const duration = Date.now() - startTime;
    Logger.health('api', 'unhealthy', { duration, error: error.message, requestId: req.id });

    res.status(503).json({
      status: 'unhealthy',
      error: error.message,
      timestamp: new Date().toISOString(),
      requestId: req.id
    });
  }
});

/**
 * Detailed health check with service dependencies
 * GET /health/detailed
 */
router.get('/health/detailed', async (req, res) => {
  const startTime = Date.now();
  const healthChecks = {};
  let overallStatus = 'healthy';

  try {
    // Check API server health
    healthChecks.api = {
      status: 'healthy',
      uptime: process.uptime(),
      memory: {
        used: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
        total: Math.round(process.memoryUsage().heapTotal / 1024 / 1024),
        rss: Math.round(process.memoryUsage().rss / 1024 / 1024)
      },
      cpu: process.cpuUsage()
    };

    // Check Deepgram service health
    try {
      const deepgramHealth = await Promise.race([
        deepgramService.healthCheck(),
        new Promise((_, reject) => 
          setTimeout(() => reject(new Error('Health check timeout')), config.health.timeoutMs)
        )
      ]);

      healthChecks.deepgram = {
        status: deepgramHealth.healthy ? 'healthy' : 'unhealthy',
        latency: deepgramHealth.latency,
        connected: deepgramService.isConnected,
        activeConnections: deepgramService.getStats().activeConnections,
        error: deepgramHealth.error
      };

      if (!deepgramHealth.healthy) {
        overallStatus = 'degraded';
      }

    } catch (error) {
      healthChecks.deepgram = {
        status: 'unhealthy',
        error: error.message,
        connected: false,
        activeConnections: 0
      };
      overallStatus = 'degraded';
    }

    // Check system resources
    healthChecks.system = {
      status: 'healthy',
      nodeVersion: process.version,
      platform: process.platform,
      arch: process.arch,
      loadAverage: process.platform !== 'win32' ? require('os').loadavg() : null,
      freeMemory: Math.round(require('os').freemem() / 1024 / 1024),
      totalMemory: Math.round(require('os').totalmem() / 1024 / 1024)
    };

    // Check configuration
    healthChecks.config = {
      status: 'healthy',
      apiVersion: config.server.apiVersion,
      environment: config.server.environment,
      logLevel: config.logging.level,
      deepgramModel: config.deepgram.model,
      deepgramLanguage: config.deepgram.language,
      maxFileSize: config.upload.maxFileSizeMB + 'MB',
      rateLimitWindow: config.security.rateLimiting.windowMs / 1000 + 's',
      rateLimitMax: config.security.rateLimiting.maxRequests
    };

    const response = {
      status: overallStatus,
      timestamp: new Date().toISOString(),
      duration: Date.now() - startTime,
      requestId: req.id,
      checks: healthChecks
    };

    const statusCode = overallStatus === 'healthy' ? 200 : 
                      overallStatus === 'degraded' ? 200 : 503;

    Logger.health('detailed-check', overallStatus, {
      duration: response.duration,
      requestId: req.id,
      checks: Object.keys(healthChecks).reduce((acc, key) => {
        acc[key] = healthChecks[key].status;
        return acc;
      }, {})
    });

    res.status(statusCode).json(response);

  } catch (error) {
    const duration = Date.now() - startTime;
    
    Logger.error('Detailed health check failed', error, {
      duration,
      requestId: req.id
    });

    res.status(503).json({
      status: 'unhealthy',
      error: error.message,
      timestamp: new Date().toISOString(),
      duration,
      requestId: req.id,
      checks: healthChecks
    });
  }
});

/**
 * Ready check for container orchestration
 * GET /health/ready
 */
router.get('/health/ready', async (req, res) => {
  const startTime = Date.now();

  try {
    // Check if all critical services are ready
    const deepgramHealth = await deepgramService.healthCheck();
    
    if (!deepgramHealth.healthy) {
      throw new Error(`Deepgram service not ready: ${deepgramHealth.error}`);
    }

    const duration = Date.now() - startTime;
    
    Logger.health('ready-check', 'ready', { duration, requestId: req.id });

    res.status(200).json({
      status: 'ready',
      timestamp: new Date().toISOString(),
      duration,
      requestId: req.id
    });

  } catch (error) {
    const duration = Date.now() - startTime;
    
    Logger.health('ready-check', 'not-ready', { 
      duration, 
      error: error.message, 
      requestId: req.id 
    });

    res.status(503).json({
      status: 'not-ready',
      error: error.message,
      timestamp: new Date().toISOString(),
      duration,
      requestId: req.id
    });
  }
});

/**
 * Liveness check for container orchestration
 * GET /health/live
 */
router.get('/health/live', (req, res) => {
  // Simple liveness check - just verify the process is running
  Logger.health('liveness-check', 'alive', { requestId: req.id });

  res.status(200).json({
    status: 'alive',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    requestId: req.id
  });
});

/**
 * Service metrics endpoint
 * GET /health/metrics
 */
router.get('/health/metrics', (req, res) => {
  const startTime = Date.now();

  try {
    const stats = deepgramService.getStats();
    const memUsage = process.memoryUsage();
    
    const metrics = {
      timestamp: new Date().toISOString(),
      requestId: req.id,
      api: {
        uptime: process.uptime(),
        requests: {
          // Note: In production, you'd want to track these metrics
          // using a proper metrics system like Prometheus
          total: 'Not tracked - use APM solution',
          current: 'Not tracked - use APM solution'
        },
        memory: {
          heapUsed: Math.round(memUsage.heapUsed / 1024 / 1024),
          heapTotal: Math.round(memUsage.heapTotal / 1024 / 1024),
          rss: Math.round(memUsage.rss / 1024 / 1024),
          external: Math.round(memUsage.external / 1024 / 1024)
        },
        cpu: process.cpuUsage()
      },
      deepgram: {
        connected: stats.isConnected,
        activeConnections: stats.activeConnections,
        connectionDetails: stats.connectionDetails
      },
      system: {
        platform: process.platform,
        nodeVersion: process.version,
        pid: process.pid,
        freeMemory: Math.round(require('os').freemem() / 1024 / 1024),
        totalMemory: Math.round(require('os').totalmem() / 1024 / 1024),
        cpuCount: require('os').cpus().length,
        loadAverage: process.platform !== 'win32' ? require('os').loadavg() : null
      }
    };

    const duration = Date.now() - startTime;
    
    Logger.debug('Metrics requested', { duration, requestId: req.id });

    res.status(200).json(metrics);

  } catch (error) {
    const duration = Date.now() - startTime;
    
    Logger.error('Failed to get metrics', error, { 
      duration, 
      requestId: req.id 
    });

    res.status(500).json({
      error: 'Failed to retrieve metrics',
      timestamp: new Date().toISOString(),
      requestId: req.id
    });
  }
});

export default router;