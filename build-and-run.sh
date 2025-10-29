#!/bin/bash
set -euo pipefail

echo "🚀 Build and Run Complete Jitsi Meet Stack"
echo "==========================================="

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

IMAGE_NAME="jitsi-meet:latest"
COMPOSE_FILE="docker-compose-complete.yml"
PORT=""
VERSION_FILE="VERSION"

# Function to increment version
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
  echo "Usage: $0 [--port <port>] [--no-build]"
  echo "  --port <port>   Port to expose (default: 8000)"
  echo "  --no-build      Skip building image (use existing ${IMAGE_NAME})"
  echo ""
  echo "This script runs the complete Jitsi Meet stack:"
  echo "  - Web frontend (your custom build)"
  echo "  - Prosody (XMPP server)"
  echo "  - Jicofo (conference focus)"
  echo "  - JVB (video bridge)"
}

NO_BUILD="false"

while [[ ${1:-} != "" ]]; do
  case "$1" in
    --port)
      PORT="${2:-}"; shift 2;;
    --no-build)
      NO_BUILD="true"; shift;;
    --help|-h)
      usage; exit 0;;
    *)
      err "Unknown option: $1"; usage; exit 1;;
  esac
done

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

# Check for Docker Compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
  err "Docker Compose is not available. Install Docker Compose first."; exit 1
fi

# Use docker compose if available, otherwise docker-compose
if docker compose version &> /dev/null; then
  COMPOSE_CMD="docker compose"
else
  COMPOSE_CMD="docker-compose"
fi
ok "Docker Compose available"

# Check compose file
if [[ ! -f "$COMPOSE_FILE" ]]; then
  err "Docker Compose file not found: $COMPOSE_FILE"; exit 1
fi
ok "Found compose file: $COMPOSE_FILE"

# Always clean and build app assets for fresh build
info "Cleaning and building app assets for fresh build..."
if [[ -f "./build-all.sh" ]]; then
  chmod +x ./build-all.sh || true
  ./build-all.sh --app-only
else
  warn "build-all.sh not found. Attempting minimal local build..."
  if command -v node >/dev/null 2>&1; then
    npm install --legacy-peer-deps
    make clean
    make compile
    make deploy
  else
    err "Node.js not available to build assets. Install Node.js or provide pre-built assets."; exit 1
  fi
fi
ok "App assets built"

# Stop and remove all running containers to avoid port conflicts
info "Stopping and removing ALL running containers..."
docker ps -aq | xargs -r docker stop >/dev/null 2>&1 || true
docker ps -aq | xargs -r docker rm >/dev/null 2>&1 || true
ok "All containers stopped and removed"

# Build image (unless skipped)
if [[ "$NO_BUILD" == "false" ]]; then
  info "Building Docker image (${IMAGE_NAME})..."
  docker build --no-cache -t "$IMAGE_NAME" -f Dockerfile.simple .
  IMAGE_ID=$(docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | awk '$1=="jitsi-meet:latest"{print $2; exit}')
  ok "Image built: ${IMAGE_NAME} (${IMAGE_ID:-unknown})"
else
  info "Skipping build as requested (--no-build)"
fi

# Stop existing stack
info "Stopping existing Jitsi Meet stack..."
$COMPOSE_CMD -f "$COMPOSE_FILE" down --remove-orphans >/dev/null 2>&1 || true
ok "Existing stack stopped"

# Set port
if [[ -z "$PORT" ]]; then
  PORT=8000
fi

# Update compose file with custom port
info "Configuring stack for port ${PORT}..."
sed -i.bak "s/8000:80/${PORT}:80/" "$COMPOSE_FILE"

# Start the complete stack
info "Starting complete Jitsi Meet stack..."
$COMPOSE_CMD -f "$COMPOSE_FILE" up -d

ok "Stack started"

# Health wait
info "Waiting for services to become healthy..."
ATTEMPTS=60
SLEEP_SECS=2
HEALTH_URL="http://localhost:${PORT}"

for ((i=1;i<=ATTEMPTS;i++)); do
  if curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then
    ok "Web service healthy (${HEALTH_URL})"
    break
  fi
  if [[ $i -eq $ATTEMPTS ]]; then
    warn "Web service not responding after ${ATTEMPTS} attempts"
    warn "Check logs with: $COMPOSE_CMD -f $COMPOSE_FILE logs"
  fi
  sleep "$SLEEP_SECS"
done

# Restore original compose file
mv "$COMPOSE_FILE.bak" "$COMPOSE_FILE" 2>/dev/null || true

echo
ok "🎉 Complete Jitsi Meet stack is running!"
echo "🌐 Open: http://localhost:${PORT}"
echo
echo "🔧 Useful commands:"
echo "  Logs   : $COMPOSE_CMD -f $COMPOSE_FILE logs -f"
echo "  Stop   : $COMPOSE_CMD -f $COMPOSE_FILE down"
echo "  Restart: $COMPOSE_CMD -f $COMPOSE_FILE restart"
echo "  Status : $COMPOSE_CMD -f $COMPOSE_FILE ps"
echo
echo "📋 Services running:"
echo "  - Web frontend (port ${PORT})"
echo "  - Prosody XMPP server (port 5280)"
echo "  - Jicofo conference focus"
echo "  - JVB video bridge (port 10000/udp)"
echo

