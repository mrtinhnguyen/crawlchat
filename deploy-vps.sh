#!/bin/bash
# ===========================================
# CrawlChat VPS Deployment Script
# ===========================================
# For Ubuntu 22.04 LTS
# Usage: sudo ./deploy-vps.sh [brand-name]
# ===========================================

set -e

# Configuration
APP_DIR="/opt/crawlchat"
BACKUP_DIR="/opt/backups/crawlchat"
BRAND=${1:-"default"}
COMPOSE_FILE="${APP_DIR}/docker/docker-compose.prod.yml"

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

# Check brand-specific compose file
if [ "$BRAND" != "default" ]; then
    BRAND_COMPOSE="${APP_DIR}/docker/docker-compose.${BRAND}.yml"
    if [ -f "$BRAND_COMPOSE" ]; then
        COMPOSE_FILE="$BRAND_COMPOSE"
        log "Using brand compose file: $COMPOSE_FILE"
    else
        warn "Brand compose file not found: $BRAND_COMPOSE"
        warn "Using default compose file"
    fi
fi

# Check if compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
    error "Docker compose file not found: $COMPOSE_FILE"
fi

# Backup function
backup() {
    log "Starting backup..."
    mkdir -p "$BACKUP_DIR"
    
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    
    # Backup MongoDB
    if docker compose -f "$COMPOSE_FILE" ps database | grep -q "Up"; then
        log "Backing up MongoDB..."
        docker compose -f "$COMPOSE_FILE" exec -T database \
            mongodump --archive > "${BACKUP_DIR}/mongo_${TIMESTAMP}.archive" || warn "MongoDB backup failed"
    fi
    
    # Backup PostgreSQL
    if docker compose -f "$COMPOSE_FILE" ps pgvector | grep -q "Up"; then
        log "Backing up PostgreSQL..."
        docker compose -f "$COMPOSE_FILE" exec -T pgvector \
            pg_dump -U postgres crawlchat > "${BACKUP_DIR}/pgvector_${TIMESTAMP}.sql" || warn "PostgreSQL backup failed"
    fi
    
    # Backup env file
    if [ -f "${APP_DIR}/.env" ]; then
        cp "${APP_DIR}/.env" "${BACKUP_DIR}/env_${TIMESTAMP}"
    fi
    
    # Cleanup old backups (keep last 7)
    find "$BACKUP_DIR" -type f -mtime +7 -delete
    
    log "Backup completed"
}

# Health check
health_check() {
    log "Running health checks..."
    
    # Check if containers are running
    local front_status=$(docker compose -f "$COMPOSE_FILE" ps front 2>/dev/null | grep -c "Up" || echo "0")
    local server_status=$(docker compose -f "$COMPOSE_FILE" ps server 2>/dev/null | grep -c "Up" || echo "0")
    local db_status=$(docker compose -f "$COMPOSE_FILE" ps database 2>/dev/null | grep -c "Up" || echo "0")
    
    if [ "$front_status" -eq 1 ]; then
        log "✅ Front container is running"
    else
        warn "❌ Front container is not running"
    fi
    
    if [ "$server_status" -eq 1 ]; then
        log "✅ Server container is running"
    else
        warn "❌ Server container is not running"
    fi
    
    if [ "$db_status" -eq 1 ]; then
        log "✅ Database container is running"
    else
        warn "❌ Database container is not running"
    fi
}

# Main deployment
deploy() {
    log "Starting deployment for brand: $BRAND"
    
    cd "$APP_DIR"
    
    # Pull latest code
    log "Pulling latest code..."
    git fetch --all
    git pull origin "$(git branch --show-current)"
    
    # Backup before deployment
    backup
    
    # Pull latest images
    log "Pulling Docker images..."
    docker compose -f "$COMPOSE_FILE" pull
    
    # Deploy with zero downtime
    log "Deploying services..."
    docker compose -f "$COMPOSE_FILE" up -d
    
    # Wait for services to start
    log "Waiting for services to start..."
    sleep 30
    
    # Health check
    health_check
    
    # Cleanup old images
    log "Cleaning up old images..."
    docker image prune -f
    
    log "Deployment completed successfully! 🎉"
    
    # Show status
    echo ""
    log "Service Status:"
    docker compose -f "$COMPOSE_FILE" ps
}

# Rollback function
rollback() {
    log "Starting rollback..."
    
    # Find the most recent backup
    LATEST_MONGO=$(ls -t "${BACKUP_DIR}"/mongo_*.archive 2>/dev/null | head -n1)
    LATEST_PG=$(ls -t "${BACKUP_DIR}"/pgvector_*.sql 2>/dev/null | head -n1)
    
    if [ -z "$LATEST_MONGO" ] && [ -z "$LATEST_PG" ]; then
        error "No backups found for rollback"
    fi
    
    # Restore MongoDB
    if [ -n "$LATEST_MONGO" ]; then
        log "Restoring MongoDB from $LATEST_MONGO..."
        docker compose -f "$COMPOSE_FILE" exec -T database \
            mongorestore --archive < "$LATEST_MONGO" || warn "MongoDB restore failed"
    fi
    
    # Restore PostgreSQL
    if [ -n "$LATEST_PG" ]; then
        log "Restoring PostgreSQL from $LATEST_PG..."
        docker compose -f "$COMPOSE_FILE" exec -T pgvector \
            psql -U postgres crawlchat < "$LATEST_PG" || warn "PostgreSQL restore failed"
    fi
    
    log "Rollback completed"
}

# Show logs
show_logs() {
    docker compose -f "$COMPOSE_FILE" logs -f --tail=100
}

# Restart services
restart() {
    log "Restarting services..."
    docker compose -f "$COMPOSE_FILE" restart
    health_check
}

# Show usage
usage() {
    echo "CrawlChat VPS Deployment Script"
    echo ""
    echo "Usage: $0 [brand-name] [command]"
    echo ""
    echo "Commands:"
    echo "  (none)     - Deploy brand (default)"
    echo "  backup     - Create backup only"
    echo "  rollback   - Restore from latest backup"
    echo "  logs       - Show service logs"
    echo "  restart    - Restart all services"
    echo "  status     - Show service status"
    echo ""
    echo "Examples:"
    echo "  sudo $0              # Deploy default"
    echo "  sudo $0 acme         # Deploy ACME brand"
    echo "  sudo $0 acme backup  # Backup ACME brand"
    echo "  sudo $0 logs         # Show logs"
}

# Parse command
COMMAND=${2:-"deploy"}

case "$COMMAND" in
    deploy|"")
        deploy
        ;;
    backup)
        backup
        ;;
    rollback)
        rollback
        ;;
    logs)
        show_logs
        ;;
    restart)
        restart
        ;;
    status)
        health_check
        docker compose -f "$COMPOSE_FILE" ps
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        error "Unknown command: $COMMAND"
        usage
        exit 1
        ;;
esac
