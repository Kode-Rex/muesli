# Multi-stage Dockerfile for Muesli Transcription API
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --omit=dev && npm cache clean --force

# Production stage
FROM node:18-alpine AS production

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Create app user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Set working directory
WORKDIR /app

# Copy dependencies from builder stage
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules

# Copy application code
COPY --chown=nodejs:nodejs src ./src
COPY --chown=nodejs:nodejs package*.json ./

# Create logs directory
RUN mkdir -p logs && chown nodejs:nodejs logs

# Switch to non-root user
USER nodejs

# Serverless platforms (Cloud Run, Fly Machines, Lambda containers) inject $PORT.
# config/index.js already reads PORT from env; default 3000 for local docker run.
ENV PORT=3000
EXPOSE 3000

# Health check uses $PORT so it works whether the platform overrides it or not.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:'+ (process.env.PORT||3000) +'/health', (r)=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

# Start application with dumb-init
CMD ["dumb-init", "node", "src/server.js"]