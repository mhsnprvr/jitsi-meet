# 🚀 Jitsi Meet Docker Image - How to Use

## What You Received

-   `jitsi-meet-image.tar.gz` - Complete Docker image (47MB)
-   This README - Instructions on how to use it

## Quick Start (3 Steps)

### 1. Import the Docker Image

```bash
# Extract and load the image
gunzip jitsi-meet-image.tar.gz
docker load -i jitsi-meet-image.tar
```

### 2. Run the Container

```bash
# Start Jitsi Meet
docker run -p 8080:80 jitsi-meet:latest
```

### 3. Access the Application

Open your browser and go to: **http://localhost:8080**

## ✅ That's It!

Your Jitsi Meet application is now running locally.

## 🔧 Additional Commands

### Run in Background

```bash
# Run in background (detached mode)
docker run -d -p 8080:80 --name jitsi-meet-app jitsi-meet:latest
```

### Stop the Container

```bash
# Stop the container
docker stop jitsi-meet-app
```

### Start Again

```bash
# Start the container again
docker start jitsi-meet-app
```

### Remove Everything

```bash
# Stop and remove container
docker stop jitsi-meet-app
docker rm jitsi-meet-app

# Remove the image
docker rmi jitsi-meet:latest
```

## 🎯 Features Included

-   ✅ **Production-ready** Jitsi Meet
-   ✅ **All configuration files** included
-   ✅ **Optimized Nginx** server
-   ✅ **Health check** endpoint at `/health`
-   ✅ **No setup required** - just run!

## 🔍 Troubleshooting

### Check if it's running

```bash
# Check container status
docker ps

# Check logs
docker logs jitsi-meet-app
```

### Test the application

```bash
# Test health endpoint
curl http://localhost:8080/health
```

### If port 8080 is busy

```bash
# Use a different port (e.g., 3000)
docker run -p 3000:80 jitsi-meet:latest
# Then access: http://localhost:3000
```

## 📱 What You Can Do

1. **Create meeting rooms** by visiting the URL
2. **Share room links** with others
3. **Customize settings** by editing the configuration files
4. **Deploy to production** using the same Docker image

## 🆘 Need Help?

If you encounter any issues:

1. Make sure Docker is installed and running
2. Check that port 8080 is available
3. Try using a different port if needed
4. Check the container logs for errors

---

**Enjoy your Jitsi Meet instance! 🎉**


