# Muesli Transcription API

Production-ready Node.js API server for audio transcription using Deepgram, designed to work with the Muesli iOS app.

## 🚀 Features

- **Batch Audio Transcription**: Upload audio files for transcription
- **Real-time Transcription**: WebSocket-based live audio transcription
- **Production Security**: Rate limiting, CORS, helmet, input validation
- **Comprehensive Logging**: Structured logging with Winston
- **Health Checks**: Multiple health check endpoints for monitoring
- **Docker Support**: Full containerization with multi-stage builds
- **Error Handling**: Graceful error handling and recovery
- **🧪 Comprehensive Testing**: 36 tests with unit and integration coverage
- **🚀 CI/CD Pipeline**: Automated testing with GitHub Actions
- **📊 Code Coverage**: Codecov integration with coverage reporting
- **🏗️ Clean Architecture**: Organized in `/src/api` with proper structure

## 📋 Prerequisites

- Node.js 18+ and npm 9+
- Deepgram API key ([Get one here](https://deepgram.com))
- Docker (optional, for containerized deployment)

## 🏗️ Project Structure

```
src/
├── api/                    # Backend API (this directory)
│   ├── src/
│   │   ├── config/         # Configuration management
│   │   ├── middleware/     # Express middleware
│   │   ├── routes/         # API route handlers
│   │   ├── services/       # Business logic services
│   │   └── utils/          # Utility functions
│   ├── tests/
│   │   ├── unit/           # Unit tests
│   │   ├── integration/    # Integration tests
│   │   └── helpers/        # Test utilities
│   ├── Dockerfile          # Multi-stage Docker build
│   ├── docker-compose.yml  # Container orchestration
│   ├── jest.config.js      # Test configuration
│   └── package.json        # Dependencies and scripts
└── mobile/                 # iOS app (Muesli.xcodeproj)
    ├── Muesli/
    ├── MuesliTests/
    └── MuesliUITests/
```

## ⚡ Quick Start

### 1. Environment Setup

```bash
# Clone the repository
git clone <repository-url>
cd muesli/src/api

# Copy environment template
cp .env.example .env

# Edit .env with your configuration
nano .env
```

### 2. Required Environment Variables

```bash
# Essential configuration
DEEPGRAM_API_KEY=your_deepgram_api_key_here
PORT=3000
NODE_ENV=production

# Security (adjust for your domain)
CORS_ORIGIN=https://yourdomain.com,https://muesli-app.com
```

### 3. Local Development

```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Or start production server
npm start
```

### 4. Docker Deployment

```bash
# Build and run with Docker Compose
docker-compose up -d

# Or build manually
docker build -t muesli-api .
docker run -p 3000:3000 --env-file .env muesli-api
```

## 📡 API Endpoints

### Health Checks
- `GET /health` - Basic health check
- `GET /health/detailed` - Comprehensive health with dependencies
- `GET /health/ready` - Kubernetes readiness probe
- `GET /health/live` - Kubernetes liveness probe
- `GET /health/metrics` - Service metrics

### Transcription
- `POST /api/v1/transcribe` - Batch audio transcription
- `WS /api/v1/transcribe/realtime` - Real-time transcription

## 🔧 Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DEEPGRAM_API_KEY` | ✅ | - | Deepgram API key |
| `PORT` | ❌ | 3000 | Server port |
| `NODE_ENV` | ❌ | production | Environment mode |
| `DEEPGRAM_MODEL` | ❌ | nova-2 | Deepgram model |
| `DEEPGRAM_LANGUAGE` | ❌ | en-US | Language code |
| `CORS_ORIGIN` | ❌ | * | Allowed CORS origins |
| `MAX_FILE_SIZE_MB` | ❌ | 50 | Max upload size |
| `LOG_LEVEL` | ❌ | info | Logging level |

### Rate Limiting
- **General API**: 100 requests per 15 minutes
- **Transcription**: 20 requests per 15 minutes
- **Configurable** via environment variables

### Supported Audio Formats
- MP4 Audio (M4A)
- MP3
- WAV
- WebM Audio  
- OGG
- Additional formats supported by Deepgram

## 🔒 Security Features

- **Helmet.js**: Security headers
- **CORS**: Configurable cross-origin requests
- **Rate Limiting**: Per-IP request limits
- **Input Validation**: File type and size validation
- **Security Audit**: Suspicious request detection
- **Request Logging**: Full request/response logging

## 📊 Monitoring & Observability

### Health Checks
```bash
# Basic health
curl http://localhost:3000/health

# Detailed health with dependencies
curl http://localhost:3000/health/detailed

# Service metrics
curl http://localhost:3000/health/metrics
```

### Logging
- **Structured JSON logs** in production
- **Human-readable logs** in development
- **Daily log rotation** with configurable retention
- **Separate error logs** for debugging

### Log Locations
- `logs/muesli-api-current.log` - All logs
- `logs/muesli-api-error-current.log` - Error logs only
- `logs/muesli-api-exceptions-*.log` - Uncaught exceptions

## 🧪 Testing

### Automated Test Suite

The API includes a comprehensive test suite with **36 tests** covering:

```bash
# Run all tests
npm test

# Run tests with coverage
npm run test:ci

# Run only unit tests
npm run test:unit

# Run only integration tests  
npm run test:integration

# Watch mode for development
npm run test:watch
```

**Test Coverage:**
- ✅ **Unit Tests**: Health and transcription endpoints
- ✅ **Integration Tests**: Full API workflows
- ✅ **Error Handling**: All error scenarios
- ✅ **Validation**: Input validation and security
- ✅ **Performance**: Response time monitoring
- ✅ **Coverage**: 17%+ overall, 95%+ for health routes

### CI/CD Pipeline

Tests run automatically on every commit via GitHub Actions:
- 🚀 **iOS Tests**: Swift/Xcode testing for mobile app
- 🌐 **API Tests**: Node.js testing for backend
- 📊 **Coverage**: Automatic coverage reporting to Codecov
- 🔍 **Linting**: Code quality checks

### Manual Testing

```bash
# Test health endpoint
curl http://localhost:3000/health

# Test batch transcription
curl -X POST http://localhost:3000/api/v1/transcribe \
  -F "audio=@test-audio.m4a" \
  -F "model=nova-2" \
  -F "language=en-US"
```

### Load Testing
```bash
# Install Apache Bench
apt-get install apache2-utils

# Test health endpoint
ab -n 1000 -c 10 http://localhost:3000/health
```

## 🐳 Production Deployment

### Docker Compose (Recommended)

```yaml
# docker-compose.prod.yml
version: '3.8'
services:
  muesli-api:
    image: muesli-api:latest
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DEEPGRAM_API_KEY=${DEEPGRAM_API_KEY}
    volumes:
      - ./logs:/app/logs
    restart: unless-stopped
```

### Kubernetes

```yaml
# k8s-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: muesli-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: muesli-api
  template:
    metadata:
      labels:
        app: muesli-api
    spec:
      containers:
      - name: muesli-api
        image: muesli-api:latest
        ports:
        - containerPort: 3000
        env:
        - name: DEEPGRAM_API_KEY
          valueFrom:
            secretKeyRef:
              name: muesli-secrets
              key: deepgram-api-key
        livenessProbe:
          httpGet:
            path: /health/live
            port: 3000
          initialDelaySeconds: 30
        readinessProbe:
          httpGet:
            path: /health/ready  
            port: 3000
          initialDelaySeconds: 10
```

### Environment-Specific Configs

#### Development
```bash
NODE_ENV=development
LOG_LEVEL=debug
DEEPGRAM_API_KEY=your_dev_key
```

#### Production
```bash
NODE_ENV=production
LOG_LEVEL=info
DEEPGRAM_API_KEY=your_prod_key
CORS_ORIGIN=https://yourdomain.com
```

## 🔧 iOS App Integration

Update your iOS app's TranscriptionService configuration:

```swift
// In TranscriptionService.swift
transcriptionAPIBaseURL = "https://your-api-domain.com/api/v1"
```

The API provides the exact JSON format expected by the iOS app:

```json
{
  "transcript": "Your transcribed text here",
  "confidence": 0.95,
  "metadata": {
    "model": "nova-2",
    "language": "en-US"
  }
}
```

## 🚨 Error Handling

The API returns consistent error responses:

```json
{
  "error": "Error description",
  "requestId": "unique-request-id",
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

Common HTTP status codes:
- `200` - Success
- `400` - Bad request (invalid file, etc.)
- `401` - Authentication failure
- `413` - File too large
- `429` - Rate limit exceeded
- `500` - Internal server error

## 📈 Performance Tuning

### Recommended Production Settings

```bash
# Process management
NODE_ENV=production
NODE_OPTIONS="--max-old-space-size=1024"

# Rate limiting
API_RATE_LIMIT_MAX_REQUESTS=200
TRANSCRIPTION_RATE_LIMIT_MAX_REQUESTS=50

# File handling  
MAX_FILE_SIZE_MB=100
MAX_UPLOAD_DURATION_SECONDS=7200
```

### Docker Resource Limits

```yaml
deploy:
  resources:
    limits:
      memory: 1G
      cpus: '1.0'
    reservations:
      memory: 512M
      cpus: '0.5'
```

## 🆘 Troubleshooting

### Common Issues

1. **Deepgram Authentication Error**
   ```bash
   # Check your API key
   curl -X GET 'https://api.deepgram.com/v1/projects' \
     -H "Authorization: Token YOUR_API_KEY"
   ```

2. **File Upload Issues**
   ```bash
   # Check file format and size
   file your-audio.m4a
   du -h your-audio.m4a
   ```

3. **Rate Limiting**
   ```bash
   # Check rate limit headers
   curl -I http://localhost:3000/api/v1/transcribe
   ```

### Debug Mode

```bash
# Enable debug logging
LOG_LEVEL=debug npm start

# Check specific logs
tail -f logs/muesli-api-current.log | grep ERROR
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## 🆔 Support

- **Issues**: GitHub Issues
- **Documentation**: This README
- **Logs**: Check application logs for debugging