# Multi-stage build for Jitsi Meet
FROM node:22-bullseye-slim AS builder

# Set working directory
WORKDIR /app

# Install system build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    python3 \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy package files
COPY package*.json ./

# Install all dependencies needed for building (with network resilience)
RUN npm i -g npm@11 && \
    npm config set fund false && \
    npm config set audit false && \
    npm config set registry https://registry.npmjs.org/ && \
    npm config set fetch-retry-mintimeout 20000 && \
    npm config set fetch-retry-maxtimeout 120000 && \
    npm config set fetch-retries 5 && \
    npm install --legacy-peer-deps --no-optional

# Copy source code
COPY . .

# Build the application with memory optimization
RUN chmod +x build-memory-efficient.sh && \
    ./build-memory-efficient.sh

# Production stage with nginx
FROM nginx:alpine

# Copy built files from builder stage
COPY --from=builder /app/libs /usr/share/nginx/html/libs
COPY --from=builder /app/css /usr/share/nginx/html/css
COPY --from=builder /app/images /usr/share/nginx/html/images
COPY --from=builder /app/sounds /usr/share/nginx/html/sounds
COPY --from=builder /app/fonts /usr/share/nginx/html/fonts
COPY --from=builder /app/lang /usr/share/nginx/html/lang
COPY --from=builder /app/static /usr/share/nginx/html/static
COPY --from=builder /app/*.html /usr/share/nginx/html/
COPY --from=builder /app/*.js /usr/share/nginx/html/
COPY --from=builder /app/*.json /usr/share/nginx/html/
COPY --from=builder /app/manifest.json /usr/share/nginx/html/
COPY --from=builder /app/pwa-worker.js /usr/share/nginx/html/

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Expose port
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
