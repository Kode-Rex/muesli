/**
 * Muesli Transcription API Server
 * Production-ready Express server with Deepgram integration
 */

import express from 'express';
import http from 'http';
import compression from 'compression';
import morgan from 'morgan';
import { config } from './config/index.js';
import Logger from './utils/logger.js';
import {
  corsMiddleware,
  helmetMiddleware,
  generalRateLimit,
  slowDownMiddleware,
  requestIdMiddleware,
  requestLogger,
  securityAudit,
  errorHandler,
  notFoundHandler
} from './middleware/security.js';
import healthRoutes from './routes/health.js';
import transcriptionRoutes, { setupWebSocketServer } from './routes/transcription.js';
import sessionsRouter from './routes/sessions.js';
import deepgramService from './services/deepgramService.js';

// Create Express application
const app = express();
const server = http.createServer(app);

// Trust proxy for accurate IP addresses in production
if (config.server.isProduction) {
  app.set('trust proxy', 1);
}

// Security middleware
app.use(helmetMiddleware);
app.use(corsMiddleware);
app.use(securityAudit);

// Request processing middleware
app.use(compression({
  level: 6,
  threshold: 1024,
  filter: (req, res) => {
    if (req.headers['x-no-compression']) {
      return false;
    }
    return compression.filter(req, res);
  }
}));

app.use(express.json({ 
  limit: '10mb',
  strict: true,
  type: 'application/json'
}));

app.use(express.urlencoded({ 
  extended: true, 
  limit: '10mb' 
}));

// Logging middleware
app.use(requestIdMiddleware);

if (config.server.isDevelopment) {
  app.use(morgan('dev'));
} else {
  app.use(morgan('combined', {
    stream: {
      write: (message) => Logger.info(message.trim(), { category: 'access' })
    }
  }));
}

app.use(requestLogger);

// Rate limiting middleware
app.use(generalRateLimit);
app.use(slowDownMiddleware);

// API routes
const apiPrefix = `/api/${config.server.apiVersion}`;

// Health check routes (before rate limiting for monitoring)
app.use(healthRoutes);
app.use(apiPrefix, healthRoutes);

// Main API routes
app.use(apiPrefix, transcriptionRoutes);

// Sessions pipeline routes
app.use('/v1/sessions', sessionsRouter);

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    name: 'Muesli Transcription API',
    version: config.server.apiVersion,
    environment: config.server.environment,
    status: 'running',
    timestamp: new Date().toISOString(),
    endpoints: {
      health: '/health',
      detailedHealth: '/health/detailed',
      readiness: '/health/ready',
      liveness: '/health/live',
      metrics: '/health/metrics',
      transcribe: `${apiPrefix}/transcribe`,
      realtimeTranscribe: `ws://localhost:${config.server.port}${apiPrefix}/transcribe/realtime`
    },
    documentation: {
      postman: 'Import the provided Postman collection',
      swagger: 'Available at /api/docs (if enabled)',
      readme: 'See README.md for detailed API documentation'
    }
  });
});

// Setup WebSocket server for real-time transcription
const wss = setupWebSocketServer(server);

// Error handling middleware (must be last)
app.use(notFoundHandler);
app.use(errorHandler);

// Graceful shutdown handling
const gracefulShutdown = (signal) => {
  Logger.info(`Received ${signal}, starting graceful shutdown...`);
  
  server.close((err) => {
    if (err) {
      Logger.error('Error during server shutdown', err);
      process.exit(1);
    }
    
    Logger.info('HTTP server closed');
    
    // Close WebSocket connections
    wss.close(() => {
      Logger.info('WebSocket server closed');
      
      // Cleanup Deepgram connections
      deepgramService.cleanupStaleConnections(0); // Close all connections
      
      Logger.info('Graceful shutdown completed');
      process.exit(0);
    });
  });
  
  // Force shutdown after 10 seconds
  setTimeout(() => {
    Logger.error('Forced shutdown after timeout');
    process.exit(1);
  }, 10000);
};

// Handle shutdown signals
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// Handle uncaught exceptions and unhandled rejections
process.on('uncaughtException', (err) => {
  Logger.error('Uncaught Exception', err);
  gracefulShutdown('UNCAUGHT_EXCEPTION');
});

process.on('unhandledRejection', (reason, promise) => {
  Logger.error('Unhandled Rejection', new Error(reason), { 
    promise: promise.toString() 
  });
  gracefulShutdown('UNHANDLED_REJECTION');
});

// Start server
const startServer = async () => {
  try {
    // Verify Deepgram service is available
    Logger.info('Checking Deepgram service connectivity...');
    const healthCheck = await deepgramService.healthCheck();
    
    if (!healthCheck.healthy) {
      Logger.warn('Deepgram service is not healthy, but starting server anyway', {
        error: healthCheck.error
      });
    } else {
      Logger.info('Deepgram service is healthy', {
        latency: healthCheck.latency
      });
    }

    // Start HTTP server
    server.listen(config.server.port, () => {
      Logger.info('🚀 Muesli Transcription API started successfully', {
        port: config.server.port,
        environment: config.server.environment,
        apiVersion: config.server.apiVersion,
        nodeVersion: process.version,
        deepgramModel: config.deepgram.model,
        deepgramLanguage: config.deepgram.language,
        maxFileSize: config.upload.maxFileSizeMB + 'MB',
        logLevel: config.logging.level
      });

      Logger.info('📡 Available endpoints:', {
        health: `http://localhost:${config.server.port}/health`,
        transcribe: `http://localhost:${config.server.port}${apiPrefix}/transcribe`,
        realtime: `ws://localhost:${config.server.port}${apiPrefix}/transcribe/realtime`,
        metrics: `http://localhost:${config.server.port}/health/metrics`
      });

      // Log configuration summary
      Logger.info('⚙️  Configuration summary:', {
        rateLimiting: {
          window: config.security.rateLimiting.windowMs / 1000 + 's',
          maxRequests: config.security.rateLimiting.maxRequests,
          transcriptionMax: config.security.rateLimiting.transcriptionMaxRequests
        },
        upload: {
          maxSize: config.upload.maxFileSizeMB + 'MB',
          allowedTypes: config.upload.allowedMimeTypes.length + ' formats'
        },
        websocket: {
          heartbeat: config.websocket.heartbeatIntervalMs / 1000 + 's',
          timeout: config.websocket.connectionTimeoutMs / 1000 + 's'
        }
      });
    });

  } catch (error) {
    Logger.error('Failed to start server', error);
    process.exit(1);
  }
};

// Start the server
startServer();