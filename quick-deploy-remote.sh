#!/bin/bash

set -e

echo "============================================"
echo "🚀 Quick Deploy Jitsi Meet on Remote Machine 🚀"
echo "============================================"
echo ""

# Create deployment directory
mkdir -p jitsi-deploy
cd jitsi-deploy

echo "Downloading official Jitsi Docker Compose files..."
curl -LJO https://raw.githubusercontent.com/jitsi/docker-jitsi-meet/master/docker-compose.yml
curl -LJO https://raw.githubusercontent.com/jitsi/docker-jitsi-meet/master/env.example
curl -LJO https://raw.githubusercontent.com/jitsi/docker-jitsi-meet/master/gen-passwords.sh
chmod +x gen-passwords.sh
echo "Files downloaded."
echo ""

echo "Creating and configuring .env file..."
cp env.example .env
# Use different sed syntax for Linux vs macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s|#HTTP_PORT=80|HTTP_PORT=8080|" .env
    sed -i '' "s|#HTTPS_PORT=443|HTTPS_PORT=8443|" .env
    sed -i '' "s|#PUBLIC_URL=https://meet.example.com:\${HTTPS_PORT}|PUBLIC_URL=http://localhost:8080|" .env
    sed -i '' "s|#DOCKER_HUB_UNAME=jitsi|DOCKER_HUB_UNAME=mowsen|" .env
    sed -i '' "s|#JITSI_IMAGE_VERSION=stable-9584|JITSI_IMAGE_VERSION=latest|" .env
else
    # Linux
    sed -i "s|#HTTP_PORT=80|HTTP_PORT=8080|" .env
    sed -i "s|#HTTPS_PORT=443|HTTPS_PORT=8443|" .env
    sed -i "s|#PUBLIC_URL=https://meet.example.com:\${HTTPS_PORT}|PUBLIC_URL=http://localhost:8080|" .env
    sed -i "s|#DOCKER_HUB_UNAME=jitsi|DOCKER_HUB_UNAME=mowsen|" .env
    sed -i "s|#JITSI_IMAGE_VERSION=stable-9584|JITSI_IMAGE_VERSION=latest|" .env
fi
echo ".env file configured."
echo ""

echo "Generating Jitsi passwords..."
./gen-passwords.sh
echo "Passwords generated."
echo ""

echo "Modifying docker-compose.yml to use custom frontend image and expose Prosody port..."
# Use different sed syntax for Linux vs macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s|image: jitsi/web:\${JITSI_IMAGE_VERSION:-unstable}|image: mowsen/jitsi-meet:\${JITSI_IMAGE_VERSION:-latest}|" docker-compose.yml
    sed -i '' 's|expose:|ports:\n            - "${PROSODY_HTTP_PORT:-5280}:5280"|' docker-compose.yml
else
    # Linux
    sed -i "s|image: jitsi/web:\${JITSI_IMAGE_VERSION:-unstable}|image: mowsen/jitsi-meet:\${JITSI_IMAGE_VERSION:-latest}|" docker-compose.yml
    sed -i 's|expose:|ports:\n            - "${PROSODY_HTTP_PORT:-5280}:5280"|' docker-compose.yml
fi
echo "docker-compose.yml modified."
echo ""

echo "Pulling the custom image..."
docker pull mowsen/jitsi-meet:latest
echo "Image pulled."
echo ""

echo "Starting the Jitsi Meet stack..."
docker-compose up -d
echo "Jitsi Meet stack is running!"
echo ""

echo "============================================"
echo "✅ Deployment Complete! Access at: http://localhost:8080 ✅"
echo "============================================"
echo ""
echo "Management commands:"
echo "  Stop: docker-compose down"
echo "  Start: docker-compose up -d"
echo "  Logs: docker-compose logs -f"
echo "  Status: docker-compose ps"
