# Multi-stage Dockerfile for Muesli Transcription API
FROM node:20-alpine AS builder

# Pull in the latest alpine package fixes that haven't yet rolled into the
# node:20-alpine tag. Without this we ship known-vulnerable libssl/libcrypto/
# musl/zlib versions and Trivy fails the build.
RUN apk upgrade --no-cache

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --omit=dev && npm cache clean --force

# Production stage
FROM node:20-alpine AS production

# Same upgrade in the production stage — base layers are independent from
# the builder stage's, so we need both to actually ship fixed binaries.
RUN apk upgrade --no-cache && apk add --no-cache dumb-init

# node:alpine ships npm bundled in /usr/local/lib/node_modules/npm, and that
# bundle pins older transitives (tar/glob/minimatch/cross-spawn) that Trivy
# correctly flags. We don't need npm at runtime — after `npm ci` finishes in
# the builder stage, the prod image only runs `node`. Drop npm and the
# corepack shim so the surface area shrinks and the scan goes clean.
RUN rm -rf /usr/local/lib/node_modules/npm \
    /usr/local/lib/node_modules/corepack \
    /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack \
    /opt/yarn-* /usr/local/bin/yarn /usr/local/bin/yarnpkg 2>/dev/null || true

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