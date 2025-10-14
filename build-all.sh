#!/bin/bash
set -e

echo "🚀 Jitsi Meet - Complete Build Script"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Node.js is available
check_node() {
    print_status "Checking Node.js installation..."
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed. Please install Node.js 22+ first."
        exit 1
    fi
    
    NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -lt 22 ]; then
        print_error "Node.js version 22+ is required. Current version: $(node -v)"
        exit 1
    fi
    
    print_success "Node.js $(node -v) is installed"
}

# Check if Docker is available
check_docker() {
    print_status "Checking Docker installation..."
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    print_success "Docker $(docker --version) is installed"
}

# Clean previous builds
clean_builds() {
    print_status "Cleaning previous builds..."
    
    # Stop and remove existing containers
    if docker ps -a --format 'table {{.Names}}' | grep -q "jitsi-meet"; then
        print_status "Stopping existing Jitsi Meet containers..."
        docker ps -a --format 'table {{.Names}}' | grep "jitsi-meet" | xargs -r docker stop
        docker ps -a --format 'table {{.Names}}' | grep "jitsi-meet" | xargs -r docker rm
    fi
    
    # Clean local build artifacts
    if [ -d "build" ]; then
        print_status "Cleaning build directory..."
        rm -rf build
    fi
    
    if [ -d "libs" ]; then
        print_status "Cleaning libs directory..."
        rm -rf libs
    fi
    
    print_success "Cleanup completed"
}

# Install dependencies
install_dependencies() {
    print_status "Installing dependencies..."
    
    if [ ! -f "package.json" ]; then
        print_error "package.json not found. Are you in the correct directory?"
        exit 1
    fi
    
    # Install dependencies with legacy peer deps to avoid conflicts
    npm install --legacy-peer-deps
    
    print_success "Dependencies installed"
}

# Build the application
build_application() {
    print_status "Building Jitsi Meet application..."
    
    # Set memory limit for Node.js
    export NODE_OPTIONS="--max-old-space-size=8192"
    
    # Clean and build
    print_status "Running make clean..."
    make clean
    
    print_status "Running make compile..."
    make compile
    
    print_status "Running make deploy..."
    make deploy
    
    # Fix HTML file to replace SSI includes with direct script tags
    print_status "Fixing HTML file for Docker compatibility..."
    if [ -f "fix-html.sh" ]; then
        ./fix-html.sh
    else
        # Create and run the fix inline
        cp index.html index.html.backup
        sed -i '' 's|<script><!--#include virtual="/config.js" --></script>|<script src="config.js"></script>|g' index.html
        sed -i '' 's|<script><!--#include virtual="/interface_config.js" --></script>|<script src="interface_config.js"></script>|g' index.html
    fi
    
    print_success "Application build completed"
}

# Verify build artifacts
verify_build() {
    print_status "Verifying build artifacts..."
    
    REQUIRED_FILES=(
        "libs/app.bundle.min.js"
        "libs/external_api.min.js"
        "libs/lib-jitsi-meet.min.js"
        "css/all.css"
        "index.html"
        "config.js"
        "interface_config.js"
    )
    
    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "$file" ]; then
            print_error "Required file missing: $file"
            exit 1
        fi
    done
    
    print_success "All required files present"
}

# Build Docker image
build_docker() {
    print_status "Building Docker image..."
    
    # Use the simple Dockerfile
    docker build --platform linux/amd64 -f Dockerfile.simple -t jitsi-meet:latest .
    
    print_success "Docker image built successfully"
}

# Test Docker container
test_docker() {
    print_status "Testing Docker container..."
    
    # Start container
    CONTAINER_ID=$(docker run -d -p 8080:80 --name jitsi-meet-test jitsi-meet:latest)
    
    # Wait for container to start
    sleep 3
    
    # Test health endpoint
    if curl -s http://localhost:8080/health | grep -q "healthy"; then
        print_success "Container is healthy"
    else
        print_error "Container health check failed"
        docker logs jitsi-meet-test
        docker stop jitsi-meet-test
        docker rm jitsi-meet-test
        exit 1
    fi
    
    # Stop test container
    docker stop jitsi-meet-test
    docker rm jitsi-meet-test
    
    print_success "Docker container test passed"
}

# Main build process
main() {
    echo
    print_status "Starting complete build process..."
    echo
    
    # Pre-flight checks
    check_node
    check_docker
    
    # Build process
    clean_builds
    install_dependencies
    build_application
    verify_build
    build_docker
    test_docker
    
    echo
    print_success "🎉 Complete build process finished successfully!"
    echo
    print_status "Your Jitsi Meet Docker image is ready:"
    print_status "  Image: jitsi-meet:latest"
    print_status "  To run: docker run -p 8080:80 jitsi-meet:latest"
    print_status "  Access: http://localhost:8080"
    echo
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Jitsi Meet Complete Build Script"
        echo
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --clean-only   Only clean previous builds"
        echo "  --app-only     Only build the application (no Docker)"
        echo "  --docker-only  Only build Docker image (assumes app is built)"
        echo
        exit 0
        ;;
    --clean-only)
        print_status "Cleaning only..."
        clean_builds
        print_success "Cleanup completed"
        exit 0
        ;;
    --app-only)
        print_status "Building application only..."
        check_node
        clean_builds
        install_dependencies
        build_application
        verify_build
        print_success "Application build completed"
        exit 0
        ;;
    --docker-only)
        print_status "Building Docker image only..."
        check_docker
        verify_build
        build_docker
        test_docker
        print_success "Docker build completed"
        exit 0
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown option: $1"
        print_status "Use --help for usage information"
        exit 1
        ;;
esac
