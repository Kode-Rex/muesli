/**
 * Transcription routes for Muesli Transcription API
 * Handles both batch and real-time transcription requests
 */

import express from 'express';
import multer from 'multer';
import { WebSocketServer } from 'ws';
import { config } from '../config/index.js';
import deepgramService from '../services/deepgramService.js';
import Logger from '../utils/logger.js';
import {
  transcriptionRateLimit,
  validateFileUpload,
  validateTranscriptionOptions,
  validateWebSocketOptions,
  handleValidationErrors
} from '../middleware/security.js';

const router = express.Router();

// Configure multer for audio file uploads
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: config.upload.maxFileSizeBytes,
    files: 1
  },
  fileFilter: (req, file, cb) => {
    if (config.upload.allowedMimeTypes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      Logger.warn('Unsupported file type rejected', {
        requestId: req.id,
        mimetype: file.mimetype,
        filename: file.originalname
      });
      cb(new Error(`Unsupported audio format: ${file.mimetype}`), false);
    }
  }
});

/**
 * Batch transcription endpoint
 * POST /transcribe
 */
router.post('/transcribe',
  transcriptionRateLimit,
  upload.single('audio'),
  validateFileUpload,
  validateTranscriptionOptions,
  handleValidationErrors,
  async (req, res) => {
    const startTime = Date.now();
    
    Logger.transcription('Batch transcription request received', {
      requestId: req.id,
      filename: req.file?.originalname,
      fileSize: req.file?.size,
      mimetype: req.file?.mimetype,
      ip: req.ip
    });

    try {
      // Extract transcription options from request body
      const options = {
        requestId: req.id,
        model: req.body.model,
        language: req.body.language,
        diarize: req.body.diarize === 'true' || req.body.diarize === true,
        punctuate: req.body.punctuate !== 'false' && req.body.punctuate !== false,
        utterances: req.body.utterances === 'true' || req.body.utterances === true,
        paragraphs: req.body.paragraphs === 'true' || req.body.paragraphs === true,
        deepgramOptions: {}
      };

      // Add any additional Deepgram-specific options
      if (req.body.smart_format !== undefined) {
        options.deepgramOptions.smart_format = req.body.smart_format === 'true';
      }
      if (req.body.filler_words !== undefined) {
        options.deepgramOptions.filler_words = req.body.filler_words === 'true';
      }

      // Transcribe the audio file
      const result = await deepgramService.transcribeFile(req.file.buffer, options);
      
      const duration = Date.now() - startTime;

      Logger.transcription('Batch transcription completed', {
        requestId: req.id,
        duration,
        transcriptLength: result.transcript.length,
        confidence: result.confidence,
        model: result.model
      });

      // Return the transcript in the format expected by the iOS app
      res.status(200).json({
        transcript: result.transcript,
        confidence: result.confidence,
        duration: duration,
        metadata: {
          model: result.model,
          language: result.language,
          requestId: req.id,
          processingTime: duration,
          ...result.metadata
        }
      });

    } catch (error) {
      const duration = Date.now() - startTime;
      
      Logger.error('Batch transcription failed', error, {
        requestId: req.id,
        duration,
        filename: req.file?.originalname,
        fileSize: req.file?.size
      });

      const statusCode = error.message.includes('authentication') ? 401 :
                        error.message.includes('rate limit') ? 429 :
                        error.message.includes('format') ? 400 : 500;

      res.status(statusCode).json({
        error: error.message,
        requestId: req.id,
        timestamp: new Date().toISOString(),
        processingTime: duration
      });
    }
  }
);

/**
 * Test transcription endpoint (for development)
 * POST /transcribe/test
 */
if (config.server.isDevelopment) {
  router.post('/transcribe/test',
    validateTranscriptionOptions,
    handleValidationErrors,
    async (req, res) => {
      Logger.transcription('Test transcription request', {
        requestId: req.id,
        body: req.body
      });

      // Return a mock response for testing
      res.status(200).json({
        transcript: "This is a test transcription response.",
        confidence: 0.95,
        duration: 150,
        metadata: {
          model: req.body.model || config.deepgram.model,
          language: req.body.language || config.deepgram.language,
          requestId: req.id,
          processingTime: 150,
          test: true
        }
      });
    }
  );
}

/**
 * WebSocket endpoint for real-time transcription
 * This is handled separately in the server.js file
 */
