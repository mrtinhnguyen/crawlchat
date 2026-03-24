---
sidebar_position: 5
---

# Multi-Branch Strategy cho nhiều Thương hiệu/Tổ chức

Hướng dẫn sử dụng Git branches để quản lý nhiều phiên bản CrawlChat cho các thương hiệu/tổ chức khác nhau.

## Tổng quan chiến lược

```
main (upstream/base)
  │
  ├── brand-acme         # Phiên bản cho ACME Corp
  │
  ├── brand-techcorp     # Phiên bản cho TechCorp
  │
  └── brand-startupxyz   # Phiên bản cho StartupXYZ
```

## Cấu trúc Branch

### Branch chính

| Branch | Mục đích | Merge từ |
|--------|----------|----------|
| `main` | Branch gốc, codebase chính | - |
| `brand-{name}` | Branch cho từng thương hiệu | `main` |

## Bước 1: Tạo branch cho thương hiệu mới

### 1.1 Tạo branch từ main

```bash
# Đảm bảo main branch được cập nhật
git checkout main
git pull origin main

# Tạo branch mới cho thương hiệu
git checkout -b brand-acme

# Push branch lên remote
git push -u origin brand-acme
```

### 1.2 Cấu trúc thư mục cho brand

```
crawlchat/
├── .env.acme                    # Environment cho ACME
├── docker/
│   └── docker-compose.acme.yml  # Docker compose cho ACME
├── front/
│   └── public/
│       ├── favicon-acme.ico     # Favicon cho ACME
│       └── logo-acme.svg        # Logo cho ACME
└── config/
    └── brand/
        └── acme/
            ├── colors.json      # Brand colors
            ├── logo.svg         # Logo chính
            └── theme.json       # Theme configuration
```

## Bước 2: Cấu hình Branding

### 2.1 Tạo file cấu hình thương hiệu

Tạo file `config/brand/{brand-name}/config.json`:

```json
{
  "brand": {
    "name": "ACME Corporation",
    "slug": "acme",
    "domain": "chat.acme.com",
    "support_email": "support@acme.com"
  },
  "appearance": {
    "primary_color": "#1E40AF",
    "secondary_color": "#3B82F6",
    "logo_url": "/assets/brand/acme/logo.svg",
    "favicon_url": "/assets/brand/acme/favicon.ico"
  },
  "features": {
    "enable_discord": false,
    "enable_slack": true,
    "enable_github": true,
    "custom_plans": ["acme-monthly", "acme-yearly"]
  },
  "oauth": {
    "google_enabled": true,
    "github_enabled": true
  }
}
```

### 2.2 Cấu hình Environment

Tạo file `.env.{brand}`:

```env
# .env.acme
# =================================
# ACME Corporation Configuration
# =================================

# App URLs
VITE_APP_URL=https://chat.acme.com
VITE_SERVER_URL=https://api.acme.com
VITE_SERVER_WS_URL=wss://api.acme.com
VITE_SOURCE_SYNC_URL=https://sync.acme.com

# Branding
VITE_BRAND_NAME=ACME Corporation
VITE_BRAND_SLUG=acme
VITE_PRIMARY_COLOR=#1E40AF

# Database
DATABASE_URL=mongodb://database:27017/crawlchat_acme?replicaSet=rs0
PGVECTOR_URL=postgresql://postgres:crawlchat@pgvector:5432/crawlchat_acme

# JWT
JWT_SECRET=acme-specific-jwt-secret-min-32-chars

# Admin
ADMIN_EMAILS=admin@acme.com

# Plans
DEFAULT_SIGNUP_PLAN_ID=acme-monthly

# OAuth
GOOGLE_CLIENT_ID=xxxxx.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-xxxxx
GOOGLE_REDIRECT_URI=https://chat.acme.com/auth/google/callback

# Optional integrations
SLACK_CLIENT_ID=xxxxx
SLACK_CLIENT_SECRET=xxxxx
```

### 2.3 Docker Compose cho Brand

Tạo file `docker/docker-compose.{brand}.yml`:

