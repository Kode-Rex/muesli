/**
 * Security middleware for Muesli Transcription API
 * Comprehensive security, rate limiting, and validation
 */

import rateLimit from 'express-rate-limit';
import slowDown from 'express-slow-down';
import helmet from 'helmet';
import cors from 'cors';
import { body, validationResult } from 'express-validator';
import { config } from '../config/index.js';
import Logger from '../utils/logger.js';

/**
 * CORS configuration
 */
export const corsMiddleware = cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (mobile apps, curl, Postman, etc.)
    if (!origin) return callback(null, true);
    
    if (config.security.corsOrigin.includes('*') || 
        config.security.corsOrigin.includes(origin)) {
      return callback(null, true);
    }
    
    Logger.security('CORS origin rejected', { origin });
    return callback(new Error('Not allowed by CORS'));
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: [
    'Origin',
    'X-Requested-With', 
    'Content-Type',
    'Accept',
    'Authorization',
    'X-Request-ID'
  ],
  maxAge: 86400 // 24 hours
});

/**
 * Helmet security headers
 */
export const helmetMiddleware = helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'", "wss:", "ws:"],
      fontSrc: ["'self'"],
      objectSrc: ["'none'"],
      mediaSrc: ["'self'"],
      frameSrc: ["'none'"]
    }
  },
  crossOriginEmbedderPolicy: false, // Allow audio file uploads
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
});

/**
 * General API rate limiting
 */
export const generalRateLimit = rateLimit({
  windowMs: config.security.rateLimiting.windowMs,
  max: config.security.rateLimiting.maxRequests,
  message: {
    error: 'Too many requests from this IP',
    retryAfter: Math.ceil(config.security.rateLimiting.windowMs / 1000)
  },
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res, next, options) => {
    Logger.rateLimit(req.ip, req.path, {
      userAgent: req.get('User-Agent'),
      method: req.method
    });
    
    res.status(options.statusCode).json(options.message);
  },
  skip: (req) => {
    // Skip rate limiting for health checks
    return req.path === '/health' || req.path === `/api/${config.server.apiVersion}/health`;
  }
});

/**
 * Strict rate limiting for transcription endpoints
 */
export const transcriptionRateLimit = rateLimit({
  windowMs: config.security.rateLimiting.windowMs,
  max: config.security.rateLimiting.transcriptionMaxRequests,
  message: {
    error: 'Too many transcription requests from this IP',
    retryAfter: Math.ceil(config.security.rateLimiting.windowMs / 1000),
    hint: 'Transcription endpoints have stricter rate limits'
  },
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res, next, options) => {
    Logger.rateLimit(req.ip, req.path, {
      userAgent: req.get('User-Agent'),
      method: req.method,
      endpoint: 'transcription'
    });
    
    res.status(options.statusCode).json(options.message);
  }
});

/**
 * Slow down middleware for progressive delays
 */
export const slowDownMiddleware = slowDown({
  windowMs: config.security.rateLimiting.windowMs,
  delayAfter: Math.floor(config.security.rateLimiting.maxRequests * 0.5),
  delayMs: 500,
  maxDelayMs: 20000,
  skipFailedRequests: false,
  skipSuccessfulRequests: false,
  onLimitReached: (req, res, options) => {
    Logger.security('Slow down limit reached', {
      ip: req.ip,
      path: req.path,
      delay: options.delay
    });
  }
});

/**
 * Request ID middleware
 */
