#!/bin/bash

echo "🚀 Jitsi Meet Docker Setup"
echo "=========================="

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    echo "   Visit: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

echo "✅ Docker is installed and running"

# Check if the image file exists
if [ ! -f "jitsi-meet-image.tar.gz" ]; then
    echo "❌ jitsi-meet-image.tar.gz not found in current directory"
    echo "   Please make sure the file is in the same folder as this script"
    exit 1
fi

echo "✅ Image file found"

# Extract and load the image
echo "📦 Loading Docker image..."
gunzip -c jitsi-meet-image.tar.gz | docker load

if [ $? -eq 0 ]; then
    echo "✅ Image loaded successfully"
else
    echo "❌ Failed to load image"
    exit 1
fi

# Check if port 8080 is available
if lsof -Pi :8080 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "⚠️  Port 8080 is already in use. Using port 3000 instead."
    PORT=3000
else
    PORT=8080
fi

# Run the container
echo "🚀 Starting Jitsi Meet container on port $PORT..."
docker run -d -p $PORT:80 --name jitsi-meet-app jitsi-meet:latest

if [ $? -eq 0 ]; then
    echo "✅ Jitsi Meet is now running!"
    echo ""
    echo "🌐 Access your Jitsi Meet at: http://localhost:$PORT"
    echo ""
    echo "🔧 Useful commands:"
    echo "   View logs:    docker logs jitsi-meet-app"
    echo "   Stop:         docker stop jitsi-meet-app"
    echo "   Start:        docker start jitsi-meet-app"
    echo "   Remove:       docker stop jitsi-meet-app && docker rm jitsi-meet-app"
    echo ""
    echo "🎉 Enjoy your Jitsi Meet instance!"
else
    echo "❌ Failed to start container"
    exit 1
fi


