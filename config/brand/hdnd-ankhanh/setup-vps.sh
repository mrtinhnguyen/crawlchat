#!/bin/bash
# ===========================================
# HDND An Khanh - VPS Auto Setup Script
# Domain: chat.hanoi.vn
# ===========================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check root
[ "$EUID" -ne 0 ] && error "Run as root: sudo $0"

echo ""
echo "=========================================="
echo "  HDND An Khanh - VPS Setup Script"
echo "  Domain: chat.hanoi.vn"
echo "=========================================="
echo ""

# Step 1: Update System
log "Step 1/8: Updating system..."
apt update && apt upgrade -y
apt install -y curl wget git nano htop fail2ban ufw ca-certificates gnupg lsb-release

# Step 2: Install Docker
log "Step 2/8: Installing Docker..."
if ! command -v docker &> /dev/null; then
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable docker
    systemctl start docker
    log "Docker installed successfully"
else
    warn "Docker already installed"
fi

# Step 3: Install Nginx & Certbot
log "Step 3/8: Installing Nginx & Certbot..."
apt install -y nginx certbot python3-certbot-nginx
systemctl enable nginx
systemctl start nginx

# Step 4: Configure Firewall
log "Step 4/8: Configuring firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

# Step 5: Create Application Directory
log "Step 5/8: Creating application directory..."
mkdir -p /opt/crawlchat
mkdir -p /opt/backups/crawlchat

# Step 6: Clone Repository
log "Step 6/8: Cloning repository..."
if [ ! -d "/opt/crawlchat/.git" ]; then
    info "Enter repository URL (e.g., https://github.com/user/crawlchat.git):"
    read -r REPO_URL
    git clone "$REPO_URL" /opt/crawlchat
    cd /opt/crawlchat
    git checkout brand-hdnd-ankhanh 2>/dev/null || warn "Branch brand-hdnd-ankhanh not found, using current branch"
else
    warn "Repository already exists, pulling latest..."
    cd /opt/crawlchat
    git pull
fi

# Step 7: Setup Environment
log "Step 7/8: Setting up environment..."
cd /opt/crawlchat

if [ ! -f ".env" ]; then
    cp .env.hdnd-ankhanh .env
    
    # Generate JWT secret
    JWT_SECRET=$(openssl rand -base64 32)
    sed -i "s|hdnd-ankhanh-secure-jwt-secret-change-this-in-production-min-32-chars|$JWT_SECRET|g" .env
    
    info "Generated JWT_SECRET: $JWT_SECRET"
    warn "Please edit .env and add your API key!"
fi

# Step 8: Setup Nginx
log "Step 8/8: Configuring Nginx..."
if [ -f "config/nginx/hdnd-ankhanh.nginx.conf" ]; then
    cp config/nginx/hdnd-ankhanh.nginx.conf /etc/nginx/sites-available/hdnd-ankhanh
    ln -sf /etc/nginx/sites-available/hdnd-ankhanh /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    nginx -t && systemctl reload nginx
fi

# Summary
echo ""
echo "=========================================="
echo "         SETUP COMPLETE!"
echo "=========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Configure DNS records:"
echo "   chat.hanoi.vn      A    YOUR_VPS_IP"
echo "   api.chat.hanoi.vn  A    YOUR_VPS_IP"
echo "   sync.chat.hanoi.vn A    YOUR_VPS_IP"
echo ""
echo "2. Edit .env file and add your API key:"
echo "   nano /opt/crawlchat/.env"
echo ""
echo "3. Get SSL certificates:"
echo "   certbot --nginx -d chat.hanoi.vn -d api.chat.hanoi.vn -d sync.chat.hanoi.vn"
echo ""
echo "4. Start services:"
echo "   cd /opt/crawlchat"
echo "   docker compose -f docker/docker-compose.hdnd-ankhanh.yml up -d"
echo ""
echo "5. Check status:"
echo "   docker compose -f docker/docker-compose.hdnd-ankhanh.yml ps"
echo ""
