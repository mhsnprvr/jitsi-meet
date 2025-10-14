#!/bin/bash
set -e

echo "Starting memory-efficient build process..."

# Set memory limits
export NODE_OPTIONS="--max-old-space-size=2048"

# Clean previous builds
echo "Cleaning previous builds..."
make clean

# Build in smaller chunks
echo "Building application..."
make compile

echo "Deploying assets..."
make deploy

echo "Build completed successfully!"

