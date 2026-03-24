#!/bin/bash
# ===========================================
# CrawlChat Multi-Brand Management Script
# ===========================================
# Usage: ./brand-manager.sh <command> <brand-name>
# 
# Commands:
#   create <brand>   - Create new brand branch
#   sync <brand>     - Sync brand branch with main
#   deploy <brand>   - Deploy brand to server
#   status <brand>   - Check brand deployment status
#   list             - List all brand branches
# ===========================================

set -e

BRANDS_DIR="./config/brand"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create new brand branch
create_brand() {
    local BRAND=$1
    
    if [ -z "$BRAND" ]; then
        print_error "Brand name is required"
        echo "Usage: $0 create <brand-name>"
        exit 1
    fi
    
    local BRANCH="brand-${BRAND}"
    
    print_info "Creating brand: ${BRAND}"
    
    # Check if branch already exists
    if git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
        print_error "Branch ${BRANCH} already exists"
        exit 1
    fi
    
    # Ensure we're on main and up to date
    git checkout main
    git pull origin main
    
    # Create brand branch
    git checkout -b "${BRANCH}"
    
    # Create brand directory structure
    mkdir -p "${BRANDS_DIR}/${BRAND}"
    
    # Create brand config
    cat > "${BRANDS_DIR}/${BRAND}/config.json" << EOF
{
  "brand": {
    "name": "${BRAND}",
    "slug": "${BRAND}",
    "domain": "chat.${BRAND}.com",
    "support_email": "support@${BRAND}.com"
  },
  "appearance": {
    "primary_color": "#3B82F6",
    "secondary_color": "#60A5FA",
    "logo_url": "/assets/brand/${BRAND}/logo.svg",
    "favicon_url": "/assets/brand/${BRAND}/favicon.ico"
  },
  "features": {
    "enable_discord": false,
    "enable_slack": false,
    "enable_github": true
  }
}
EOF
    
    # Create .env file for brand
    if [ -f ".env.example" ]; then
        cp ".env.example" ".env.${BRAND}"
        print_info "Created .env.${BRAND} - Please update with brand-specific values"
    fi
    
    # Create docker-compose for brand
    if [ -f "docker/docker-compose.yml" ]; then
        cp "docker/docker-compose.yml" "docker/docker-compose.${BRAND}.yml"
        print_info "Created docker/docker-compose.${BRAND}.yml - Please update with brand-specific config"
    fi
    
    # Commit initial structure
    git add "${BRANDS_DIR}/${BRAND}" ".env.${BRAND}" "docker/docker-compose.${BRAND}.yml" 2>/dev/null || true
    git commit -m "feat(${BRAND}): initialize brand configuration" || true
    
    print_success "Brand ${BRAND} created successfully!"
    print_info "Branch: ${BRANCH}"
    print_info "Config: ${BRANDS_DIR}/${BRAND}/config.json"
    print_info "Env: .env.${BRAND}"
    print_info "Docker: docker/docker-compose.${BRAND}.yml"
    
    echo ""
    print_info "Next steps:"
    echo "  1. Update .env.${BRAND} with brand-specific environment variables"
    echo "  2. Update docker/docker-compose.${BRAND}.yml with brand-specific config"
    echo "  3. Add brand assets to front/public/brand/${BRAND}/"
    echo "  4. Push branch: git push -u origin ${BRANCH}"
}

# Sync brand branch with main
sync_brand() {
    local BRAND=$1
    
    if [ -z "$BRAND" ]; then
        print_error "Brand name is required"
        echo "Usage: $0 sync <brand-name>"
        exit 1
    fi
    
    local BRANCH="brand-${BRAND}"
    
    print_info "Syncing ${BRAND} with main..."
    
    # Fetch latest
    git fetch origin
    
    # Check if branch exists
    if ! git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
        print_error "Branch ${BRANCH} does not exist"
        exit 1
    fi
    
    # Switch to brand branch
    git checkout "${BRANCH}"
    
    # Merge main into branch
    git merge "origin/main"
    
    print_success "${BRAND} synced with main"
}

# Deploy brand
deploy_brand() {
    local BRAND=$1
    
    if [ -z "$BRAND" ]; then
        print_error "Brand name is required"
        echo "Usage: $0 deploy <brand-name>"
        exit 1
    fi
    
    local BRANCH="brand-${BRAND}"
    local COMPOSE_FILE="docker/docker-compose.${BRAND}.yml"
    
    print_info "Deploying ${BRAND}..."
    
    # Check if compose file exists
    if [ ! -f "${COMPOSE_FILE}" ]; then
        print_error "Docker compose file not found: ${COMPOSE_FILE}"
        exit 1
    fi
    
    # Pull latest images
    docker compose -f "${COMPOSE_FILE}" pull
    
    # Deploy with zero downtime
    docker compose -f "${COMPOSE_FILE}" up -d
    
    print_success "${BRAND} deployed successfully!"
    
    # Show status
    docker compose -f "${COMPOSE_FILE}" ps
}

# Check brand status
status_brand() {
    local BRAND=$1
    
    if [ -z "$BRAND" ]; then
        print_error "Brand name is required"
        echo "Usage: $0 status <brand-name>"
        exit 1
    fi
    
    local COMPOSE_FILE="docker/docker-compose.${BRAND}.yml"
    
    if [ ! -f "${COMPOSE_FILE}" ]; then
        print_error "Docker compose file not found: ${COMPOSE_FILE}"
        exit 1
    fi
    
    echo "=== ${BRAND} Status ==="
    docker compose -f "${COMPOSE_FILE}" ps
    
    echo ""
    echo "=== Recent Logs ==="
    docker compose -f "${COMPOSE_FILE}" logs --tail=20
}

# List all brand branches
list_brands() {
    print_info "Available brand branches:"
    echo ""
    
    # List local branches starting with 'brand-'
    git branch --list 'brand-*' | while read branch; do
        local name="${branch#*brand-}"
        name="${name# }"  # Remove leading space
        
        local config_file="${BRANDS_DIR}/${name}/config.json"
        local env_file=".env.${name}"
        local compose_file="docker/docker-compose.${name}.yml"
        
        echo "📦 ${name}"
        echo "   Branch: ${branch}"
        [ -f "$config_file" ] && echo "   Config: ✅ ${config_file}" || echo "   Config: ❌ Missing"
        [ -f "$env_file" ] && echo "   Env: ✅ ${env_file}" || echo "   Env: ❌ Missing"
        [ -f "$compose_file" ] && echo "   Docker: ✅ ${compose_file}" || echo "   Docker: ❌ Missing"
        echo ""
    done
}

# Show help
show_help() {
    echo "CrawlChat Multi-Brand Management Script"
    echo ""
    echo "Usage: $0 <command> [brand-name]"
    echo ""
    echo "Commands:"
    echo "  create <brand>   Create new brand branch"
    echo "  sync <brand>     Sync brand branch with main"
    echo "  deploy <brand>   Deploy brand to server"
    echo "  status <brand>   Check brand deployment status"
    echo "  list             List all brand branches"
    echo "  help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 create acme"
    echo "  $0 sync acme"
    echo "  $0 deploy acme"
    echo "  $0 status acme"
    echo "  $0 list"
}

# Main
case "$1" in
    create)
        create_brand "$2"
        ;;
    sync)
        sync_brand "$2"
        ;;
    deploy)
        deploy_brand "$2"
        ;;
    status)
        status_brand "$2"
        ;;
    list)
        list_brands
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