export const requestIdMiddleware = (req, res, next) => {
  req.id = req.get('X-Request-ID') || 
           `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  
  res.set('X-Request-ID', req.id);
  next();
};

/**
 * Request logging middleware
 */
export const requestLogger = (req, res, next) => {
  const startTime = Date.now();
  
  // Log request start
  Logger.info('Request started', {
    requestId: req.id,
    method: req.method,
    url: req.url,
    ip: req.ip,
    userAgent: req.get('User-Agent'),
    contentLength: req.get('content-length') || 0
  });

  // Override res.end to capture response
  const originalEnd = res.end;
  res.end = function(chunk, encoding) {
    const duration = Date.now() - startTime;
    
    Logger.request(req, res, duration);
    
    originalEnd.call(this, chunk, encoding);
  };

  next();
};

/**
 * File upload validation
 */
export const validateFileUpload = [
  body('audio').custom((value, { req }) => {
    if (!req.file) {
      throw new Error('Audio file is required');
    }

    // Check file size
    if (req.file.size > config.upload.maxFileSizeBytes) {
      throw new Error(`File size exceeds ${config.upload.maxFileSizeMB}MB limit`);
    }

    // Check MIME type
    if (!config.upload.allowedMimeTypes.includes(req.file.mimetype)) {
      throw new Error(`Unsupported audio format: ${req.file.mimetype}`);
    }

    return true;
  })
];

/**
 * Transcription options validation
 */
export const validateTranscriptionOptions = [
  body('model')
    .optional()
    .isString()
    .isLength({ min: 1, max: 50 })
    .withMessage('Model must be a string between 1-50 characters'),
  
  body('language')
    .optional()
    .matches(/^[a-z]{2}(-[A-Z]{2})?$/)
    .withMessage('Language must be in format: en or en-US'),
  
  body('diarize')
    .optional()
    .isBoolean()
    .withMessage('Diarize must be a boolean'),
  
  body('punctuate')
    .optional()
    .isBoolean()
    .withMessage('Punctuate must be a boolean'),
  
  body('utterances')
    .optional()
    .isBoolean()
    .withMessage('Utterances must be a boolean'),
  
  body('paragraphs')
    .optional()
    .isBoolean()
    .withMessage('Paragraphs must be a boolean')
];

/**
 * WebSocket connection validation
 */
export const validateWebSocketOptions = [
  body('model')
    .optional()
    .isString()
    .isLength({ min: 1, max: 50 }),
  
  body('language')
    .optional()
    .matches(/^[a-z]{2}(-[A-Z]{2})?$/),
  
  body('interim_results')
    .optional()
    .isBoolean(),
  
  body('punctuate')
    .optional()
    .isBoolean()
];

/**
 * Validation error handler
 */
export const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);
  
  if (!errors.isEmpty()) {
    const errorDetails = errors.array().map(error => ({
      field: error.path,
      message: error.msg,
      value: error.value
    }));

    Logger.warn('Validation errors', {
      requestId: req.id,
      errors: errorDetails,
      ip: req.ip
    });

    return res.status(400).json({
      error: 'Validation failed',
      details: errorDetails
    });
  }
  
  next();
};

/**
 * Error handling middleware
 */
export const errorHandler = (err, req, res, next) => {
  const statusCode = err.statusCode || err.status || 500;
  const message = err.message || 'Internal Server Error';
  
  Logger.error('Request error', err, {
    requestId: req.id,
    statusCode,
    method: req.method,
    url: req.url,
    ip: req.ip
  });

  // Don't expose internal errors in production
  const responseMessage = config.server.isProduction && statusCode === 500 
    ? 'Internal Server Error' 
    : message;

  res.status(statusCode).json({
    error: responseMessage,
    requestId: req.id,
    timestamp: new Date().toISOString()
  });
};

/**
 * 404 handler
 */
export const notFoundHandler = (req, res) => {
  Logger.warn('Route not found', {
    requestId: req.id,
    method: req.method,
    url: req.url,
    ip: req.ip,
    userAgent: req.get('User-Agent')
  });

  res.status(404).json({
    error: 'Route not found',
    requestId: req.id,
    availableEndpoints: [
      `GET /api/${config.server.apiVersion}/health`,
      `POST /api/${config.server.apiVersion}/transcribe`,
      `WS /api/${config.server.apiVersion}/transcribe/realtime`
    ]
  });
};

/**
 * Security audit middleware (logs suspicious activity)
 */
export const securityAudit = (req, res, next) => {
  const suspiciousPatterns = [
    /(\.\.|\/\/|\\\\)/,  // Path traversal
    /(script|javascript|vbscript)/i,  // Script injection
    /(union|select|insert|delete|update|drop)/i,  // SQL injection
    /(<|>|&lt;|&gt;)/,  // HTML/XML injection
    /(eval|exec|system|cmd)/i  // Command injection
  ];

  const userAgent = req.get('User-Agent') || '';
  const url = req.url || '';
  const body = JSON.stringify(req.body || {});

  for (const pattern of suspiciousPatterns) {
    if (pattern.test(url) || pattern.test(body) || pattern.test(userAgent)) {
      Logger.security('Suspicious request detected', {
        requestId: req.id,
        ip: req.ip,
        userAgent,
        url,
        pattern: pattern.toString()
      });
      break;
    }
  }

  next();
};

export default {
  corsMiddleware,
  helmetMiddleware,
  generalRateLimit,
  transcriptionRateLimit,
  slowDownMiddleware,
  requestIdMiddleware,
  requestLogger,
  validateFileUpload,
  validateTranscriptionOptions,
  validateWebSocketOptions,
  handleValidationErrors,
  errorHandler,
  notFoundHandler,
  securityAudit
};