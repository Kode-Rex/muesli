/**
 * Configuration management for Muesli Transcription API
 * Centralized configuration with environment variable validation
 */

import dotenv from 'dotenv';
import Joi from 'joi';

// Load environment variables
dotenv.config();

// Configuration schema validation
const configSchema = Joi.object({
  // Deepgram Configuration
  DEEPGRAM_API_KEY: Joi.string().required().messages({
    'any.required': 'DEEPGRAM_API_KEY is required in environment variables',
    'string.empty': 'DEEPGRAM_API_KEY cannot be empty'
  }),
  DEEPGRAM_MODEL: Joi.string().default('nova-2'),
  DEEPGRAM_LANGUAGE: Joi.string().default('en-US'),

  // Server Configuration
  PORT: Joi.number().port().default(3000),
  NODE_ENV: Joi.string().valid('development', 'production', 'test').default('production'),
  API_VERSION: Joi.string().default('v1'),

  // Security Configuration
  CORS_ORIGIN: Joi.string()
    .when('NODE_ENV', {
      is: 'production',
      then: Joi.string().required().disallow('*').messages({
        'any.required': 'CORS_ORIGIN is required in production and must not be "*"',
        'any.invalid': 'CORS_ORIGIN must not be "*" in production'
      }),
      otherwise: Joi.string().default('http://localhost:3000')
    }),
  API_RATE_LIMIT_WINDOW_MS: Joi.number().default(15 * 60 * 1000), // 15 minutes
  API_RATE_LIMIT_MAX_REQUESTS: Joi.number().default(100),
  TRANSCRIPTION_RATE_LIMIT_MAX_REQUESTS: Joi.number().default(20),

  // File Upload Configuration
  MAX_FILE_SIZE_MB: Joi.number().default(50),
  MAX_UPLOAD_DURATION_SECONDS: Joi.number().default(3600), // 1 hour

  // Logging Configuration
  LOG_LEVEL: Joi.string().valid('error', 'warn', 'info', 'debug').default('info'),
  LOG_RETENTION_DAYS: Joi.number().default(30),

  // Health Check Configuration
  HEALTH_CHECK_TIMEOUT_MS: Joi.number().default(5000),

  // WebSocket Configuration
  WS_HEARTBEAT_INTERVAL_MS: Joi.number().default(30000),
  WS_CONNECTION_TIMEOUT_MS: Joi.number().default(300000), // 5 minutes

  // Optional Monitoring
  SENTRY_DSN: Joi.string().allow(''),
  NEW_RELIC_LICENSE_KEY: Joi.string().allow(''),

  // Optional Database
  REDIS_URL: Joi.string().allow(''),
  DATABASE_URL: Joi.string().allow('')
}).unknown(true); // Allow other environment variables

// Validate configuration
const { error, value: envVars } = configSchema.validate(process.env);

if (error) {
  console.error('❌ Configuration validation error:', error.details[0].message);
  process.exit(1);
}

// Export validated configuration
export const config = {
  // Deepgram settings
  deepgram: {
    apiKey: envVars.DEEPGRAM_API_KEY,
    model: envVars.DEEPGRAM_MODEL,
    language: envVars.DEEPGRAM_LANGUAGE
  },

  // Server settings
  server: {
    port: envVars.PORT,
    environment: envVars.NODE_ENV,
    apiVersion: envVars.API_VERSION,
    isProduction: envVars.NODE_ENV === 'production',
    isDevelopment: envVars.NODE_ENV === 'development',
    isTest: envVars.NODE_ENV === 'test'
  },

  // Security settings
  security: {
    corsOrigin: envVars.CORS_ORIGIN.split(',').map(origin => origin.trim()),
    rateLimiting: {
      windowMs: envVars.API_RATE_LIMIT_WINDOW_MS,
      maxRequests: envVars.API_RATE_LIMIT_MAX_REQUESTS,
      transcriptionMaxRequests: envVars.TRANSCRIPTION_RATE_LIMIT_MAX_REQUESTS
    }
  },

  // File upload settings
  upload: {
    maxFileSizeMB: envVars.MAX_FILE_SIZE_MB,
    maxFileSizeBytes: envVars.MAX_FILE_SIZE_MB * 1024 * 1024,
    maxDurationSeconds: envVars.MAX_UPLOAD_DURATION_SECONDS,
    allowedMimeTypes: [
      'audio/mp4',
      'audio/mpeg',
      'audio/wav', 
      'audio/webm',
      'audio/ogg',
      'audio/m4a',
      'audio/x-m4a'
    ]
  },

  // Logging settings
  logging: {
    level: envVars.LOG_LEVEL,
    retentionDays: envVars.LOG_RETENTION_DAYS
  },

  // Health check settings
  health: {
    timeoutMs: envVars.HEALTH_CHECK_TIMEOUT_MS
  },

  // WebSocket settings
  websocket: {
    heartbeatIntervalMs: envVars.WS_HEARTBEAT_INTERVAL_MS,
    connectionTimeoutMs: envVars.WS_CONNECTION_TIMEOUT_MS
  },

  // Optional monitoring
  monitoring: {
    sentryDsn: envVars.SENTRY_DSN,
    newRelicKey: envVars.NEW_RELIC_LICENSE_KEY
  },

  // Optional database
  database: {
    redisUrl: envVars.REDIS_URL,
    databaseUrl: envVars.DATABASE_URL
  }
};

// Configuration validation summary
console.log('✅ Configuration loaded successfully');
console.log(`📡 API Version: ${config.server.apiVersion}`);
console.log(`🌍 Environment: ${config.server.environment}`);
console.log(`🔑 Deepgram Model: ${config.deepgram.model}`);
console.log(`📝 Log Level: ${config.logging.level}`);

export default config;