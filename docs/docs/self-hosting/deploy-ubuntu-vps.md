---
sidebar_position: 4
---

# Deploy lên Ubuntu VPS

Hướng dẫn chi tiết deploy CrawlChat lên máy chủ VPS Ubuntu (production).

## Yêu cầu hệ thống

### Hardware Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 2 cores | 4+ cores |
| RAM | 4 GB | 8+ GB |
| Storage | 40 GB SSD | 100+ GB SSD |

### Software Requirements

- Ubuntu 22.04 LTS hoặc mới hơn
- Docker & Docker Compose
- Nginx (reverse proxy)
- Certbot (SSL certificates)

## Bước 1: Chuẩn bị VPS

### 1.1 Cập nhật hệ thống

```bash
sudo apt update && sudo apt upgrade -y
```

### 1.2 Cài đặt Docker

```bash
# Cài đặt dependencies
sudo apt install -y ca-certificates curl gnupg lsb-release

# Thêm Docker GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Thêm Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Cài đặt Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Thêm user vào docker group
sudo usermod -aG docker $USER
newgrp docker

# Kiểm tra cài đặt
docker --version
docker compose version
```

### 1.3 Cài đặt Nginx

```bash
sudo apt install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx
```

### 1.4 Cài đặt Certbot (SSL)

```bash
sudo apt install -y certbot python3-certbot-nginx
```

### 1.5 Cấu hình Firewall

```bash
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable
```

## Bước 2: Clone và cấu hình CrawlChat

### 2.1 Clone repository

```bash
# Tạo thư mục ứng dụng
sudo mkdir -p /opt/crawlchat
sudo chown $USER:$USER /opt/crawlchat

# Clone repository
cd /opt/crawlchat
git clone https://github.com/YOUR_USERNAME/crawlchat.git .
# Hoặc clone từ private repo:
# git clone git@github.com:YOUR_ORG/crawlchat.git .
```

### 2.2 Cấu hình Environment Variables

```bash
# Copy file .env.example
cp .env.example .env

# Chỉnh sửa file .env
nano .env
```

#### File .env cho Production

```env
# ================================
# COMMON - Bắt buộc
# ================================
DATABASE_URL=mongodb://database:27017/crawlchat?replicaSet=rs0
JWT_SECRET=YOUR_SUPER_SECURE_JWT_SECRET_MIN_32_CHARS
SELF_HOSTED=true

# ================================
# URLs - Cập nhật theo domain của bạn
# ================================
VITE_APP_URL=https://yourdomain.com
VITE_SERVER_URL=https://api.yourdomain.com
VITE_SERVER_WS_URL=wss://api.yourdomain.com
VITE_SOURCE_SYNC_URL=https://sync.yourdomain.com
SERVER_HOST=https://api.yourdomain.com
SOURCE_SYNC_URL=http://source_sync:3000

# ================================
# DATABASE - Internal Docker URLs
# ================================
PGVECTOR_URL=postgresql://postgres:crawlchat@pgvector:5432/crawlchat
REDIS_URL=redis://redis:6379

# ================================
# AI/LLM - Bắt buộc
# ================================
OPENROUTER_API_KEY=sk-or-v1-your-api-key-here

# ================================
# MARKER SERVICE
# ================================
MARKER_HOST=http://marker:80
MARKER_API_KEY=your-marker-api-key

# ================================
# OPTIONAL - Email
# ================================
RESEND_KEY=re_xxxxxxxxxxxxx
RESEND_FROM_EMAIL=noreply@yourdomain.com

# ================================
# OPTIONAL - OAuth
# ================================
GOOGLE_CLIENT_ID=xxxxx.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-xxxxx
GOOGLE_REDIRECT_URI=https://yourdomain.com/auth/google/callback

# ================================
# OPTIONAL - Admin
# ================================
ADMIN_EMAILS=admin@yourdomain.com

# ================================
# OPTIONAL - Payment
# ================================
DEFAULT_SIGNUP_PLAN_ID=free
```

### 2.3 Tạo JWT Secret mạnh

```bash
# Generate random JWT secret
openssl rand -base64 32
```

## Bước 3: Cấu hình Docker Compose

### 3.1 Tạo file docker-compose production

```bash
cp docker/docker-compose.yml docker/docker-compose.prod.yml
nano docker/docker-compose.prod.yml
```

