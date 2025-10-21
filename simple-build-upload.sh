#!/bin/bash

set -e

echo "🚀 Simple Build and Upload Script"
echo "=================================="
echo ""

# Configuration
DOCKER_USERNAME="mowsen"
IMAGE_NAME="jitsi-meet"
IMAGE_TAG="latest"
FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "Building Jitsi Meet application..."
./build-all.sh

echo ""
echo "Tagging image for Docker Hub..."
docker tag jitsi-meet:latest ${FULL_IMAGE_NAME}

echo ""
echo "Pushing to Docker Hub..."
echo "Make sure you're logged in with: docker login -u ${DOCKER_USERNAME}"
docker push ${FULL_IMAGE_NAME}

echo ""
echo "✅ Success! Your image is now available at:"
echo "   🐳 ${FULL_IMAGE_NAME}"
echo ""
echo "To use on another machine:"
echo "   docker pull ${FULL_IMAGE_NAME}"
echo "   docker run -p 8000:80 ${FULL_IMAGE_NAME}"
echo ""
