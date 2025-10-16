#!/bin/bash

# Jitsi Meet Custom Deployment Script
# This script builds, tags, pushes to Docker Hub, and provides usage instructions

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOCKER_USERNAME="mowsen"
IMAGE_NAME="jitsi-meet"
TAG="latest"
FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${TAG}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Jitsi Meet Custom Deployment Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to print status
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "build-all.sh" ]; then
    print_error "build-all.sh not found. Please run this script from the jitsi-meet root directory."
    exit 1
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if user is logged into Docker Hub
if ! docker info | grep -q "Username"; then
    print_warning "You may not be logged into Docker Hub."
    echo "Please run: docker login -u ${DOCKER_USERNAME}"
    echo "Press Enter to continue or Ctrl+C to cancel..."
    read
fi

print_status "Starting Jitsi Meet custom deployment process..."

# Step 1: Build the application
print_status "Step 1: Building Jitsi Meet application..."
if [ -f "build-all.sh" ]; then
    ./build-all.sh
    if [ $? -ne 0 ]; then
        print_error "Build failed!"
        exit 1
    fi
else
    print_error "build-all.sh not found!"
    exit 1
fi

# Step 2: Tag the image for Docker Hub
print_status "Step 2: Tagging image for Docker Hub..."
docker tag jitsi-meet:latest ${FULL_IMAGE_NAME}
if [ $? -ne 0 ]; then
    print_error "Failed to tag image!"
    exit 1
fi

# Step 3: Push to Docker Hub
print_status "Step 3: Pushing to Docker Hub..."
docker push ${FULL_IMAGE_NAME}
if [ $? -ne 0 ]; then
    print_error "Failed to push to Docker Hub!"
    exit 1
fi

print_status "Successfully pushed ${FULL_IMAGE_NAME} to Docker Hub!"

# Step 4: Create usage instructions
print_status "Step 4: Creating deployment instructions..."

cat > DEPLOYMENT_INSTRUCTIONS.md << EOF
# Jitsi Meet Custom Deployment