### 3.2 Các thay đổi quan trọng

```yaml
# Trong docker-compose.prod.yml, cập nhật:

services:
  front:
    environment:
      VITE_APP_URL: "https://yourdomain.com"
      VITE_SERVER_WS_URL: "wss://api.yourdomain.com"
      VITE_SERVER_URL: "https://api.yourdomain.com"
      VITE_SOURCE_SYNC_URL: "https://sync.yourdomain.com"
      # ... các biến khác
    ports:
      - "127.0.0.1:3001:3000"  # Chỉ listen localhost

  server:
    ports:
      - "127.0.0.1:3002:3000"  # Chỉ listen localhost

  source_sync:
    ports:
      - "127.0.0.1:3003:3000"  # Chỉ listen localhost

  marker:
    ports:
      - "127.0.0.1:3005:80"    # Chỉ listen localhost
```

## Bước 4: Cấu hình Nginx Reverse Proxy

### 4.1 Tạo cấu hình Nginx cho Frontend

```bash
sudo nano /etc/nginx/sites-available/crawlchat-front
```

```nginx
# Frontend - yourdomain.com
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;

    location / {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

### 4.2 Tạo cấu hình Nginx cho Server API

```bash
sudo nano /etc/nginx/sites-available/crawlchat-api
```

```nginx
# API Server - api.yourdomain.com
server {
    listen 80;
    server_name api.yourdomain.com;

    location / {
        proxy_pass http://127.0.0.1:3002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # WebSocket support
        proxy_read_timeout 86400;
    }
}
```

### 4.3 Tạo cấu hình Nginx cho Source Sync

```bash
sudo nano /etc/nginx/sites-available/crawlchat-sync
```

```nginx
# Source Sync - sync.yourdomain.com
server {
    listen 80;
    server_name sync.yourdomain.com;

    location / {
        proxy_pass http://127.0.0.1:3003;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

### 4.4 Kích hoạt sites

```bash
sudo ln -s /etc/nginx/sites-available/crawlchat-front /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/crawlchat-api /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/crawlchat-sync /etc/nginx/sites-enabled/

# Xóa default site (optional)
sudo rm /etc/nginx/sites-enabled/default

# Test cấu hình
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

## Bước 5: Cài đặt SSL Certificates

### 5.1 Lấy SSL certificates

```bash
# Frontend
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

# API
sudo certbot --nginx -d api.yourdomain.com

# Source Sync
sudo certbot --nginx -d sync.yourdomain.com
```

### 5.2 Tự động gia hạn SSL

```bash
# Test renewal
sudo certbot renew --dry-run

# Certbot tự động cài đặt cronjob cho renewal
```

## Bước 6: Khởi động ứng dụng

### 6.1 Pull/Build Docker images

```bash
cd /opt/crawlchat

# Option 1: Sử dụng pre-built images từ GHCR
docker compose -f docker/docker-compose.prod.yml pull

# Option 2: Build từ source
docker compose -f docker/docker-compose.prod.yml build
```

### 6.2 Khởi động services

```bash
# Start tất cả services
docker compose -f docker/docker-compose.prod.yml up -d

# Xem logs
docker compose -f docker/docker-compose.prod.yml logs -f

# Kiểm tra status
docker compose -f docker/docker-compose.prod.yml ps
```

### 6.3 Kiểm tra MongoDB Replica Set

```bash
# Đợi database khởi động (khoảng 30-60 giây)
sleep 60

# Kiểm tra replica set status
docker compose -f docker/docker-compose.prod.yml exec database mongosh --eval "rs.status()"
```

## Bước 7: Thiết lập tự động khởi động

### 7.1 Tạo systemd service

```bash
sudo nano /etc/systemd/system/crawlchat.service
```

```ini
[Unit]
Description=CrawlChat Docker Compose Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/crawlchat
ExecStart=/usr/bin/docker compose -f docker/docker-compose.prod.yml up -d
ExecStop=/usr/bin/docker compose -f docker/docker-compose.prod.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

### 7.2 Kích hoạt service

```bash
sudo systemctl daemon-reload
sudo systemctl enable crawlchat.service
```

## Bước 8: Monitoring & Logs

### 8.1 Xem logs

```bash
# Tất cả services
docker compose -f docker/docker-compose.prod.yml logs -f

# Service cụ thể
docker compose -f docker/docker-compose.prod.yml logs -f front
docker compose -f docker/docker-compose.prod.yml logs -f server
docker compose -f docker/docker-compose.prod.yml logs -f source_sync

# Real-time logs với timestamp
docker compose -f docker/docker-compose.prod.yml logs -f --timestamps
```

### 8.2 Resource monitoring

```bash
# Docker resource usage
docker stats

# Disk usage
docker system df

# Volumes
docker volume ls
```

## Bước 9: Backup & Restore

### 9.1 Backup script

```bash
nano /opt/crawlchat/backup.sh
```

```bash
#!/bin/bash
BACKUP_DIR="/opt/backups/crawlchat"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="crawlchat_backup_${DATE}.tar.gz"

mkdir -p $BACKUP_DIR

# Backup MongoDB
docker compose -f /opt/crawlchat/docker/docker-compose.prod.yml exec -T database \
  mongodump --archive > $BACKUP_DIR/mongo_${DATE}.archive

# Backup PostgreSQL (PGVector)
docker compose -f /opt/crawlchat/docker/docker-compose.prod.yml exec -T pgvector \
  pg_dump -U postgres crawlchat > $BACKUP_DIR/pgvector_${DATE}.sql

# Backup .env
cp /opt/crawlchat/.env $BACKUP_DIR/env_${DATE}

# Compress
tar -czf $BACKUP_DIR/$BACKUP_FILE -C $BACKUP_DIR \
  mongo_${DATE}.archive pgvector_${DATE}.sql env_${DATE}

# Cleanup old backups (keep last 7 days)
find $BACKUP_DIR -name "crawlchat_backup_*.tar.gz" -mtime +7 -delete
find $BACKUP_DIR -name "mongo_*.archive" -mtime +7 -delete
find $BACKUP_DIR -name "pgvector_*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "env_*" -mtime +7 -delete

echo "Backup completed: $BACKUP_DIR/$BACKUP_FILE"
```

```bash
chmod +x /opt/crawlchat/backup.sh
```

### 9.2 Cronjob backup hàng ngày

```bash
# Mở crontab
crontab -e

# Thêm dòng sau (backup lúc 2:00 AM hàng ngày)
0 2 * * * /opt/crawlchat/backup.sh >> /var/log/crawlchat-backup.log 2>&1
```

## Bước 10: Update ứng dụng

### 10.1 Update script

```bash
nano /opt/crawlchat/update.sh
```

```bash
#!/bin/bash
set -e

cd /opt/crawlchat

# Pull latest code
git pull origin main

# Pull latest Docker images
docker compose -f docker/docker-compose.prod.yml pull

# Restart services with zero downtime
docker compose -f docker/docker-compose.prod.yml up -d

# Cleanup old images
docker image prune -f

echo "Update completed at $(date)"
```

```bash
chmod +x /opt/crawlchat/update.sh
```

## Troubleshooting

### Services không khởi động

```bash
# Check logs
docker compose -f docker/docker-compose.prod.yml logs

# Check container status
docker compose -f docker/docker-compose.prod.yml ps

# Restart specific service
docker compose -f docker/docker-compose.prod.yml restart front
```

### MongoDB connection issues

```bash
# Check MongoDB status
docker compose -f docker/docker-compose.prod.yml exec database mongosh --eval "db.adminCommand('ping')"

# Check replica set
docker compose -f docker/docker-compose.prod.yml exec database mongosh --eval "rs.status()"

# Manually initiate replica set
docker compose -f docker/docker-compose.prod.yml exec database mongosh --eval "rs.initiate({_id:'rs0',members:[{_id:0,host:'database:27017'}]})"
```

### Disk space issues

```bash
# Check disk usage
df -h

# Docker cleanup
docker system prune -a

# Remove unused volumes
docker volume prune
```

### SSL issues

```bash
# Check certificate status
sudo certbot certificates

# Force renew
sudo certbot renew --force-renewal
```

## Security Checklist

- [ ] Đổi JWT_SECRET thành giá trị mạnh và độc nhất
- [ ] Cấu hình firewall chỉ cho phép port 22, 80, 443
- [ ] Cài đặt fail2ban cho SSH protection
- [ ] Vô hiệu hóa root login qua SSH
- [ ] Thiết lập automatic security updates
- [ ] Backup database định kỳ
- [ ] Rotate API keys định kỳ
