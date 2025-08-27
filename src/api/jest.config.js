/**
 * Jest configuration for Muesli API tests
 */

export default {
  // Use Node.js environment for testing
  testEnvironment: 'node',
  
  // Enable ES modules support
  preset: null,
  transform: {},
  
  // Test file patterns
  testMatch: [
    '**/tests/**/*.test.js',
    '**/tests/**/*.spec.js'
  ],
  
  // Setup files
  setupFilesAfterEnv: [
    '<rootDir>/tests/helpers/testSetup.js'
  ],
  
  // Coverage configuration
  collectCoverage: true,
  coverageDirectory: 'coverage',
  coverageReporters: [
    'text',
    'text-summary',
    'html',
    'lcov',
    'json'
  ],
  
  // Coverage thresholds (very low to start - we'll increase as tests improve)
  coverageThreshold: {
    global: {
      branches: 1,
      functions: 1,
      lines: 10,
      statements: 10
    }
  },
  
  // Files to collect coverage from
  collectCoverageFrom: [
    'src/**/*.js',
    '!src/server.js', // Exclude main server file from coverage
    '!**/node_modules/**',
    '!**/tests/**',
    '!**/coverage/**'
  ],
  
  // Module paths
  moduleFileExtensions: ['js', 'json'],
  
  // Test timeout (increase for integration tests)
  testTimeout: 10000,
  
  // Clear mocks between tests
  clearMocks: true,
  
  // Verbose output for debugging
  verbose: true,
  
  // Transform ignore patterns for ES modules
  transformIgnorePatterns: [
    'node_modules/(?!(supertest|@jest/globals)/)'
  ],
  

  
  // Mock certain modules for testing
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/src/$1'
  },
  
  // Force exit after tests complete
  forceExit: true,
  
  // Detect handles that prevent Jest from exiting
  detectOpenHandles: true,
  
  // Maximum worker processes
  maxWorkers: '50%'
};
