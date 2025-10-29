#!/bin/bash
set -euo pipefail

echo "🚀 Build and Upload Jitsi Meet to Docker Hub"
echo "============================================"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERR]${NC} $1"; }

# Configuration
DOCKER_USERNAME="mowsen"
IMAGE_NAME="jitsi-meet"
IMAGE_TAG="latest"
FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"
VERSION_FILE="VERSION"

# Versioning
increment_version() {
    local version_file="$1"
    local current_version
    
    if [[ -f "$version_file" ]]; then
        current_version=$(cat "$version_file")
    else
        current_version="1.0.0"
    fi
    
    # Split version into parts
    IFS='.' read -ra VERSION_PARTS <<< "$current_version"
    local major=${VERSION_PARTS[0]}
    local minor=${VERSION_PARTS[1]}
    local patch=${VERSION_PARTS[2]}
    
    # Increment patch version
    patch=$((patch + 1))
    
    # Create new version
    local new_version="${major}.${minor}.${patch}"
    
    # Save new version
    echo "$new_version" > "$version_file"
    
    echo "$new_version"
}

usage() {
  echo "Usage: $0 [--no-clean] [--no-verify]"
  echo "  --no-clean      Skip cleaning previous builds"
  echo "  --no-verify     Skip upload verification"
  echo ""
  echo "This script builds Jitsi Meet for amd64 platform and uploads to Docker Hub:"
  echo "  - Builds application assets"
  echo "  - Creates Docker image for amd64 platform"
  echo "  - Uploads to Docker Hub"
}

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
    info "Cleaning previous builds..."
    
    # Stop and remove existing containers
    docker stop jitsi-meet-test 2>/dev/null || true
    docker rm jitsi-meet-test 2>/dev/null || true
    
    # Remove old images (optional)
    info "Removing old local images..."
    docker rmi ${FULL_IMAGE_NAME} 2>/dev/null || true
    docker rmi jitsi-meet:latest 2>/dev/null || true
    
    ok "Cleanup completed"
}

# Function to build the application
build_application() {
    info "Building Jitsi Meet application..."
    
    # Check if build-all.sh exists and is executable
    if [ ! -f "./build-all.sh" ]; then
        err "build-all.sh not found in current directory"; exit 1
    fi
    
    if [ ! -x "./build-all.sh" ]; then
        info "Making build-all.sh executable..."
        chmod +x ./build-all.sh
    fi
    
    # Run the build script
    info "Running build-all.sh..."
    ./build-all.sh
    
    ok "Application build completed"
}

# Function to tag and push to Docker Hub
upload_to_dockerhub() {
    info "Preparing image for Docker Hub..."
    
    # Check if the local image exists (robust check)
    if ! docker image inspect jitsi-meet:latest >/dev/null 2>&1; then
        err "jitsi-meet:latest image not found after build. Ensure buildx --load succeeded."; exit 1
    fi
    
    # Tag the image for Docker Hub
    info "Tagging image as ${FULL_IMAGE_NAME}..."
    docker tag jitsi-meet:latest ${FULL_IMAGE_NAME}
    
    # Push to Docker Hub
    info "Pushing to Docker Hub..."
    info "This may take a few minutes depending on your internet connection..."
    docker push ${FULL_IMAGE_NAME}
    
    ok "Image uploaded to Docker Hub successfully!"
}

# Function to verify the upload
verify_upload() {
    info "Verifying upload..."
    
    # Pull the image to verify it's accessible
    info "Testing pull from Docker Hub..."
    docker pull ${FULL_IMAGE_NAME}
    
    ok "Upload verified successfully!"
}

# Function to show usage information
show_usage() {
    info "Usage Information:"
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
    info "Starting build and upload process..."
    
    # Preconditions
    info "Checking Docker installation..."
    if ! command -v docker &> /dev/null; then
        err "Docker is not installed. Install Docker Desktop first."; exit 1
    fi
    if ! docker info &> /dev/null; then
        err "Docker is not running. Start Docker and retry."; exit 1
    fi
    ok "Docker is available"

    # Get current version
    current_version=$(cat "$VERSION_FILE" 2>/dev/null || echo "1.0.0")
    info "Current version: $current_version"

    # Increment version
    new_version=$(increment_version "$VERSION_FILE")
    ok "Version incremented to: $new_version"
    
    # Check prerequisites
    info "Checking prerequisites..."
    check_command "docker"
    check_command "node"
    check_command "npm"
    check_docker_login
    ok "Prerequisites check passed"
    
    # Clean previous builds
    if [[ "$NO_CLEAN" == "false" ]]; then
        clean_builds
    else
        warn "Skipping cleanup step"
    fi
    
    # Build the application
    build_application
    
    # Stop and remove all running containers to avoid port conflicts
    info "Stopping and removing ALL running containers..."
    docker ps -aq | xargs -r docker stop >/dev/null 2>&1 || true
    docker ps -aq | xargs -r docker rm >/dev/null 2>&1 || true
    ok "All containers stopped and removed"

    # Build Docker image for amd64 platform using buildx and load to local cache
    info "Building Docker image for amd64 platform (buildx + --load)..."
    if ! docker buildx version >/dev/null 2>&1; then
        err "docker buildx is required for cross-platform builds. Please enable buildx (Docker Desktop: Features in development -> Enable BuildKit)."
        exit 1
    fi
    docker buildx build --platform linux/amd64 --no-cache -t jitsi-meet:latest -f Dockerfile.simple . --load
    ok "Docker image built and loaded locally successfully"

    # Upload to Docker Hub
    upload_to_dockerhub
    
    # Verify the upload
    if [[ "$NO_VERIFY" == "false" ]]; then
        verify_upload
    else
        warn "Skipping verification step"
    fi
    
    # Show usage information
    show_usage
    
    echo "============================================"
    echo "🎉 Build and Upload Complete! 🎉"
    echo "============================================"
    echo ""
    echo "Your custom Jitsi Meet image is now available on Docker Hub!"
    echo "Image: ${FULL_IMAGE_NAME}"
    echo "Version: ${new_version}"
    echo ""
    echo "Next steps:"
    echo "1. Use quick-deploy-remote.sh to deploy to any server"
    echo "2. Or manually pull and run: docker run -p 8000:80 ${FULL_IMAGE_NAME}"
    echo ""
}

NO_CLEAN="false"
NO_VERIFY="false"

while [[ ${1:-} != "" ]]; do
  case "$1" in
    --no-clean)
      NO_CLEAN="true"; shift;;
    --no-verify)
      NO_VERIFY="true"; shift;;
    --help|-h)
      usage; exit 0;;
    *)
      err "Unknown option: $1"; usage; exit 1;;
  esac
done

# Run main function
main