## Your Custom Image
- **Docker Hub**: \`${FULL_IMAGE_NAME}\`
- **Built**: $(date)
- **Features**: Your custom Jitsi Meet frontend with all modifications

## Quick Start

### Option 1: Use with Official Jitsi Docker Setup

1. **Clone the official Jitsi Docker repository:**
   \`\`\`bash
   git clone https://github.com/jitsi/docker-jitsi-meet.git
   cd docker-jitsi-meet
   \`\`\`

2. **Configure the environment:**
   \`\`\`bash
   cp env.example .env
   \`\`\`

3. **Edit docker-compose.yml to use your custom image:**
   \`\`\`yaml
   services:
     web:
       image: ${FULL_IMAGE_NAME}  # Change this line
       # ... rest of configuration
   \`\`\`

4. **Start the stack:**
   \`\`\`bash
   ./gen-passwords.sh
   docker-compose up -d
   \`\`\`

### Option 2: Use with Docker Compose (Standalone)

Create a \`docker-compose.yml\` file:

\`\`\`yaml
version: "3.8"

networks:
  meet.jitsi:
    name: meet.jitsi

services:
  web:
    image: ${FULL_IMAGE_NAME}
    container_name: jitsi-web-custom
    restart: unless-stopped
    ports:
      - "8000:80"
    environment:
      - PUBLIC_URL=http://localhost:8000
    networks:
      - meet.jitsi
    depends_on:
      - prosody

  prosody:
    image: jitsi/prosody:stable-9584
    container_name: jitsi-prosody
    restart: unless-stopped
    ports:
      - "5280:5280"
    environment:
      - ENABLE_AUTH=0
      - ENABLE_GUESTS=1
      - XMPP_DOMAIN=meet.jitsi
      - XMPP_AUTH_DOMAIN=auth.meet.jitsi
      - XMPP_MUC_DOMAIN=muc.meet.jitsi
      - XMPP_INTERNAL_MUC_DOMAIN=internal-muc.meet.jitsi
      - JICOFO_AUTH_USER=focus
      - JICOFO_AUTH_PASSWORD=jicofopass
      - JVB_AUTH_USER=jvb
      - JVB_AUTH_PASSWORD=jvbpass
    networks:
      - meet.jitsi

  jicofo:
    image: jitsi/jicofo:stable-9584
    container_name: jitsi-jicofo
    restart: unless-stopped
    depends_on:
      - prosody
    environment:
      - ENABLE_AUTH=0
      - XMPP_DOMAIN=meet.jitsi
      - XMPP_AUTH_DOMAIN=auth.meet.jitsi
      - XMPP_INTERNAL_MUC_DOMAIN=internal-muc.meet.jitsi
      - XMPP_SERVER=prosody
      - JICOFO_AUTH_USER=focus
      - JICOFO_AUTH_PASSWORD=jicofopass
      - JVB_BREWERY_MUC=jvbbrewery
    networks:
      - meet.jitsi

  jvb:
    image: jitsi/jvb:stable-9584
    container_name: jitsi-jvb
    restart: unless-stopped
    depends_on:
      - prosody
    ports:
      - "10000:10000/udp"
    environment:
      - XMPP_AUTH_DOMAIN=auth.meet.jitsi
      - XMPP_INTERNAL_MUC_DOMAIN=internal-muc.meet.jitsi
      - XMPP_SERVER=prosody
      - JVB_AUTH_USER=jvb
      - JVB_AUTH_PASSWORD=jvbpass
      - JVB_BREWERY_MUC=jvbbrewery
      - JVB_PORT=10000
      - JVB_STUN_SERVERS=stun.l.google.com:19302
    networks:
      - meet.jitsi
\`\`\`

Then run:
\`\`\`bash
docker-compose up -d
\`\`\`

## Access Your Instance
- **URL**: http://localhost:8000
- **Features**: Your custom UI with all modifications
- **Backend**: Official Jitsi Meet services

## Management Commands

\`\`\`bash
# View logs
docker-compose logs -f

# Stop services
docker-compose down

# Restart services
docker-compose restart

# Update your custom image
docker pull ${FULL_IMAGE_NAME}
docker-compose up -d
\`\`\`

## Troubleshooting

1. **WebSocket connection errors**: Ensure port 5280 is exposed
2. **Video not working**: Check that port 10000 UDP is open
3. **Custom UI not loading**: Verify the image name in docker-compose.yml

## Support
- **Docker Hub**: https://hub.docker.com/r/${DOCKER_USERNAME}/${IMAGE_NAME}
- **Built on**: $(date)
- **Image size**: $(docker images ${FULL_IMAGE_NAME} --format "table {{.Size}}" | tail -n 1)
EOF

print_status "Created DEPLOYMENT_INSTRUCTIONS.md with complete usage instructions!"

# Step 5: Create a simple deployment script
print_status "Step 5: Creating quick deployment script..."

cat > quick-deploy.sh << 'EOF'
#!/bin/bash
# Quick deployment script for your custom Jitsi Meet

set -e

DOCKER_USERNAME="mowsen"
IMAGE_NAME="jitsi-meet"
TAG="latest"
FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${TAG}"

echo "🚀 Deploying Jitsi Meet with your custom frontend..."

# Create docker-compose.yml if it doesn't exist
if [ ! -f "docker-compose.yml" ]; then
    echo "Creating docker-compose.yml..."
    cat > docker-compose.yml << 'COMPOSE_EOF'
version: "3.8"

networks:
  meet.jitsi:
    name: meet.jitsi

services:
  web:
    image: mowsen/jitsi-meet:latest
    container_name: jitsi-web-custom
    restart: unless-stopped
    ports:
      - "8000:80"
    environment:
      - PUBLIC_URL=http://localhost:8000
    networks:
      - meet.jitsi
    depends_on:
      - prosody

  prosody:
    image: jitsi/prosody:stable-9584
    container_name: jitsi-prosody
    restart: unless-stopped
    ports:
      - "5280:5280"
    environment:
      - ENABLE_AUTH=0
      - ENABLE_GUESTS=1
      - XMPP_DOMAIN=meet.jitsi
      - XMPP_AUTH_DOMAIN=auth.meet.jitsi
      - XMPP_MUC_DOMAIN=muc.meet.jitsi
      - XMPP_INTERNAL_MUC_DOMAIN=internal-muc.meet.jitsi
      - JICOFO_AUTH_USER=focus
      - JICOFO_AUTH_PASSWORD=jicofopass
      - JVB_AUTH_USER=jvb
      - JVB_AUTH_PASSWORD=jvbpass
    networks:
      - meet.jitsi

  jicofo:
    image: jitsi/jicofo:stable-9584
    container_name: jitsi-jicofo
    restart: unless-stopped
    depends_on:
      - prosody
    environment:
      - ENABLE_AUTH=0
      - XMPP_DOMAIN=meet.jitsi
      - XMPP_AUTH_DOMAIN=auth.meet.jitsi
      - XMPP_INTERNAL_MUC_DOMAIN=internal-muc.meet.jitsi
      - XMPP_SERVER=prosody
      - JICOFO_AUTH_USER=focus
      - JICOFO_AUTH_PASSWORD=jicofopass
      - JVB_BREWERY_MUC=jvbbrewery
    networks:
      - meet.jitsi

  jvb:
    image: jitsi/jvb:stable-9584
    container_name: jitsi-jvb
    restart: unless-stopped
    depends_on:
      - prosody
    ports:
      - "10000:10000/udp"
    environment:
      - XMPP_AUTH_DOMAIN=auth.meet.jitsi
      - XMPP_INTERNAL_MUC_DOMAIN=internal-muc.meet.jitsi
      - XMPP_SERVER=prosody
      - JVB_AUTH_USER=jvb
      - JVB_AUTH_PASSWORD=jvbpass
      - JVB_BREWERY_MUC=jvbbrewery
      - JVB_PORT=10000
      - JVB_STUN_SERVERS=stun.l.google.com:19302
    networks:
      - meet.jitsi
COMPOSE_EOF
fi

# Pull the latest image
echo "📥 Pulling latest image..."
docker pull ${FULL_IMAGE_NAME}

# Start the services
echo "🚀 Starting services..."
docker-compose up -d

echo "✅ Jitsi Meet is now running!"
echo "🌐 Access at: http://localhost:8000"
echo ""
echo "📋 Management commands:"
echo "  View logs: docker-compose logs -f"
echo "  Stop: docker-compose down"
echo "  Restart: docker-compose restart"
EOF

chmod +x quick-deploy.sh

print_status "Created quick-deploy.sh for easy deployment!"

# Final summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  🎉 DEPLOYMENT COMPLETE! 🎉${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Your custom Jitsi Meet image:${NC}"
echo -e "  📦 Docker Hub: ${FULL_IMAGE_NAME}"
echo -e "  🏷️  Tag: ${TAG}"
echo -e "  📅 Built: $(date)"
echo ""
echo -e "${BLUE}Files created:${NC}"
echo -e "  📄 DEPLOYMENT_INSTRUCTIONS.md - Complete usage guide"
echo -e "  🚀 quick-deploy.sh - One-command deployment script"
echo ""
echo -e "${BLUE}To use elsewhere:${NC}"
echo -e "  1. Copy DEPLOYMENT_INSTRUCTIONS.md to your target server"
echo -e "  2. Run: docker pull ${FULL_IMAGE_NAME}"
echo -e "  3. Use the docker-compose.yml from the instructions"
echo -e "  4. Or run: ./quick-deploy.sh"
echo ""
echo -e "${GREEN}Your custom Jitsi Meet is ready for deployment anywhere! 🚀${NC}"