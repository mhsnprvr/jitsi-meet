#!/bin/bash
set -euo pipefail

echo "🚀 Quick Deploy Jitsi Meet on Remote Machine"
echo "============================================"

# Get domain from command line argument or use localhost
DOMAIN=${1:-"localhost"}
echo "🌐 Using domain: $DOMAIN"

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

# Stop and remove only Jitsi containers for fresh deployment
info "Stopping and removing existing Jitsi containers..."
docker ps -aq --filter "name=jitsi" | xargs -r docker stop >/dev/null 2>&1 || true
docker ps -aq --filter "name=jitsi" | xargs -r docker rm >/dev/null 2>&1 || true
ok "Jitsi containers removed"

# Create deployment directory
info "Creating deployment directory..."
mkdir -p jitsi-deploy
cd jitsi-deploy
ok "Deployment directory created"

info "Downloading official Jitsi Docker Compose files..."
curl -LJO https://raw.githubusercontent.com/jitsi/docker-jitsi-meet/master/docker-compose.yml
curl -LJO https://raw.githubusercontent.com/jitsi/docker-jitsi-meet/master/env.example
curl -LJO https://raw.githubusercontent.com/jitsi/docker-jitsi-meet/master/gen-passwords.sh
chmod +x gen-passwords.sh
ok "Files downloaded"

info "Creating and configuring .env file..."
cp env.example .env
# Use different sed syntax for Linux vs macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s|#HTTP_PORT=80|HTTP_PORT=8000|" .env
    sed -i '' "s|#HTTPS_PORT=443|HTTPS_PORT=8443|" .env
    sed -i '' "s|#PUBLIC_URL=https://meet.example.com:\${HTTPS_PORT}|PUBLIC_URL=http://$DOMAIN:8000|" .env
    sed -i '' "s|#DOCKER_HUB_UNAME=jitsi|DOCKER_HUB_UNAME=mowsen|" .env
    sed -i '' "s|#JITSI_IMAGE_VERSION=stable-9584|JITSI_IMAGE_VERSION=latest|" .env
    sed -i '' "s|#XMPP_DOMAIN=meet.example.com|XMPP_DOMAIN=$DOMAIN|" .env
    sed -i '' "s|#XMPP_AUTH_DOMAIN=auth.meet.example.com|XMPP_AUTH_DOMAIN=auth.$DOMAIN|" .env
    sed -i '' "s|#XMPP_MUC_DOMAIN=muc.meet.example.com|XMPP_MUC_DOMAIN=muc.$DOMAIN|" .env
    sed -i '' "s|#XMPP_INTERNAL_MUC_DOMAIN=internal-muc.meet.example.com|XMPP_INTERNAL_MUC_DOMAIN=internal-muc.$DOMAIN|" .env
    # Add WebSocket configuration for localhost
    echo "ENABLE_WEB_SOCKET=1" >> .env
    echo "WEBSOCKET_DOMAIN=$DOMAIN" >> .env
else
    # Linux
    sed -i "s|#HTTP_PORT=80|HTTP_PORT=8000|" .env
    sed -i "s|#HTTPS_PORT=443|HTTPS_PORT=8443|" .env
    sed -i "s|#PUBLIC_URL=https://meet.example.com:\${HTTPS_PORT}|PUBLIC_URL=http://$DOMAIN:8000|" .env
    sed -i "s|#DOCKER_HUB_UNAME=jitsi|DOCKER_HUB_UNAME=mowsen|" .env
    sed -i "s|#JITSI_IMAGE_VERSION=stable-9584|JITSI_IMAGE_VERSION=latest|" .env
    sed -i "s|#XMPP_DOMAIN=meet.example.com|XMPP_DOMAIN=$DOMAIN|" .env
    sed -i "s|#XMPP_AUTH_DOMAIN=auth.meet.example.com|XMPP_AUTH_DOMAIN=auth.$DOMAIN|" .env
    sed -i "s|#XMPP_MUC_DOMAIN=muc.meet.example.com|XMPP_MUC_DOMAIN=muc.$DOMAIN|" .env
    sed -i "s|#XMPP_INTERNAL_MUC_DOMAIN=internal-muc.meet.example.com|XMPP_INTERNAL_MUC_DOMAIN=internal-muc.$DOMAIN|" .env
    # Add WebSocket configuration for localhost
    echo "ENABLE_WEB_SOCKET=1" >> .env
    echo "WEBSOCKET_DOMAIN=$DOMAIN" >> .env
fi
ok ".env file configured"

info "Generating Jitsi passwords..."
./gen-passwords.sh
ok "Passwords generated"

info "Modifying docker-compose.yml to use custom frontend image and expose Prosody port..."
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

# Create a backup and manually add port 8000 to web service only
cp docker-compose.yml docker-compose.yml.backup

# Use awk to add port 8000 only to web service
awk '
/^[[:space:]]*web:/ { in_web = 1 }
/^[[:space:]]*[a-zA-Z]/ && !/^[[:space:]]*web:/ { in_web = 0 }
in_web && /ports:/ { 
    print $0
    print "            - \"8000:80\""
    next
}
{ print }
' docker-compose.yml.backup > docker-compose.yml

ok "docker-compose.yml modified"

info "Pulling custom Jitsi image..."
docker pull mowsen/jitsi-meet:latest
ok "Custom image pulled"

info "Starting the Jitsi Meet stack..."
docker-compose up -d
ok "Jitsi Meet stack is running!"

echo "============================================"
echo "✅ Deployment Complete! Access at: http://$DOMAIN:8000 ✅"
echo "============================================"
echo ""
echo "Management commands:"
echo "  Stop: docker-compose down"
echo "  Start: docker-compose up -d"
echo "  Logs: docker-compose logs -f"
echo "  Status: docker-compose ps"
echo ""
echo "⚠️  IMPORTANT: For localhost deployment:"
echo "  - Access directly at: http://localhost:8000"
echo "  - WebSocket connections should work automatically"
echo "  - No reverse proxy needed for localhost testing"
echo ""
echo "⚠️  For production deployment, configure your reverse proxy to:"
echo "  - Proxy WebSocket connections to /xmpp-websocket"
echo "  - Handle HTTPS termination"
echo "  - Route traffic to port 8000 for the web service"
echo "  - Ensure WebSocket upgrade headers are passed through"
