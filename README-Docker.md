# Jitsi Meet Docker Setup

This document explains how to build and run Jitsi Meet using Docker.

## Quick Start

### Build the Docker Image

```bash
# Build the image
docker build -t jitsi-meet .

# Or using docker-compose
docker-compose build
```

### Run the Container

```bash
# Run the container
docker run -p 8080:80 jitsi-meet

# Or using docker-compose
docker-compose up
```

The application will be available at `http://localhost:8080`

## Build Process

The Dockerfile uses a multi-stage build:

1. **Builder Stage**:

    - Uses Node.js 22 Alpine
    - Installs dependencies
    - Builds the application using `make all`
    - Creates optimized production bundles

2. **Production Stage**:
    - Uses Nginx Alpine
    - Copies built files from builder stage
    - Serves static files with optimized configuration

## Configuration

### Environment Variables

-   `NODE_ENV=production` - Sets production mode

### Nginx Configuration

The included `nginx.conf` provides:

-   Gzip compression
-   Static asset caching
-   Security headers
-   WASM file handling
-   Health check endpoint

### Custom Configuration

To customize the Jitsi Meet configuration:

1. Modify `config.js` and `interface_config.js` before building
2. Rebuild the Docker image
3. The changes will be included in the final image

## Production Deployment

### Using Docker Compose

```bash
# Start services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### Health Checks

The container includes health checks:

-   Endpoint: `http://localhost:8080/health`
-   Checks every 30 seconds
-   3 retries before marking as unhealthy

### Scaling

To run multiple instances:

```bash
docker-compose up --scale jitsi-meet=3
```

## Troubleshooting

### Build Issues

1. **Node.js version**: Ensure you're using Node.js 22+
2. **Memory**: The build process requires significant memory (8GB+ recommended)
3. **Dependencies**: All dependencies are installed during build

### Runtime Issues

1. **Port conflicts**: Change the port mapping in docker-compose.yml
2. **File permissions**: Ensure nginx can read the files
3. **Memory limits**: Increase container memory if needed

### Logs

```bash
# View container logs
docker logs <container_id>

# View nginx logs
docker exec <container_id> tail -f /var/log/nginx/error.log
```

## Customization

### Custom Nginx Configuration

Replace `nginx.conf` with your custom configuration before building.

### Additional Static Files

Add files to the appropriate directories before building:

-   Images: `images/`
-   Sounds: `sounds/`
-   Fonts: `fonts/`
-   Static HTML: root directory

### Environment-Specific Builds

Create different Dockerfiles for different environments:

```dockerfile
# Dockerfile.dev
FROM node:22-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["make", "dev"]
```

## Security Considerations

1. **HTTPS**: Use a reverse proxy with SSL termination
2. **Headers**: The nginx config includes security headers
3. **Updates**: Regularly update the base images
4. **Secrets**: Don't include sensitive data in the image

## Performance Optimization

1. **Caching**: Static assets are cached for 1 year
2. **Compression**: Gzip compression is enabled
3. **Multi-stage build**: Reduces final image size
4. **Alpine Linux**: Minimal base image

## Monitoring

-   Health check endpoint: `/health`
-   Nginx access logs: `/var/log/nginx/access.log`
-   Nginx error logs: `/var/log/nginx/error.log`

