#!/bin/bash
# ===========================================
# HDND An Khanh - Quick Deploy Script
# Domain: chat.hanoi.vn
# ===========================================

set -e

COMPOSE_FILE="/opt/crawlchat/docker/docker-compose.hdnd-ankhanh.yml"

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

cd /opt/crawlchat

case "${1:-deploy}" in
    deploy)
        log "Deploying HDND An Khanh..."
        
        # Pull latest code
        git pull origin brand-hdnd-ankhanh 2>/dev/null || git pull
        
        # Pull images
        docker compose -f "$COMPOSE_FILE" pull
        
        # Start services
        docker compose -f "$COMPOSE_FILE" up -d
        
        log "Waiting for services..."
        sleep 30
        
        # Show status
        docker compose -f "$COMPOSE_FILE" ps
        ;;
    
    start)
        log "Starting services..."
        docker compose -f "$COMPOSE_FILE" up -d
        ;;
    
    stop)
        log "Stopping services..."
        docker compose -f "$COMPOSE_FILE" down
        ;;
    
    restart)
        log "Restarting services..."
        docker compose -f "$COMPOSE_FILE" restart
        ;;
    
    logs)
        docker compose -f "$COMPOSE_FILE" logs -f --tail=100
        ;;
    
    status)
        docker compose -f "$COMPOSE_FILE" ps
        echo ""
        echo "=== Health Check ==="
        curl -s https://chat.hanoi.vn/health 2>/dev/null && echo "✅ Frontend OK" || echo "❌ Frontend Failed"
        curl -s https://api.chat.hanoi.vn/health 2>/dev/null && echo "✅ API OK" || echo "❌ API Failed"
        ;;
    
    update)
        log "Updating application..."
        git pull origin brand-hdnd-ankhanh 2>/dev/null || git pull
        docker compose -f "$COMPOSE_FILE" pull
        docker compose -f "$COMPOSE_FILE" up -d
        docker image prune -f
        log "Update complete!"
        ;;
    
    backup)
        BACKUP_DIR="/opt/backups/crawlchat"
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        
        mkdir -p "$BACKUP_DIR"
        
        log "Creating backup..."
        
        # Backup MongoDB
        docker compose -f "$COMPOSE_FILE" exec -T database \
            mongodump --archive > "${BACKUP_DIR}/mongo_${TIMESTAMP}.archive" 2>/dev/null || warn "MongoDB backup failed"
        
        # Backup PostgreSQL
        docker compose -f "$COMPOSE_FILE" exec -T pgvector \
            pg_dump -U postgres crawlchat_hdnd_ankhanh > "${BACKUP_DIR}/pgvector_${TIMESTAMP}.sql" 2>/dev/null || warn "PostgreSQL backup failed"
        
        # Cleanup old backups
        find "$BACKUP_DIR" -type f -mtime +7 -delete 2>/dev/null
        
        log "Backup complete: ${BACKUP_DIR}"
        ;;
    
    *)
        echo "Usage: $0 {deploy|start|stop|restart|logs|status|update|backup}"
        exit 1
        ;;
esac
