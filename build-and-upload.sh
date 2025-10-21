#!/bin/bash

set -e

# Configuration
DOCKER_USERNAME="mowsen"
IMAGE_NAME="jitsi-meet"
IMAGE_TAG="latest"
FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "============================================"
echo "🚀 Build and Upload Jitsi Meet to Docker Hub 🚀"
echo "============================================"
echo ""

# Function to check if command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo "❌ Error: $1 is not installed or not in PATH"
        exit 1
    fi
}

# Function to check Docker login
check_docker_login() {
    if ! docker info &> /dev/null; then
        echo "❌ Error: Docker is not running or not accessible"
        exit 1
    fi
    
    # Check if logged in to Docker Hub
    if ! docker system info | grep -q "Username"; then
        echo "⚠️  Warning: You may not be logged in to Docker Hub"
        echo "   Run 'docker login -u ${DOCKER_USERNAME}' if needed"
        echo ""
    fi
}

# Function to clean previous builds
clean_builds() {
    echo "🧹 Cleaning previous builds..."
    
    # Stop and remove existing containers
    docker stop jitsi-meet-test 2>/dev/null || true
    docker rm jitsi-meet-test 2>/dev/null || true
    
    # Remove old images (optional)
    echo "   Removing old local images..."
    docker rmi ${FULL_IMAGE_NAME} 2>/dev/null || true
    docker rmi jitsi-meet:latest 2>/dev/null || true
    
    echo "✅ Cleanup completed"
    echo ""
}

# Function to build the application
build_application() {
    echo "🔨 Building Jitsi Meet application..."
    
    # Check if build-all.sh exists and is executable
    if [ ! -f "./build-all.sh" ]; then
        echo "❌ Error: build-all.sh not found in current directory"
        exit 1
    fi
    
    if [ ! -x "./build-all.sh" ]; then
        echo "   Making build-all.sh executable..."
        chmod +x ./build-all.sh
    fi
    
    # Run the build script
    echo "   Running build-all.sh..."
    ./build-all.sh
    
    echo "✅ Application build completed"
    echo ""
}

# Function to tag and push to Docker Hub
upload_to_dockerhub() {
    echo "📦 Preparing image for Docker Hub..."
    
    # Check if the local image exists
    if ! docker images | grep -q "jitsi-meet.*latest"; then
        echo "❌ Error: jitsi-meet:latest image not found"
        echo "   Make sure build-all.sh completed successfully"
        exit 1
    fi
    
    # Tag the image for Docker Hub
    echo "   Tagging image as ${FULL_IMAGE_NAME}..."
    docker tag jitsi-meet:latest ${FULL_IMAGE_NAME}
    
    # Push to Docker Hub
    echo "   Pushing to Docker Hub..."
    echo "   This may take a few minutes depending on your internet connection..."
    docker push ${FULL_IMAGE_NAME}
    
    echo "✅ Image uploaded to Docker Hub successfully!"
    echo ""
}

# Function to verify the upload
verify_upload() {
    echo "🔍 Verifying upload..."
    
    # Pull the image to verify it's accessible
    echo "   Testing pull from Docker Hub..."
    docker pull ${FULL_IMAGE_NAME}
    
    echo "✅ Upload verified successfully!"
    echo ""
}

# Function to show usage information
show_usage() {
    echo "📋 Usage Information:"
    echo ""
    echo "Your image is now available at:"
    echo "   🐳 Docker Hub: ${FULL_IMAGE_NAME}"
    echo ""
    echo "To use this image on another machine:"
    echo "   docker pull ${FULL_IMAGE_NAME}"
    echo "   docker run -p 8000:80 ${FULL_IMAGE_NAME}"
    echo ""
    echo "Or use the quick-deploy-remote.sh script:"
    echo "   ./quick-deploy-remote.sh https://your-domain.com"
    echo ""
}

# Main execution
main() {
    echo "Starting build and upload process..."
    echo ""
    
    # Check prerequisites
    echo "🔍 Checking prerequisites..."
    check_command "docker"
    check_command "node"
    check_command "npm"
    check_docker_login
    echo "✅ Prerequisites check passed"
    echo ""
    
    # Clean previous builds
    clean_builds
    
    # Build the application
    build_application
    
    # Upload to Docker Hub
    upload_to_dockerhub
    
    # Verify the upload
    verify_upload
    
    # Show usage information
    show_usage
    
    echo "============================================"
    echo "🎉 Build and Upload Complete! 🎉"
    echo "============================================"
    echo ""
    echo "Your custom Jitsi Meet image is now available on Docker Hub!"
    echo "Image: ${FULL_IMAGE_NAME}"
    echo ""
    echo "Next steps:"
    echo "1. Use quick-deploy-remote.sh to deploy to any server"
    echo "2. Or manually pull and run: docker run -p 8000:80 ${FULL_IMAGE_NAME}"
    echo ""
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Build and upload Jitsi Meet to Docker Hub"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --no-clean     Skip cleaning previous builds"
        echo "  --no-verify    Skip upload verification"
        echo ""
        echo "Examples:"
        echo "  $0                    # Full build and upload"
        echo "  $0 --no-clean         # Skip cleanup step"
        echo "  $0 --no-verify        # Skip verification step"
        exit 0
        ;;
    --no-clean)
        echo "⚠️  Skipping cleanup step"
        NO_CLEAN=true
        ;;
    --no-verify)
        echo "⚠️  Skipping verification step"
        NO_VERIFY=true
        ;;
    "")
        # No arguments, proceed normally
        ;;
    *)
        echo "❌ Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac

# Run main function
main
