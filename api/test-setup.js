#!/usr/bin/env node
/**
 * Quick setup test for Muesli Transcription API
 * Verifies configuration and dependencies
 */

import { config } from './src/config/index.js';
import Logger from './src/utils/logger.js';
import deepgramService from './src/services/deepgramService.js';

console.log('🧪 Testing Muesli Transcription API Setup...\n');

// Test 1: Configuration
console.log('1️⃣  Testing Configuration...');
try {
  console.log('✅ Configuration loaded successfully');
  console.log(`   Environment: ${config.server.environment}`);
  console.log(`   API Version: ${config.server.apiVersion}`);
  console.log(`   Port: ${config.server.port}`);
  console.log(`   Deepgram Model: ${config.deepgram.model}`);
  console.log(`   Log Level: ${config.logging.level}`);
  console.log(`   Max File Size: ${config.upload.maxFileSizeMB}MB`);
} catch (error) {
  console.log('❌ Configuration failed:', error.message);
  process.exit(1);
}

// Test 2: Logger
console.log('\n2️⃣  Testing Logger...');
try {
  Logger.info('Test log message');
  Logger.warn('Test warning message');
  Logger.debug('Test debug message');
  console.log('✅ Logger working correctly');
} catch (error) {
  console.log('❌ Logger failed:', error.message);
}

// Test 3: Deepgram Service
console.log('\n3️⃣  Testing Deepgram Service...');
try {
  const healthCheck = await deepgramService.healthCheck();
  
  if (healthCheck.healthy) {
    console.log('✅ Deepgram service is healthy');
    console.log(`   Latency: ${healthCheck.latency}ms`);
  } else {
    console.log('⚠️  Deepgram service is not healthy');
    console.log(`   Error: ${healthCheck.error}`);
    console.log('   This might be due to invalid API key or network issues');
  }
} catch (error) {
  console.log('❌ Deepgram service test failed:', error.message);
  console.log('   Please check your DEEPGRAM_API_KEY in .env file');
}

// Test 4: Dependencies
console.log('\n4️⃣  Testing Dependencies...');
const requiredDeps = [
  'express',
  '@deepgram/sdk',
  'winston',
  'helmet',
  'cors',
  'multer',
  'express-rate-limit'
];

let depErrors = 0;
for (const dep of requiredDeps) {
  try {
    await import(dep);
    console.log(`   ✅ ${dep}`);
  } catch (error) {
    console.log(`   ❌ ${dep} - ${error.message}`);
    depErrors++;
  }
}

if (depErrors === 0) {
  console.log('✅ All dependencies are available');
} else {
  console.log(`❌ ${depErrors} dependencies are missing. Run: npm install`);
}

// Test 5: File Structure
console.log('\n5️⃣  Testing File Structure...');
import { access } from 'fs/promises';
import { constants } from 'fs';

const requiredFiles = [
  'src/config/index.js',
  'src/utils/logger.js',
  'src/services/deepgramService.js',
  'src/middleware/security.js',
  'src/routes/health.js',
  'src/routes/transcription.js',
  'src/server.js',
  '.env.example'
];

let fileErrors = 0;
for (const file of requiredFiles) {
  try {
    await access(file, constants.F_OK);
    console.log(`   ✅ ${file}`);
  } catch (error) {
    console.log(`   ❌ ${file} - Missing`);
    fileErrors++;
  }
}

if (fileErrors === 0) {
  console.log('✅ All required files are present');
} else {
  console.log(`❌ ${fileErrors} required files are missing`);
}

// Test 6: Environment Variables
console.log('\n6️⃣  Testing Environment Variables...');
const requiredEnvVars = ['DEEPGRAM_API_KEY'];
const recommendedEnvVars = ['PORT', 'NODE_ENV', 'LOG_LEVEL'];

let envErrors = 0;
for (const envVar of requiredEnvVars) {
  if (process.env[envVar]) {
    console.log(`   ✅ ${envVar} is set`);
  } else {
    console.log(`   ❌ ${envVar} is not set (required)`);
    envErrors++;
  }
}

for (const envVar of recommendedEnvVars) {
  if (process.env[envVar]) {
    console.log(`   ✅ ${envVar} is set`);
  } else {
    console.log(`   ⚠️  ${envVar} is not set (recommended)`);
  }
}

// Summary
console.log('\n📋 Setup Test Summary');
console.log('='.repeat(50));

if (depErrors === 0 && fileErrors === 0 && envErrors === 0) {
  console.log('🎉 Setup test completed successfully!');
  console.log('   Your API is ready to start.');
  console.log('\n🚀 Next steps:');
  console.log('   1. Run: npm start');
  console.log('   2. Test: curl http://localhost:3000/health');
  console.log('   3. Check logs: tail -f logs/muesli-api-current.log');
} else {
  console.log('⚠️  Setup test found issues:');
  if (depErrors > 0) console.log(`   - ${depErrors} missing dependencies`);
  if (fileErrors > 0) console.log(`   - ${fileErrors} missing files`);
  if (envErrors > 0) console.log(`   - ${envErrors} missing environment variables`);
  console.log('\n🔧 Please fix the issues above before starting the server.');
}

console.log('\n📚 For help, see README.md or check the logs.');
process.exit(0);