# 🚀 How to Share Your Jitsi Meet Docker Image

## Option 1: Docker Hub (Recommended)

### Step 1: Create Docker Hub Account

1. Go to [hub.docker.com](https://hub.docker.com)
2. Sign up for a free account
3. Verify your email

### Step 2: Login and Push

```bash
# Login to Docker Hub
docker login

# Tag your image with your username
docker tag jitsi-meet:latest YOUR_USERNAME/jitsi-meet:latest

# Push to Docker Hub
docker push YOUR_USERNAME/jitsi-meet:latest
```

### Step 3: Share with Others

Others can now use your image with:

```bash
docker pull YOUR_USERNAME/jitsi-meet:latest
docker run -p 8080:80 YOUR_USERNAME/jitsi-meet:latest
```

## Option 2: Export/Import Docker Image

### Export Image to File

```bash
# Export the image to a tar file
docker save jitsi-meet:latest -o jitsi-meet-image.tar

# Compress the file (optional)
gzip jitsi-meet-image.tar
```

### Share the File

-   Upload `jitsi-meet-image.tar.gz` to cloud storage (Google Drive, Dropbox, etc.)
-   Or share via email (if file size allows)

### Import on Another Machine

```bash
# Download and import the image
docker load -i jitsi-meet-image.tar

# Run the container
docker run -p 8080:80 jitsi-meet:latest
```

## Option 3: GitHub Container Registry (ghcr.io)

### Step 1: Login to GitHub Container Registry

```bash
# Login with GitHub token
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin
```

### Step 2: Tag and Push

```bash
# Tag for GitHub Container Registry
docker tag jitsi-meet:latest ghcr.io/YOUR_USERNAME/jitsi-meet:latest

# Push to GitHub Container Registry
docker push ghcr.io/YOUR_USERNAME/jitsi-meet:latest
```

### Step 3: Share

Others can use:

```bash
docker pull ghcr.io/YOUR_USERNAME/jitsi-meet:latest
docker run -p 8080:80 ghcr.io/YOUR_USERNAME/jitsi-meet:latest
```

## Option 4: Private Registry

### Self-hosted Registry

```bash
# Run a private registry
docker run -d -p 5000:5000 --name registry registry:2

# Tag for private registry
docker tag jitsi-meet:latest localhost:5000/jitsi-meet:latest

# Push to private registry
docker push localhost:5000/jitsi-meet:latest
```

## 📋 Complete Sharing Guide

### For Docker Hub (Most Popular):

1. **Create Docker Hub account** at [hub.docker.com](https://hub.docker.com)

2. **Login and tag your image:**

    ```bash
    docker login
    docker tag jitsi-meet:latest YOUR_USERNAME/jitsi-meet:latest
    ```

3. **Push to Docker Hub:**

    ```bash
    docker push YOUR_USERNAME/jitsi-meet:latest
    ```

4. **Share with others:**
    ```bash
    # Others can pull and run your image
    docker pull YOUR_USERNAME/jitsi-meet:latest
    docker run -p 8080:80 YOUR_USERNAME/jitsi-meet:latest
    ```

### For File Sharing:

1. **Export the image:**

    ```bash
    docker save jitsi-meet:latest -o jitsi-meet-image.tar
    gzip jitsi-meet-image.tar
    ```

2. **Share the file** via cloud storage or email

3. **Others import and run:**
    ```bash
    docker load -i jitsi-meet-image.tar.gz
    docker run -p 8080:80 jitsi-meet:latest
    ```

## 🎯 Quick Commands

### Check Image Size

```bash
docker images jitsi-meet:latest
```

### Test Before Sharing

```bash
# Test the image works
docker run -d -p 8080:80 --name test jitsi-meet:latest
curl http://localhost:8080/health
docker stop test && docker rm test
```

### Create a README for Users

````bash
# Create a simple usage guide
cat > README-Usage.md << 'EOF'
# Jitsi Meet Docker Image

## Quick Start
```bash
docker run -p 8080:80 YOUR_USERNAME/jitsi-meet:latest
````

## Access

Open your browser to: http://localhost:8080

## Features

-   ✅ Production-ready Jitsi Meet
-   ✅ All configuration files included
-   ✅ Optimized Nginx server
-   ✅ Health check endpoint

## Configuration

Edit `config.js` and `interface_config.js` to customize your instance.
EOF

````

## 🔧 Advanced Options

### Multi-architecture Build
```bash
# Build for multiple platforms
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 -t YOUR_USERNAME/jitsi-meet:latest --push .
````

### Version Tags

```bash
# Tag with version
docker tag jitsi-meet:latest YOUR_USERNAME/jitsi-meet:v1.0.0
docker tag jitsi-meet:latest YOUR_USERNAME/jitsi-meet:latest

# Push both tags
docker push YOUR_USERNAME/jitsi-meet:v1.0.0
docker push YOUR_USERNAME/jitsi-meet:latest
```

## 📝 Best Practices

1. **Always test** your image before sharing
2. **Use semantic versioning** for tags (v1.0.0, v1.1.0, etc.)
3. **Include documentation** with usage instructions
4. **Keep images small** by using multi-stage builds
5. **Use specific tags** instead of just `latest`

## 🚀 Ready to Share!

Choose the method that works best for your needs:

-   **Docker Hub**: Best for public sharing
-   **File Export**: Best for private sharing
-   **GitHub Container Registry**: Best for GitHub users
-   **Private Registry**: Best for enterprise use


