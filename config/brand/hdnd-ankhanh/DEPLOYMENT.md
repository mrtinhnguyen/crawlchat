# HDND An Khanh - Deployment Guide
## Domain: chat.hanoi.vn

---

## 📋 Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [VPS Setup](#2-vps-setup)
3. [Environment Variables](#3-environment-variables)
4. [Domain Configuration](#4-domain-configuration)
5. [SSL Certificates](#5-ssl-certificates)
6. [Deploy Application](#6-deploy-application)
7. [Verify Deployment](#7-verify-deployment)
8. [Troubleshooting](#8-troubleshooting)

---

## 1. Prerequisites

### Hardware Requirements
- **CPU**: 2+ cores
- **RAM**: 4GB+ (recommended 8GB)
- **Storage**: 40GB+ SSD
- **OS**: Ubuntu 22.04 LTS

### Required Information
- [ ] VPS IP Address
- [ ] Domain: `chat.hanoi.vn`
- [ ] API Key (OpenAI or Gemini or OpenRouter)

---

## 2. VPS Setup

### Step 2.1: Connect to VPS

```bash
# Connect via SSH
ssh root@YOUR_VPS_IP
```

### Step 2.2: Update System

```bash
apt update && apt upgrade -y
```

### Step 2.3: Install Docker

```bash
# Install dependencies
apt install -y ca-certificates curl gnupg lsb-release

# Add Docker GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable Docker
systemctl enable docker
systemctl start docker

# Verify
docker --version
docker compose version
```

### Step 2.4: Install Nginx & Certbot

```bash
# Install Nginx
apt install -y nginx

# Install Certbot
apt install -y certbot python3-certbot-nginx

# Enable Nginx
systemctl enable nginx
systemctl start nginx
```

### Step 2.5: Configure Firewall

```bash
# Allow SSH, HTTP, HTTPS
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

# Check status
ufw status
```

---

## 3. Environment Variables

### Step 3.1: Create Application Directory

```bash
mkdir -p /opt/crawlchat
cd /opt/crawlchat
```

### Step 3.2: Clone Repository

```bash
# Option A: Public repo
git clone https://github.com/YOUR_USERNAME/crawlchat.git .

# Option B: Private repo (using SSH key)
# First generate SSH key: ssh-keygen -t ed25519 -C "deploy@chat.hanoi.vn"
# Add public key to GitHub Deploy Keys
git clone git@github.com:YOUR_USERNAME/crawlchat.git .

# Checkout brand branch
git checkout brand-hdnd-ankhanh
```

### Step 3.3: Create .env File

```bash
# Copy template
cp .env.hdnd-ankhanh .env

# Edit file
nano .env
```

### Step 3.4: Configure Required Variables

Edit `.env` file with your values:

```env
# ==========================================
# REQUIRED - Must Change These Values
# ==========================================

# Generate strong JWT secret (run: openssl rand -base64 32)
JWT_SECRET=CHANGE_THIS_TO_RANDOM_32_CHAR_STRING

# Choose ONE LLM provider:

# Option A: OpenAI
OPENAI_API_KEY=sk-proj-xxxxxxxxxxxxxxxxxxxxxxxx

# Option B: Google Gemini
# GEMINI_API_KEY=AIzaxxxxxxxxxxxxxxxxxxxxxxxx

# Option C: OpenRouter
# OPENROUTER_API_KEY=sk-or-v1-xxxxxxxxxxxxxxxx

# ==========================================
# Domain URLs - Update for your domain
# ==========================================
VITE_APP_URL=https://chat.hanoi.vn
VITE_SERVER_URL=https://api.chat.hanoi.vn
VITE_SERVER_WS_URL=wss://api.chat.hanoi.vn
VITE_SOURCE_SYNC_URL=https://sync.chat.hanoi.vn

# ==========================================
# Admin Email (comma separated)
# ==========================================
ADMIN_EMAILS=admin@hanoi.vn,your-email@gmail.com
```

### Step 3.5: Generate JWT Secret

```bash
# Generate random secret
openssl rand -base64 32

# Copy the output and paste into .env as JWT_SECRET
```

---

## 4. Domain Configuration

### Step 4.1: DNS Records

Go to your domain registrar (where you bought hanoi.vn) and add DNS records:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | chat | YOUR_VPS_IP | 3600 |
| A | api.chat | YOUR_VPS_IP | 3600 |
| A | sync.chat | YOUR_VPS_IP | 3600 |

Example:
```
chat.hanoi.vn        A    123.45.67.89
api.chat.hanoi.vn    A    123.45.67.89
sync.chat.hanoi.vn   A    123.45.67.89
```

### Step 4.2: Verify DNS Propagation

```bash
# Wait 5-10 minutes, then verify
dig chat.hanoi.vn +short
dig api.chat.hanoi.vn +short
dig sync.chat.hanoi.vn +short

# Should return your VPS IP
```

### Step 4.3: Configure Nginx

```bash
# Copy Nginx config
cp /opt/crawlchat/config/nginx/hdnd-ankhanh.nginx.conf /etc/nginx/sites-available/hdnd-ankhanh

# Enable site
ln -s /etc/nginx/sites-available/hdnd-ankhanh /etc/nginx/sites-enabled/

# Remove default site (optional)
rm /etc/nginx/sites-enabled/default

# Test config
nginx -t

# Reload Nginx
systemctl reload nginx
```

---

## 5. SSL Certificates

### Step 5.1: Get SSL Certificates

```bash
# Get certificate for all subdomains
certbot --nginx -d chat.hanoi.vn -d api.chat.hanoi.vn -d sync.chat.hanoi.vn

# Follow prompts:
# 1. Enter email for notifications
# 2. Agree to terms
# 3. Choose: Redirect HTTP to HTTPS (Recommended)
```

### Step 5.2: Test Auto-Renewal

```bash
# Test renewal
certbot renew --dry-run

# Certbot auto-installs cronjob for renewal
```

### Step 5.3: Update Nginx Config with SSL Paths

The Certbot automatically updates Nginx config. Verify:

```bash
# Check if SSL is configured
cat /etc/nginx/sites-available/hdnd-ankhanh | grep ssl_certificate
```

---

## 6. Deploy Application

### Step 6.1: Update Docker Compose with API Key

```bash
nano /opt/crawlchat/docker/docker-compose.hdnd-ankhanh.yml
```

Update the API key section:

```yaml
# In server service, uncomment your chosen provider:
environment:
  # For OpenAI:
  OPENAI_API_KEY: "sk-proj-YOUR_ACTUAL_KEY_HERE"
  
  # For Gemini:
  # GEMINI_API_KEY: "AIza-YOUR_ACTUAL_KEY_HERE"
  
  # For OpenRouter:
  # OPENROUTER_API_KEY: "sk-or-v1-YOUR_ACTUAL_KEY_HERE"
```

### Step 6.2: Pull Docker Images

```bash
cd /opt/crawlchat

# Pull pre-built images
docker compose -f docker/docker-compose.hdnd-ankhanh.yml pull
```

### Step 6.3: Start Services

```bash
# Start all services
docker compose -f docker/docker-compose.hdnd-ankhanh.yml up -d

# Check status
docker compose -f docker/docker-compose.hdnd-ankhanh.yml ps
```

### Step 6.4: Wait for MongoDB Replica Set

```bash
# Wait 60 seconds for MongoDB to initialize
sleep 60

# Check MongoDB replica set status
docker compose -f docker/docker-compose.hdnd-ankhanh.yml exec database mongosh --eval "rs.status()"
```

---

## 7. Verify Deployment

### Step 7.1: Check All Services

```bash
# Check container status
docker compose -f docker/docker-compose.hdnd-ankhanh.yml ps

# All services should show "Up" or "healthy"
```

### Step 7.2: Check Logs

```bash
# View all logs
docker compose -f docker/docker-compose.hdnd-ankhanh.yml logs -f

# View specific service logs
docker compose -f docker/docker-compose.hdnd-ankhanh.yml logs -f front
docker compose -f docker/docker-compose.hdnd-ankhanh.yml logs -f server
```

### Step 7.3: Test Endpoints

```bash
# Test frontend
curl -I https://chat.hanoi.vn

# Test API health
curl https://api.chat.hanoi.vn/health

# Should return 200 OK
```

### Step 7.4: Access Web Interface

Open browser and go to: `https://chat.hanoi.vn`

You should see the login/signup page.

---

## 8. Troubleshooting

### MongoDB Issues

```bash
# Check MongoDB logs
docker compose -f docker/docker-compose.hdnd-ankhanh.yml logs database

# Manually initiate replica set
docker compose -f docker/docker-compose.hdnd-ankhanh.yml exec database mongosh --eval "rs.initiate({_id:'rs0',members:[{_id:0,host:'database:27017'}]})"

# Check replica set
docker compose -f docker/docker-compose.hdnd-ankhanh.yml exec database mongosh --eval "rs.status()"
```

### Container Not Starting

```bash
# Check logs for errors
docker compose -f docker/docker-compose.hdnd-ankhanh.yml logs <service_name>

# Restart specific service
docker compose -f docker/docker-compose.hdnd-ankhanh.yml restart <service_name>

# Full restart
docker compose -f docker/docker-compose.hdnd-ankhanh.yml down
docker compose -f docker/docker-compose.hdnd-ankhanh.yml up -d
```

### Port Already in Use

```bash
# Check what's using the port
lsof -i :3101
lsof -i :3102

# Kill process if needed
kill -9 <PID>
```

### SSL Certificate Issues

```bash
# Check certificate
certbot certificates

# Force renew
certbot renew --force-renewal

# Reload nginx
systemctl reload nginx
```

### API Key Not Working

```bash
# Check if environment variable is set
docker compose -f docker/docker-compose.hdnd-ankhanh.yml exec server env | grep -i api_key

# Test API connection
curl https://api.chat.hanoi.vn/health/ai
```

---

## 🔧 Quick Commands Reference

```bash
# Start services
docker compose -f docker/docker-compose.hdnd-ankhanh.yml up -d

# Stop services
docker compose -f docker/docker-compose.hdnd-ankhanh.yml down

# View logs
docker compose -f docker/docker-compose.hdnd-ankhanh.yml logs -f

# Restart services
docker compose -f docker/docker-compose.hdnd-ankhanh.yml restart

# Check status
docker compose -f docker/docker-compose.hdnd-ankhanh.yml ps

# Update deployment
git pull
docker compose -f docker/docker-compose.hdnd-ankhanh.yml pull
docker compose -f docker/docker-compose.hdnd-ankhanh.yml up -d
```

---

## 📊 Service Ports

| Service | Internal Port | External Port | URL |
|---------|---------------|---------------|-----|
| Frontend | 3000 | 3101 | https://chat.hanoi.vn |
| Server API | 3000 | 3102 | https://api.chat.hanoi.vn |
| Source Sync | 3000 | 3103 | https://sync.chat.hanoi.vn |
| Marker | 80 | 3105 | Internal only |
| MongoDB | 27017 | - | Internal only |
| Redis | 6379 | - | Internal only |
| PostgreSQL | 5432 | - | Internal only |

---

## ✅ Deployment Checklist

- [ ] VPS setup complete (Docker, Nginx, Certbot)
- [ ] DNS records configured (chat, api.chat, sync.chat)
- [ ] SSL certificates installed
- [ ] Environment variables configured
- [ ] JWT_SECRET generated and set
- [ ] API key configured (OpenAI/Gemini/OpenRouter)
- [ ] Docker services running
- [ ] MongoDB replica set initialized
- [ ] All health checks passing
- [ ] Web interface accessible

---

## 📞 Support

If you encounter issues:
1. Check logs: `docker compose logs -f`
2. Check Docker status: `docker compose ps`
3. Check Nginx: `nginx -t && systemctl status nginx`
4. Check SSL: `certbot certificates`
