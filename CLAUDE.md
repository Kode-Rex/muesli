# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Quick Start

### iOS App
```bash
# Build and run iOS app
./scripts/build.sh clean
./scripts/test.sh all
```

### API Backend
```bash
# Setup and start API server
cd src/api
cp .env.example .env
# Edit .env with DEEPGRAM_API_KEY=your_actual_key
npm install
npm run dev
```

## Development Commands

### iOS App Commands
**Note**: All scripts assume you're running from project root and target the iOS project at `src/mobile/Muesli.xcodeproj`.

- **Build**: `./scripts/build.sh [clean] [device]` - Builds the iOS app with optional clean build and device selection
- **Test**: `./scripts/test.sh [unit|ui|all] [device]` - Runs tests (defaults to all tests on iPhone 16)
- **Lint**: `./scripts/lint.sh [fix]` - Runs SwiftLint analysis, use `fix` to auto-correct issues
- **Single Test**: Use Xcode's test navigator or `xcodebuild test -scheme Muesli -only-testing:MuesliTests/SpecificTestClass/testMethod`
- **List Devices**: `xcrun simctl list devices available` - Show available iOS simulators

### API Backend Commands (in src/api/)
**Important**: All test commands require `NODE_OPTIONS='--experimental-vm-modules'` for ES modules support (already configured in package.json).

- **Development**: `npm run dev` - Starts server with nodemon for auto-reload
- **Production**: `npm start` - Starts production server
- **Test All**: `npm test` - Runs all tests with coverage (36 tests, uses ES modules)
- **Test Watch**: `npm run test:watch` - Runs tests in watch mode
- **Unit Tests**: `npm run test:unit` - Runs only unit tests
- **Integration Tests**: `npm run test:integration` - Runs only integration tests (requires server running)
- **Lint**: `npm run lint` or `npm run lint:fix` for auto-fix
- **Health Check**: `npm run health` - Checks if server is running (curl localhost:3000/health)
- **Docker Build**: `npm run docker:build` - Builds Docker image
- **Docker Run**: `npm run docker:run` - Runs containerized app

## Architecture Overview

Muesli is a full-stack conference note-taking platform with two main components:

### iOS App (`src/mobile/`)
- **Framework**: SwiftUI with SwiftData for persistence
- **Architecture**: MVVM-inspired with SwiftUI's native state management
- **Key Components**:
  - `MuesliApp.swift` - App entry point with SwiftData container setup
  - `Views/` - SwiftUI views organized by functionality
  - `Models/` - SwiftData models (Note.swift)
  - `SampleData/` - Development sample data management
  - `Services/` - Audio recording, transcription, networking services
  - `Config/` - API configuration and constants

### API Backend (`src/api/`)
- **Framework**: Node.js 18+ with Express.js
- **Architecture**: RESTful API with WebSocket support for real-time transcription
- **Key Components**:
  - `src/server.js` - Main server entry point with middleware setup
  - `src/routes/` - Express route handlers
  - `src/services/` - Business logic (Deepgram integration)
  - `src/middleware/` - Security, logging, rate limiting middleware
  - `src/config/` - Environment-based configuration
  - `src/utils/` - Logging utilities with Winston

## Code Quality Standards

### SwiftLint Configuration
The project uses a comprehensive SwiftLint setup (`.swiftlint.yml`) with:
- **Custom Rules**: Enforces AppLogger usage over print(), private @State properties, TODO issue references
- **40+ Enabled Rules**: Including force unwrapping warnings, code organization rules
- **File Headers Required**: All Swift files must include proper headers
- **Line Length**: 120 char warning, 150 char error
- **Performance**: Parallel linting enabled

### Logging Standards
- **iOS**: Use `AppLogger.shared` instead of `print()` statements
- **API**: Use Winston logger with structured logging and daily rotation
- Both platforms support different log levels (error, warn, info, debug)

## Key Architectural Patterns

### iOS Data Flow
- SwiftData models with fallback to in-memory storage if persistent storage fails
- Sample data seeding in debug builds only
- View models follow SwiftUI's @State and @StateObject patterns
- Services are designed as singletons for audio recording and network operations

