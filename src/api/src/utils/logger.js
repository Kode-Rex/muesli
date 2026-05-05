/**
 * Production-grade logging system for Muesli Transcription API
 * Winston-based logging with multiple transports and structured logging
 */

import winston from 'winston';
import DailyRotateFile from 'winston-daily-rotate-file';
import { config } from '../config/index.js';
import { redactConfig, SECRET_PATTERN } from './redactConfig.js';

// Walk the log info object and redact secret-shaped fields. Skip the
// canonical fields (level, message, timestamp) that Winston manages.
const redactFormat = winston.format((info) => {
  const skip = new Set(['level', 'message', 'timestamp', Symbol.for('level'), Symbol.for('message'), Symbol.for('splat')]);
  for (const k of Reflect.ownKeys(info)) {
    if (skip.has(k)) continue;
    if (typeof k === 'string' && SECRET_PATTERN.test(k)) {
      info[k] = '[REDACTED]';
    } else {
      info[k] = redactConfig(info[k]);
    }
  }
  return info;
})();

// Custom log format for structured logging
const logFormat = winston.format.combine(
  redactFormat,
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss.SSS' }),
  winston.format.errors({ stack: true }),
  winston.format.json(),
  winston.format.printf(({ timestamp, level, message, service, requestId, userId, duration, ...meta }) => {
    const logEntry = {
      timestamp,
      level,
      message,
      service: service || 'muesli-api',
      ...(requestId && { requestId }),
      ...(userId && { userId }),
      ...(duration !== undefined && { duration: `${duration}ms` }),
      ...meta
    };

    if (config.server.isDevelopment) {
      // Human-readable format for development
      return `[${timestamp}] ${level.toUpperCase()}: ${message}${requestId ? ` (${requestId})` : ''}${Object.keys(meta).length ? ` ${JSON.stringify(meta)}` : ''}`;
    }

    return JSON.stringify(logEntry);
  })
);

// Console transport for development
const consoleTransport = new winston.transports.Console({
  level: config.logging.level,
  format: winston.format.combine(
    winston.format.colorize({ all: true }),
    logFormat
  )
});

// File transport for all logs
const fileTransport = new DailyRotateFile({
  filename: 'logs/muesli-api-%DATE%.log',
  datePattern: 'YYYY-MM-DD',
  maxSize: '100m',
  maxFiles: `${config.logging.retentionDays}d`,
  level: config.logging.level,
  format: logFormat,
  createSymlink: true,
  symlinkName: 'muesli-api-current.log'
});

// Error log transport
const errorTransport = new DailyRotateFile({
  filename: 'logs/muesli-api-error-%DATE%.log',
  datePattern: 'YYYY-MM-DD',
  maxSize: '100m',
  maxFiles: `${config.logging.retentionDays}d`,
  level: 'error',
  format: logFormat,
  createSymlink: true,
  symlinkName: 'muesli-api-error-current.log'
});

// Create logger instance
const logger = winston.createLogger({
  level: config.logging.level,
  format: logFormat,
  defaultMeta: { service: 'muesli-api' },
  transports: [
    consoleTransport,
    fileTransport,
    errorTransport
  ],
  // Handle uncaught exceptions and unhandled rejections
  exceptionHandlers: [
    new DailyRotateFile({
      filename: 'logs/muesli-api-exceptions-%DATE%.log',
      datePattern: 'YYYY-MM-DD',
      maxSize: '100m',
      maxFiles: `${config.logging.retentionDays}d`,
      format: logFormat
    })
  ],
  rejectionHandlers: [
    new DailyRotateFile({
      filename: 'logs/muesli-api-rejections-%DATE%.log',
      datePattern: 'YYYY-MM-DD',
      maxSize: '100m',
      maxFiles: `${config.logging.retentionDays}d`,
      format: logFormat
    })
  ]
});

// Enhanced logging methods for specific use cases
export class Logger {
  static info(message, meta = {}) {
    logger.info(message, meta);
  }

  static error(message, error = null, meta = {}) {
    const errorMeta = error ? {
      error: {
        message: error.message,
        stack: error.stack,
        name: error.name
      }
    } : {};
    
    logger.error(message, { ...errorMeta, ...meta });
  }

  static warn(message, meta = {}) {
    logger.warn(message, meta);
  }

  static debug(message, meta = {}) {
    logger.debug(message, meta);
  }

  // Request logging
  static request(req, res, duration) {
    const requestMeta = {
      requestId: req.id,
      method: req.method,
      url: req.url,
      userAgent: req.get('User-Agent'),
      ip: req.ip,
      statusCode: res.statusCode,
      duration,
      contentLength: res.get('content-length') || 0
    };

    if (res.statusCode >= 400) {
      this.error(`HTTP ${req.method} ${req.url}`, null, requestMeta);
    } else {
      this.info(`HTTP ${req.method} ${req.url}`, requestMeta);
    }
  }

  // Transcription-specific logging
  static transcription(action, meta = {}) {
    this.info(`Transcription: ${action}`, {
      category: 'transcription',
      action,
      ...meta
    });
  }

  // WebSocket logging
  static websocket(action, connectionId, meta = {}) {
    this.info(`WebSocket: ${action}`, {
      category: 'websocket',
      action,
      connectionId,
      ...meta
    });
  }

  // Security logging
  static security(action, meta = {}) {
    this.warn(`Security: ${action}`, {
      category: 'security',
      action,
      ...meta
    });
  }

  // Performance logging
  static performance(operation, duration, meta = {}) {
    const level = duration > 5000 ? 'warn' : duration > 1000 ? 'info' : 'debug';
    
    logger.log(level, `Performance: ${operation}`, {
      category: 'performance',
      operation,
      duration,
      ...meta
    });
  }

  // Health check logging
  static health(component, status, meta = {}) {
    const level = status === 'healthy' ? 'debug' : 'warn';
    
    logger.log(level, `Health: ${component} is ${status}`, {
      category: 'health',
      component,
      status,
      ...meta
    });
  }

  // Deepgram-specific logging
  static deepgram(action, meta = {}) {
    this.info(`Deepgram: ${action}`, {
      category: 'deepgram',
      action,
      ...meta
    });
  }

  // Rate limiting logging
  static rateLimit(ip, endpoint, meta = {}) {
    this.security('Rate limit exceeded', {
      ip,
      endpoint,
      ...meta
    });
  }
}

// Export logger instance for direct use
export { logger };
export default Logger;