export const setupWebSocketServer = (server) => {
  const wss = new WebSocketServer({ 
    server,
    path: `/api/${config.server.apiVersion}/transcribe/realtime`
  });

  // Track active connections
  const activeConnections = new Map();

  wss.on('connection', (ws, request) => {
    const connectionId = `ws-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    const ip = request.socket.remoteAddress;
    
    Logger.websocket('WebSocket connection opened', connectionId, {
      ip,
      userAgent: request.headers['user-agent']
    });

    // Initialize connection state
    activeConnections.set(connectionId, {
      ws,
      deepgramConnection: null,
      startTime: Date.now(),
      lastActivity: Date.now(),
      ip
    });

    // Handle connection setup message
    ws.on('message', async (data) => {
      const connectionInfo = activeConnections.get(connectionId);
      if (!connectionInfo) return;

      connectionInfo.lastActivity = Date.now();

      try {
        const message = JSON.parse(data.toString());

        if (message.type === 'start') {
          // Initialize Deepgram connection
          Logger.websocket('Starting real-time transcription', connectionId, {
            options: message.options
          });

          const options = {
            connectionId,
            model: message.options?.model,
            language: message.options?.language,
            interim_results: message.options?.interim_results !== false,
            deepgramOptions: message.options || {}
          };

          const deepgramConnection = await deepgramService.createRealtimeConnection(options);
          connectionInfo.deepgramConnection = deepgramConnection;

          // Forward transcription results to WebSocket client
          deepgramConnection.connection.on('Results', (transcriptData) => {
            if (ws.readyState === ws.OPEN) {
              ws.send(JSON.stringify({
                type: 'transcript',
                data: transcriptData,
                connectionId
              }));
            }
          });

          // Handle Deepgram connection events
          deepgramConnection.connection.on('error', (error) => {
            Logger.error('Deepgram WebSocket error', error, { connectionId });
            
            if (ws.readyState === ws.OPEN) {
              ws.send(JSON.stringify({
                type: 'error',
                error: error.message,
                connectionId
              }));
            }
          });

          // Confirm connection started
          ws.send(JSON.stringify({
            type: 'started',
            connectionId,
            message: 'Real-time transcription started'
          }));

        } else if (message.type === 'stop') {
          // Stop transcription
          Logger.websocket('Stopping real-time transcription', connectionId);
          
          if (connectionInfo.deepgramConnection) {
            connectionInfo.deepgramConnection.close();
            connectionInfo.deepgramConnection = null;
          }

          ws.send(JSON.stringify({
            type: 'stopped',
            connectionId,
            message: 'Real-time transcription stopped'
          }));
        }

      } catch (error) {
        Logger.error('WebSocket message handling error', error, { connectionId });
        
        if (ws.readyState === ws.OPEN) {
          ws.send(JSON.stringify({
            type: 'error',
            error: 'Invalid message format',
            connectionId
          }));
        }
      }
    });

    // Handle raw audio data
    ws.on('message', (data) => {
      if (data instanceof Buffer && data.length > 100) {
        const connectionInfo = activeConnections.get(connectionId);
        
        if (connectionInfo?.deepgramConnection) {
          connectionInfo.lastActivity = Date.now();
          
          try {
            connectionInfo.deepgramConnection.send(data);
          } catch (error) {
            Logger.error('Failed to send audio data to Deepgram', error, { connectionId });
          }
        }
      }
    });

    // Handle connection close
    ws.on('close', (code, reason) => {
      const connectionInfo = activeConnections.get(connectionId);
      const sessionDuration = connectionInfo ? 
        Date.now() - connectionInfo.startTime : 0;

      Logger.websocket('WebSocket connection closed', connectionId, {
        code,
        reason: reason.toString(),
        sessionDuration
      });

      if (connectionInfo?.deepgramConnection) {
        connectionInfo.deepgramConnection.close();
      }

      activeConnections.delete(connectionId);
    });

    // Handle connection errors
    ws.on('error', (error) => {
      Logger.error('WebSocket connection error', error, { connectionId });
      
      const connectionInfo = activeConnections.get(connectionId);
      if (connectionInfo?.deepgramConnection) {
        connectionInfo.deepgramConnection.close();
      }
      
      activeConnections.delete(connectionId);
    });

    // Send heartbeat
    const heartbeatInterval = setInterval(() => {
      if (ws.readyState === ws.OPEN) {
        ws.ping();
      } else {
        clearInterval(heartbeatInterval);
      }
    }, config.websocket.heartbeatIntervalMs);
  });

  // Cleanup stale connections periodically
  const cleanupInterval = setInterval(() => {
    deepgramService.cleanupStaleConnections();
    
    const now = Date.now();
    for (const [connectionId, connectionInfo] of activeConnections.entries()) {
      if (now - connectionInfo.lastActivity > config.websocket.connectionTimeoutMs) {
        Logger.warn('Cleaning up stale WebSocket connection', { connectionId });
        
        if (connectionInfo.deepgramConnection) {
          connectionInfo.deepgramConnection.close();
        }
        
        if (connectionInfo.ws.readyState === connectionInfo.ws.OPEN) {
          connectionInfo.ws.close();
        }
        
        activeConnections.delete(connectionId);
      }
    }
  }, 60000); // Check every minute

  // Cleanup on server shutdown
  process.on('SIGTERM', () => {
    clearInterval(cleanupInterval);
    
    for (const [connectionId, connectionInfo] of activeConnections.entries()) {
      if (connectionInfo.deepgramConnection) {
        connectionInfo.deepgramConnection.close();
      }
      if (connectionInfo.ws.readyState === connectionInfo.ws.OPEN) {
        connectionInfo.ws.close();
      }
    }
  });

  Logger.info('WebSocket server initialized', {
    path: `/api/${config.server.apiVersion}/transcribe/realtime`,
    heartbeatInterval: config.websocket.heartbeatIntervalMs,
    connectionTimeout: config.websocket.connectionTimeoutMs
  });

  return wss;
};

export default router;