```yaml
name: crawlchat-acme

services:
  front:
    image: ghcr.io/your-org/crawlchat-front:latest
    # ... (copy from docker-compose.yml)
    environment:
      VITE_APP_URL: "https://chat.acme.com"
      VITE_SERVER_URL: "https://api.acme.com"
      VITE_SERVER_WS_URL: "wss://api.acme.com"
      VITE_BRAND_NAME: "ACME Corporation"
      # ...

  server:
    image: ghcr.io/your-org/crawlchat-server:latest
    environment:
      DATABASE_URL: "mongodb://database:27017/crawlchat_acme?replicaSet=rs0"
      # ...

  # Database riêng cho brand (optional)
  # Hoặc dùng chung database với schema prefix
```

## Bước 3: Quản lý Code Changes

### 3.1 Thay đổi chỉ cho brand cụ thể

```bash
# Đang ở brand-acme branch
git checkout brand-acme

# Thực hiện changes
# - Cập nhật logo/favicon
# - Thay đổi colors trong Tailwind
# - Custom components

# Commit changes
git add .
git commit -m "feat(acme): customize branding for ACME Corp"

# Push
git push origin brand-acme
```

### 3.2 Đồng bộ với main branch

```bash
# Đang ở brand-acme branch
git checkout brand-acme

# Merge updates từ main
git fetch origin
git merge origin/main

# Hoặc rebase để giữ history clean
git rebase origin/main

# Giải quyết conflicts nếu có
# Sau đó push
git push origin brand-acme --force-with-lease
```

### 3.3 Workflow hàng ngày

```bash
# 1. Làm việc trên brand branch
git checkout brand-acme
git pull origin brand-acme

# 2. Development
# ... code changes ...

# 3. Commit & Push
git add .
git commit -m "feat(acme): add custom feature"
git push origin brand-acme

# 4. Khi cần sync với upstream
git fetch origin main
git merge origin/main
git push origin brand-acme
```

## Bước 4: Build & Deploy cho từng Brand

### 4.1 Build Docker images cho brand

```bash
# Build với brand context
docker build \
  --build-arg BRAND_NAME=acme \
  --build-arg BRAND_CONFIG=config/brand/acme \
  -f docker/Dockerfile \
  -t crawlchat-front:acme-latest \
  .
```

### 4.2 Deploy script cho brand

Tạo script `deploy-brand.sh`:

```bash
#!/bin/bash
set -e

BRAND=$1
BRANCH="brand-${BRAND}"

if [ -z "$BRAND" ]; then
  echo "Usage: ./deploy-brand.sh <brand-name>"
  exit 1
fi

echo "Deploying ${BRAND}..."

# Switch to brand branch
git checkout ${BRANCH}
git pull origin ${BRANCH}

# Build images
docker compose -f docker/docker-compose.${BRAND}.yml build

# Deploy with zero downtime
docker compose -f docker/docker-compose.${BRAND}.yml up -d

echo "${BRAND} deployed successfully!"
```

### 4.3 GitHub Actions cho multi-brand

Tạo file `.github/workflows/deploy-brand.yml`:

```yaml
name: Deploy Brand

on:
  push:
    branches:
      - 'brand-*'

jobs:
  detect-brand:
    runs-on: ubuntu-latest
    outputs:
      brand: ${{ steps.extract.outputs.brand }}
    steps:
      - name: Extract brand name
        id: extract
        run: |
          BRAND=$(echo "${GITHUB_REF#refs/heads/}" | sed 's/brand-//')
          echo "brand=${BRAND}" >> $GITHUB_OUTPUT

  build-and-deploy:
    needs: detect-brand
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build and push images
        run: |
          BRAND=${{ needs.detect-brand.outputs.brand }}
          # Build logic here
          echo "Building for brand: ${BRAND}"

      - name: Deploy to VPS
        run: |
          BRAND=${{ needs.detect-brand.outputs.brand }}
          # Deploy logic here
          echo "Deploying brand: ${BRAND}"
```

## Bước 5: Database Strategy

### Option 1: Separate Databases

Mỗi brand có database riêng:

```yaml
# docker-compose.acme.yml
services:
  database:
    # ... MongoDB config
    volumes:
      - acme_mongo_data:/data/db

volumes:
  acme_mongo_data:
```

### Option 2: Shared Database với Schema Prefix

Dùng chung database, phân biệt bằng prefix:

```env
# ACME
DATABASE_URL=mongodb://database:27017/crawlchat?replicaSet=rs0
MONGO_COLLECTION_PREFIX=acme_

# TechCorp
DATABASE_URL=mongodb://database:27017/crawlchat?replicaSet=rs0
MONGO_COLLECTION_PREFIX=techcorp_
```

## Bước 6: Custom Assets

### 6.1 Logo & Favicon

```
front/public/
├── brand/
│   ├── acme/
│   │   ├── logo.svg
│   │   ├── logo-dark.svg
│   │   ├── favicon.ico
│   │   └── og-image.png
│   └── techcorp/
│       └── ...
```

### 6.2 Custom Theme Colors

Cập nhật `tailwind.config.ts` hoặc sử dụng CSS variables:

```css
/* front/app/app.css */
:root {
  --brand-primary: theme('colors.acme.primary');
  --brand-secondary: theme('colors.acme.secondary');
}

/* Hoặc inject runtime */
[data-brand="acme"] {
  --brand-primary: #1E40AF;
  --brand-secondary: #3B82F6;
}

[data-brand="techcorp"] {
  --brand-primary: #059669;
  --brand-secondary: #10B981;
}
```

## Quy tắc quản lý Branch

### DO's ✅

- Tạo branch `brand-{name}` từ `main` cho mỗi thương hiệu
- Đặt tên branch nhất quán: `brand-acme`, `brand-techcorp`
- Sync định kỳ với `main` để nhận bug fixes
- Tách biệt config files cho từng brand
- Document tất cả customizations

### DON'Ts ❌

- Không merge `brand-*` branches ngược lại `main`
- Không share sensitive configs (API keys, secrets)
- Không bỏ qua conflicts khi merge từ main
- Không hard-code brand-specific values trong shared code

## Cleanup & Maintenance

### Xóa brand branch

```bash
# Local
git branch -D brand-acme

# Remote
git push origin --delete brand-acme
```

### Archive brand configuration

```bash
# Tạo archive
git tag archive/brand-acme-$(date +%Y%m%d) brand-acme

# Push tag
git push origin archive/brand-acme-$(date +%Y%m%d)
```

## Monitoring Multi-Brand Deployments

### Health Check Script

```bash
#!/bin/bash
# health-check.sh

BRANDS=("acme" "techcorp" "startupxyz")

for BRAND in "${BRANDS[@]}"; do
  echo "Checking ${BRAND}..."
  
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" https://chat.${BRAND}.com/health)
  
  if [ "$RESPONSE" = "200" ]; then
    echo "✅ ${BRAND} is healthy"
  else
    echo "❌ ${BRAND} returned ${RESPONSE}"
    # Send alert
  fi
done
```

## Tóm tắt Workflow

```
┌─────────────────────────────────────────────────────────────┐
│                      MAIN BRANCH                             │
│                   (Base Codebase)                            │
└─────────────────────────────────────────────────────────────┘
                            │
         ┌──────────────────┼──────────────────┐
         │                  │                  │
         ▼                  ▼                  ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ brand-acme  │    │brand-techcorp│   │brand-startup│
│             │    │              │    │             │
│ - .env.acme │    │ - .env.tech  │    │ - .env.start│
│ - logo      │    │ - logo       │    │ - logo      │
│ - theme     │    │ - theme      │    │ - theme     │
│ - config    │    │ - config     │    │ - config    │
└─────────────┘    └─────────────┘    └─────────────┘
         │                  │                  │
         ▼                  ▼                  ▼
    chat.acme.com     chat.techcorp.com  chat.startup.com
```

1. **Develop**: Làm việc trên brand branch
2. **Sync**: Merge từ main để nhận updates
3. **Build**: Build Docker images với brand context
4. **Deploy**: Deploy lên VPS tương ứng
5. **Monitor**: Monitor health và logs
