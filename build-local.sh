#!/bin/bash
set -e

echo "Building Jitsi Meet locally..."

# Check if Node.js is available
if ! command -v node &> /dev/null; then
    echo "Node.js is not installed. Please install Node.js 22+ first."
    exit 1
fi

# Check Node.js version
NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 22 ]; then
    echo "Node.js version 22+ is required. Current version: $(node -v)"
    exit 1
fi

# Install dependencies
echo "Installing dependencies..."
npm install --legacy-peer-deps

# Build the application
echo "Building application..."
NODE_OPTIONS="--max-old-space-size=8192" make all

echo "Build completed successfully!"
echo "You can now use Dockerfile.simple to create the Docker image."