### API Security Model
**Production-ready security stack for handling sensitive audio transcription**:

- **Multi-layer Security**: Helmet (security headers), CORS (cross-origin), rate limiting, input validation
- **Rate Limiting**: 
  - Global: 100 requests per 15min window
  - Transcription endpoint: 20 requests per 15min window
  - Configurable via .env variables
- **Request Processing**: 
  - Compression (level 6, 1KB threshold)
  - Body parsing limits (10MB max)
  - Request ID tracking for debugging
  - Slow-down middleware for additional protection
- **Graceful Shutdown**: 
  - SIGTERM/SIGINT handling
  - WebSocket connection cleanup
  - Deepgram service cleanup
  - 10-second forced shutdown timeout
- **Health Monitoring**: 
  - `/health` - Basic health check
  - `/health/detailed` - Full system status
  - `/health/metrics` - Performance metrics
  - Deepgram connectivity verification

### Data Persistence
- **iOS**: SwiftData with automatic fallback to in-memory if disk storage fails
- **API**: Stateless design, relies on external services (Deepgram) for processing

## Debugging & Troubleshooting

### Common Debugging Commands
```bash
# API server logs (live tail)
tail -f src/api/logs/muesli-api-current.log

# API error logs
tail -f src/api/logs/muesli-api-error-current.log

# Check API server health
curl -f http://localhost:3000/health

# iOS build issues - clean everything
./scripts/build.sh clean
rm -rf ~/Library/Developer/Xcode/DerivedData/Muesli-*
```

### Common Issues
- **Jest tests fail**: Ensure `NODE_OPTIONS='--experimental-vm-modules'` is set
- **Integration tests fail**: Start API server first (`npm run dev` in src/api/)
- **SwiftData errors**: Check console logs, app falls back to in-memory storage
- **SwiftLint path errors**: Ensure .swiftlint.yml includes correct paths under `src/mobile/`

## Dependencies & Key Integrations

### iOS Dependencies
- **SwiftUI** - Native declarative UI framework
- **SwiftData** - Apple's data persistence (with automatic fallback)
- **os.log** - Structured logging system (AppLogger.shared)
- **SwiftLint** - Code quality enforcement (40+ rules)

### API Dependencies
- **Express.js** - Web framework with comprehensive middleware
- **Deepgram SDK** - AI speech recognition service
- **Winston** - Structured logging with daily rotation
- **Jest** - Testing framework (ES modules support)
- **Docker** - Containerized deployment

## Environment Setup

### iOS Prerequisites
- iOS 17.0+, Xcode 15.0+, Swift 5.9+
- SwiftLint (auto-installed by lint script via Homebrew)

### API Prerequisites  
- Node.js 18+, npm 9+
- Deepgram API key in `.env` file (copy from .env.example)
- Optional: Docker for containerized deployment

### Required Environment Variables (.env)
```bash
# Essential for API functionality
DEEPGRAM_API_KEY=your_actual_deepgram_key_here
PORT=3000
NODE_ENV=development
LOG_LEVEL=info

# Optional but recommended
CORS_ORIGIN=http://localhost:3000
MAX_FILE_SIZE_MB=50
```

## Testing Strategy

### iOS Testing
- **Unit Tests**: `MuesliTests/` - Test core logic, models, utilities
- **UI Tests**: `MuesliUITests/` - Test user interactions and navigation
- **Test Organization**: Separate folders for different test categories
- **Coverage**: Use `./scripts/test.sh all` for coverage reports

### API Testing
- **36 Tests**: Comprehensive unit and integration tests
- **Jest Framework**: ES modules support with `NODE_OPTIONS='--experimental-vm-modules'`
- **Coverage Configuration**: 
  - Thresholds: 10% lines/statements, 1% branches/functions (intentionally low to start)
  - Reports: HTML, LCOV, JSON, text formats
  - Excludes: server.js, node_modules, test files
- **Test Timeout**: 10 seconds (configurable for integration tests)
- **Test Categories**: 
  - Unit tests (`tests/unit/`) - Individual component testing
  - Integration tests (`tests/integration/`) - Full API endpoint testing
- **Test Requirements**: API server must be running for integration tests