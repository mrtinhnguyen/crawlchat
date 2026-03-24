#!/bin/bash
# ===========================================
# CrawlChat VPS Setup Script
# ===========================================
# For fresh Ubuntu 22.04 LTS VPS
# Installs all prerequisites automatically
# Usage: sudo ./setup-vps.sh
# ===========================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "Please run as root: sudo $0"
fi

# Check Ubuntu version
if [ ! -f /etc/lsb-release ]; then
    error "This script is designed for Ubuntu. /etc/lsb-release not found."
fi

source /etc/lsb-release
info "Detected: $DISTRIB_DESCRIPTION"

# Update system
log "Updating system packages..."
apt update && apt upgrade -y

# Install essential packages
log "Installing essential packages..."
apt install -y \
    curl \
    wget \
    git \
    nano \
    htop \
    fail2ban \
    ufw \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https

# Install Docker
log "Installing Docker..."
if ! command -v docker &> /dev/null; then
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
    
    log "Docker installed successfully"
else
    warn "Docker is already installed"
fi

# Install Nginx
log "Installing Nginx..."
if ! command -v nginx &> /dev/null; then
    apt install -y nginx
    systemctl enable nginx
    systemctl start nginx
    log "Nginx installed successfully"
else
    warn "Nginx is already installed"
fi

# Install Certbot
log "Installing Certbot..."
if ! command -v certbot &> /dev/null; then
    apt install -y certbot python3-certbot-nginx
    log "Certbot installed successfully"
else
    warn "Certbot is already installed"
fi

# Configure firewall
log "Configuring firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable
ufw status

# Configure fail2ban
log "Configuring fail2ban..."
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 1h

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
port = http,https
logpath = /var/log/nginx/*error.log
maxretry = 5
bantime = 1h
EOF

systemctl enable fail2ban
systemctl restart fail2ban

# Create app user
log "Creating application user..."
if ! id -u crawlchat &>/dev/null; then
    useradd -m -s /bin/bash crawlchat
    usermod -aG docker crawlchat
    log "User 'crawlchat' created"
else
    warn "User 'crawlchat' already exists"
fi

# Create app directories
log "Creating application directories..."
mkdir -p /opt/crawlchat
mkdir -p /opt/backups/crawlchat
chown -R crawlchat:crawlchat /opt/crawlchat
chown -R crawlchat:crawlchat /opt/backups

# Configure SSH security
log "Securing SSH..."
sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config || true
systemctl reload sshd || warn "Could not reload SSH config"

# Install unattended-upgrades for security updates
log "Configuring automatic security updates..."
apt install -y unattended-upgrades
echo 'Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::Package-Blacklist {};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";' > /etc/apt/apt.conf.d/50unattended-upgrades

# Setup log rotation
log "Configuring log rotation..."
cat > /etc/logrotate.d/crawlchat << 'EOF'
/opt/crawlchat/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 0640 crawlchat crawlchat
    sharedscripts
}
EOF

# Create systemd service for CrawlChat
log "Creating systemd service..."
cat > /etc/systemd/system/crawlchat.service << 'EOF'
[Unit]
Description=CrawlChat Docker Compose Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/crawlchat
User=crawlchat
ExecStart=/usr/bin/docker compose -f docker/docker-compose.prod.yml up -d
ExecStop=/usr/bin/docker compose -f docker/docker-compose.prod.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable crawlchat.service

# Create backup cronjob
log "Setting up backup cronjob..."
(crontab -u crawlchat -l 2>/dev/null | grep -v "crawlchat/backup.sh" || true; echo "0 2 * * * /opt/crawlchat/backup.sh >> /var/log/crawlchat-backup.log 2>&1") | crontab -u crawlchat -

# Summary
echo ""
echo "=========================================="
echo "      CrawlChat VPS Setup Complete!      "
echo "=========================================="
echo ""
echo "Installed Components:"
echo "  ✅ Docker & Docker Compose"
echo "  ✅ Nginx"
echo "  ✅ Certbot (SSL)"
echo "  ✅ Firewall (UFW)"
echo "  ✅ Fail2Ban"
echo "  ✅ Automatic Security Updates"
echo ""
echo "Application Directories:"
echo "  📁 /opt/crawlchat      - Application"
echo "  📁 /opt/backups        - Backups"
echo ""
echo "Next Steps:"
echo "  1. Clone your repository:"
echo "     su - crawlchat"
echo "     git clone https://github.com/YOUR_REPO/crawlchat.git /opt/crawlchat"
echo ""
echo "  2. Create .env file:"
echo "     cp /opt/crawlchat/.env.example /opt/crawlchat/.env"
echo "     nano /opt/crawlchat/.env"
echo ""
echo "  3. Start the application:"
echo "     sudo systemctl start crawlchat"
echo ""
echo "  4. Setup SSL certificates:"
echo "     sudo certbot --nginx -d yourdomain.com"
echo ""
echo "  5. Check status:"
echo "     sudo systemctl status crawlchat"
echo "     docker compose -f /opt/crawlchat/docker/docker-compose.prod.yml ps"
echo ""
