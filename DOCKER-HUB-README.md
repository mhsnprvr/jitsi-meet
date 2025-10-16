# Jitsi Meet - Custom Edition

A fully functional Jitsi Meet video conferencing platform with custom UI and complete backend services.

## 🚀 Quick Start

### Option 1: Use Docker Compose (Recommended)

```bash
# Download the docker-compose file
curl -O https://raw.githubusercontent.com/YOUR_REPO/docker-compose-complete.yml

# Start all services
docker-compose -f docker-compose-complete.yml up -d
```

Access your Jitsi Meet instance at: **http://localhost:8000**

### Option 2: Manual Docker Run

```bash
# Start backend services
docker network create meet.jitsi

# Prosody XMPP Server
docker run -d --name prosody --network meet.jitsi \
  -e ENABLE_AUTH=0 \
  -e ENABLE_GUESTS=1 \
  -e XMPP_DOMAIN=meet.jitsi \
  -e XMPP_AUTH_DOMAIN=auth.meet.jitsi \
  -e XMPP_MUC_DOMAIN=muc.meet.jitsi \
  -e XMPP_INTERNAL_MUC_DOMAIN=internal-muc.meet.jitsi \
  -e JICOFO_AUTH_USER=focus \
  -e JICOFO_AUTH_PASSWORD=jicofopass \
  -e JVB_AUTH_USER=jvb \
  -e JVB_AUTH_PASSWORD=jvbpass \
  jitsi/prosody:stable-9584

# Jicofo (Conference Focus)
docker run -d --name jicofo --network meet.jitsi \
  -e XMPP_DOMAIN=meet.jitsi \
  -e XMPP_AUTH_DOMAIN=auth.meet.jitsi \
  -e XMPP_INTERNAL_MUC_DOMAIN=internal-muc.meet.jitsi \
  -e XMPP_SERVER=prosody \
  -e JICOFO_AUTH_USER=focus \
  -e JICOFO_AUTH_PASSWORD=jicofopass \
  -e JVB_BREWERY_MUC=jvbbrewery \
  jitsi/jicofo:stable-9584

# JVB (Video Bridge)
docker run -d --name jvb --network meet.jitsi \
  -p 10000:10000/udp \
  -e XMPP_AUTH_DOMAIN=auth.meet.jitsi \
  -e XMPP_INTERNAL_MUC_DOMAIN=internal-muc.meet.jitsi \
  -e XMPP_SERVER=prosody \
  -e JVB_AUTH_USER=jvb \
  -e JVB_AUTH_PASSWORD=jvbpass \
  -e JVB_BREWERY_MUC=jvbbrewery \
  -e JVB_PORT=10000 \
  jitsi/jvb:stable-9584

# Custom Web Frontend
docker run -d --name jitsi-web --network meet.jitsi \
  -p 8000:80 \
  mowsen/jitsi-meet:latest
```

## 📦 What's Included

This image includes:

- ✅ **Custom Jitsi Meet Frontend** - Modified UI with custom features
- ✅ **Prosody XMPP Server** - For signaling and presence
- ✅ **Jicofo** - Conference focus component
- ✅ **JVB (Jitsi Video Bridge)** - For media handling
- ✅ **Production-ready Configuration** - Optimized settings
- ✅ **Health Checks** - Monitoring endpoints

## 🔧 Configuration

### Environment Variables

The web frontend supports the following environment variables:

- `PUBLIC_URL` - Your public URL (default: http://localhost:8000)
- `ENABLE_AUTH` - Enable authentication (0 or 1)
- `ENABLE_GUESTS` - Allow guest access (0 or 1)

### Custom Configuration

To customize the configuration, you can:

1. Mount custom config files:
   ```bash
   docker run -d \
     -v ./config.js:/usr/share/nginx/html/config.js \
     -v ./interface_config.js:/usr/share/nginx/html/interface_config.js \
     -p 8000:80 \
     mowsen/jitsi-meet:latest
   ```

2. Or extend the image with your own Dockerfile

## 🌐 Network Architecture

```
┌─────────────────┐
│   Web Frontend  │ :8000
│  (Your Custom   │
│      UI)        │
└────────┬────────┘
         │
         │ HTTP/WebSocket
         │
┌────────▼────────┐
│    Prosody      │ :5222, :5280
│  (XMPP Server)  │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
┌───▼──┐  ┌──▼───┐
│Jicofo│  │ JVB  │ :10000/udp
│      │  │      │
└──────┘  └──────┘
```

## 📊 Ports

- `8000` - Web interface (HTTP)
- `10000/udp` - Video bridge (RTP/RTCP)
- `5222` - XMPP client connections
- `5280` - BOSH connections

## 🔒 Security

- Default configuration allows guest access for easy setup
- For production, enable authentication via environment variables
- Use reverse proxy (Nginx/Caddy) with SSL/TLS
- Configure firewall rules for port 10000/udp

## 🐛 Troubleshooting

### Connection Issues

If you're experiencing disconnections:

1. Check all containers are running:
   ```bash
   docker ps
   ```

2. Check container logs:
   ```bash
   docker logs jitsi-web
   docker logs prosody
   docker logs jicofo
   docker logs jvb
   ```

3. Ensure port 10000/udp is accessible for video streams

### Audio/Video Issues

1. Verify JVB is reachable on port 10000/udp
2. Check browser console for errors
3. Ensure STUN servers are reachable

## 📝 Management Commands

```bash
# View running services
docker-compose ps

# View logs
docker-compose logs -f

# Restart services
docker-compose restart

# Stop services
docker-compose down

# Update to latest version
docker-compose pull
docker-compose up -d
```

## 🎯 Features

- **Video Conferencing** - HD video calls with multiple participants
- **Screen Sharing** - Share your screen with participants
- **Chat** - Built-in text chat
- **Recording** - Record meetings (with additional configuration)
- **Virtual Backgrounds** - Blur or replace your background
- **Breakout Rooms** - Split participants into separate rooms
- **Polls** - Create and vote on polls
- **Reactions** - Emoji reactions during meetings

## 💡 Use Cases

- Remote team meetings
- Online classes and webinars
- Virtual events and conferences
- One-on-one video calls
- Customer support sessions

## 🔗 Resources

- [Jitsi Meet Documentation](https://jitsi.github.io/handbook/)
- [Docker Hub](https://hub.docker.com/r/mowsen/jitsi-meet)
- [Report Issues](https://github.com/YOUR_REPO/issues)

## 📄 License

This image is based on Jitsi Meet, which is licensed under Apache License 2.0.

## 🤝 Support

For issues, questions, or contributions:
- Open an issue on GitHub
- Contact: your-email@example.com

## 🎉 Quick Test

After starting the containers, visit `http://localhost:8000` and create a meeting. You should be able to:

1. Create a new meeting room
2. Join with audio/video
3. Share your screen
4. Invite others by sharing the room URL

Enjoy your Jitsi Meet experience! 🚀
