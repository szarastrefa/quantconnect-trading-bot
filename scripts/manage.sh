#!/bin/bash

# QuantConnect Trading Bot - System Management Script
# Unified management interface for the trading bot system
# Domain: eqtrader.ddnskita.my.id

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
COMPOSE_FILE="docker-compose.yml"
PRODUCTION_COMPOSE_FILE="docker-compose.production.yml"
DOMAIN="eqtrader.ddnskita.my.id"
DDNS_UPDATE_URL="https://tunnel.hostddns.us/ddns/377b9a29c7bba5435e4b5d53e3ead4aa"

# Auto-detect environment
if [ -f "$PROJECT_DIR/$PRODUCTION_COMPOSE_FILE" ] && [ "$NODE_ENV" = "production" ]; then
    COMPOSE_FILE="$PRODUCTION_COMPOSE_FILE"
    ENVIRONMENT="production"
else
    ENVIRONMENT="development"
fi

# Helper functions
print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║      QuantConnect Trading Bot Manager        ║"
    echo "║              $ENVIRONMENT Environment                   ║"
    echo "╠══════════════════════════════════════════════╣"
    echo "║ Domain: $DOMAIN         ║"
    echo "║ Compose: $COMPOSE_FILE     ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_action() {
    echo -e "${CYAN}[ACTION]${NC} $1"
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed or not in PATH"
        exit 1
    fi
}

check_project_dir() {
    if [ ! -f "$PROJECT_DIR/$COMPOSE_FILE" ]; then
        print_error "Docker Compose file not found: $PROJECT_DIR/$COMPOSE_FILE"
        exit 1
    fi
}

update_ddns() {
    print_action "Updating DDNS record for $DOMAIN..."
    
    response=$(curl -s "$DDNS_UPDATE_URL")
    if echo "$response" | grep -q "success"; then
        print_status "✅ DDNS updated successfully"
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
    else
        print_error "❌ DDNS update failed"
        echo "$response"
        return 1
    fi
}

start_system() {
    print_action "🚀 Starting QuantConnect Trading Bot..."
    
    cd "$PROJECT_DIR"
    
    # Update DDNS first
    if [ "$ENVIRONMENT" = "production" ]; then
        update_ddns || print_warning "DDNS update failed, continuing anyway..."
    fi
    
    # Start services
    docker-compose -f "$COMPOSE_FILE" up -d
    
    print_status "✅ System started"
    
    # Wait a moment for services to initialize
    sleep 5
    
    # Show status
    show_status
}

stop_system() {
    print_action "🛑 Stopping QuantConnect Trading Bot..."
    
    cd "$PROJECT_DIR"
    docker-compose -f "$COMPOSE_FILE" down
    
    print_status "✅ System stopped"
}

restart_system() {
    print_action "🔄 Restarting QuantConnect Trading Bot..."
    
    cd "$PROJECT_DIR"
    
    # Update DDNS if production
    if [ "$ENVIRONMENT" = "production" ]; then
        update_ddns || print_warning "DDNS update failed, continuing anyway..."
    fi
    
    docker-compose -f "$COMPOSE_FILE" restart
    
    print_status "✅ System restarted"
    
    # Wait and show status
    sleep 5
    show_status
}

show_status() {
    print_action "📊 System Status"
    
    cd "$PROJECT_DIR"
    
    echo -e "${BLUE}Container Status:${NC}"
    docker-compose -f "$COMPOSE_FILE" ps
    
    echo ""
    echo -e "${BLUE}🔍 Container Health:${NC}"
    docker ps --filter "name=trading_bot" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -20
    
    echo ""
    echo -e "${BLUE}💾 Resource Usage:${NC}"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" $(docker ps --filter "name=trading_bot" -q) 2>/dev/null || echo "No containers running"
    
    echo ""
    echo -e "${BLUE}🌐 Service Endpoints:${NC}"
    if [ "$ENVIRONMENT" = "production" ]; then
        echo "  Frontend:  https://$DOMAIN"
        echo "  Backend:   https://$DOMAIN/api"
        echo "  Health:    https://$DOMAIN/health"
        echo "  WebSocket: wss://$DOMAIN/socket.io"
    else
        echo "  Frontend:  http://localhost:3000"
        echo "  Backend:   http://localhost:5000"
        echo "  Health:    http://localhost:5000/api/health"
        echo "  WebSocket: ws://localhost:5000/socket.io"
    fi
    
    echo ""
    echo -e "${BLUE}🏥 Quick Health Check:${NC}"
    check_health
}

check_health() {
    cd "$PROJECT_DIR"
    
    # Check if containers are running
    running_containers=$(docker ps --filter "name=trading_bot" --filter "status=running" | grep -c "trading_bot" || echo "0")
    total_containers=$(docker-compose -f "$COMPOSE_FILE" config --services | wc -l)
    
    if [ "$running_containers" -eq "$total_containers" ]; then
        echo -e "  ✅ All containers running ($running_containers/$total_containers)"
    else
        echo -e "  ⚠️  Some containers not running ($running_containers/$total_containers)"
    fi
    
    # Test API endpoint
    if [ "$ENVIRONMENT" = "production" ]; then
        api_url="https://$DOMAIN/health"
    else
        api_url="http://localhost:5000/api/health"
    fi
    
    if curl -f -s "$api_url" > /dev/null 2>&1; then
        echo "  ✅ API endpoint responding"
    else
        echo "  ❌ API endpoint not responding"
    fi
    
    # Check DDNS if production
    if [ "$ENVIRONMENT" = "production" ]; then
        if nslookup "$DOMAIN" > /dev/null 2>&1; then
            echo "  ✅ DNS resolution working"
        else
            echo "  ❌ DNS resolution failed"
        fi
    fi
}

show_logs() {
    local service="$1"
    local follow="$2"
    
    cd "$PROJECT_DIR"
    
    if [ -n "$service" ]; then
        print_action "📋 Showing logs for service: $service"
        if [ "$follow" = "--follow" ] || [ "$follow" = "-f" ]; then
            docker-compose -f "$COMPOSE_FILE" logs -f "$service"
        else
            docker-compose -f "$COMPOSE_FILE" logs --tail=100 "$service"
        fi
    else
        print_action "📋 Showing logs for all services"
        if [ "$follow" = "--follow" ] || [ "$follow" = "-f" ]; then
            docker-compose -f "$COMPOSE_FILE" logs -f
        else
            docker-compose -f "$COMPOSE_FILE" logs --tail=50
        fi
    fi
}

update_system() {
    print_action "🔄 Updating QuantConnect Trading Bot..."
    
    cd "$PROJECT_DIR"
    
    # Check if git repo
    if [ -d ".git" ]; then
        print_status "Pulling latest changes from repository..."
        git pull origin main || git pull origin master
    else
        print_warning "Not a git repository, skipping code update"
    fi
    
    # Rebuild and restart
    print_status "Rebuilding containers..."
    docker-compose -f "$COMPOSE_FILE" build --pull
    
    print_status "Restarting system..."
    docker-compose -f "$COMPOSE_FILE" up -d
    
    print_status "✅ System updated and restarted"
    
    # Show status
    sleep 5
    show_status
}

build_system() {
    print_action "🏗️ Building QuantConnect Trading Bot..."
    
    cd "$PROJECT_DIR"
    
    # Build all services
    docker-compose -f "$COMPOSE_FILE" build --parallel
    
    print_status "✅ Build completed"
}

deploy_system() {
    print_action "🚀 Deploying QuantConnect Trading Bot..."
    
    cd "$PROJECT_DIR"
    
    # Update DDNS
    if [ "$ENVIRONMENT" = "production" ]; then
        update_ddns || {
            print_error "DDNS update failed!"
            read -p "Continue deployment anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        }
    fi
    
    # Build and deploy
    build_system
    
    # Stop old containers
    docker-compose -f "$COMPOSE_FILE" down
    
    # Start new containers
    docker-compose -f "$COMPOSE_FILE" up -d
    
    print_status "✅ Deployment completed"
    
    # Wait and show status
    sleep 10
    show_status
}

run_health_check() {
    print_action "🔍 Running comprehensive health check..."
    
    cd "$PROJECT_DIR"
    
    if [ -f "scripts/check_system_integrity.py" ]; then
        python3 scripts/check_system_integrity.py --verbose
    else
        print_warning "System integrity checker not found, running basic checks..."
        
        echo -e "${BLUE}Basic Health Check:${NC}"
        check_health
        
        echo ""
        echo -e "${BLUE}Docker System Info:${NC}"
        docker system df
        
        echo ""
        echo -e "${BLUE}Network Status:${NC}"
        docker network ls | grep trading
        
        echo ""
        echo -e "${BLUE}Volume Status:${NC}"
        docker volume ls | grep trading
    fi
}

backup_system() {
    print_action "💾 Creating system backup..."
    
    cd "$PROJECT_DIR"
    
    if [ -f "scripts/backup_system.sh" ]; then
        bash scripts/backup_system.sh
    else
        # Simple backup
        backup_dir="backups/$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
        
        print_status "Creating database backup..."
        docker-compose -f "$COMPOSE_FILE" exec -T db pg_dump -U postgres trading_bot > "$backup_dir/database.sql" || print_warning "Database backup failed"
        
        print_status "Creating configuration backup..."
        cp .env "$backup_dir/" 2>/dev/null || print_warning "No .env file to backup"
        cp -r models "$backup_dir/" 2>/dev/null || print_warning "No models directory to backup"
        cp -r data "$backup_dir/" 2>/dev/null || print_warning "No data directory to backup"
        
        print_status "✅ Backup created at: $backup_dir"
    fi
}

cleanup_system() {
    print_action "🧹 Cleaning up system..."
    
    cd "$PROJECT_DIR"
    
    # Remove unused containers
    print_status "Removing unused containers..."
    docker container prune -f
    
    # Remove unused images
    print_status "Removing unused images..."
    docker image prune -f
    
    # Remove unused volumes (careful!)
    read -p "Remove unused volumes? This may delete data! (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker volume prune -f
    fi
    
    # Remove unused networks
    print_status "Removing unused networks..."
    docker network prune -f
    
    print_status "✅ Cleanup completed"
}

open_web_interface() {
    print_action "🌐 Opening web interface..."
    
    if [ "$ENVIRONMENT" = "production" ]; then
        url="https://$DOMAIN"
    else
        url="http://localhost:3000"
    fi
    
    print_status "Opening: $url"
    
    # Try to open in browser
    if command -v xdg-open > /dev/null; then
        xdg-open "$url"
    elif command -v open > /dev/null; then
        open "$url"
    else
        print_status "Please open: $url"
    fi
}

show_menu() {
    print_header
    echo
    echo -e "${CYAN}Available Commands:${NC}"
    echo "  1. 🚀 start              - Start the trading system"
    echo "  2. 🛑 stop               - Stop the trading system"
    echo "  3. 🔄 restart            - Restart the trading system"
    echo "  4. 📊 status             - Show system status"
    echo "  5. 📋 logs [service]     - Show logs (optionally for specific service)"
    echo "  6. 🔄 update             - Update system from repository"
    echo "  7. 🏗️ build              - Build all containers"
    echo "  8. 🚀 deploy             - Full deployment (build + start)"
    echo "  9. 🔍 health             - Run comprehensive health check"
    echo " 10. 💾 backup             - Create system backup"
    echo " 11. 🧹 cleanup            - Clean up unused Docker resources"
    echo " 12. 🌐 web               - Open web interface"
    echo " 13. 🌍 ddns-update       - Update DDNS record"
    echo " 14. ❌ help              - Show this menu"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0 start                 # Start the system"
    echo "  $0 logs api              # Show API logs"
    echo "  $0 logs --follow         # Follow all logs"
    echo "  $0 status                # Show system status"
    echo ""
}

# Main command processing
case "$1" in
    start)
        check_docker
        check_project_dir
        start_system
        ;;
    stop)
        check_docker
        check_project_dir
        stop_system
        ;;
    restart)
        check_docker
        check_project_dir
        restart_system
        ;;
    status)
        check_docker
        check_project_dir
        show_status
        ;;
    logs)
        check_docker
        check_project_dir
        show_logs "$2" "$3"
        ;;
    update)
        check_docker
        check_project_dir
        update_system
        ;;
    build)
        check_docker
        check_project_dir
        build_system
        ;;
    deploy)
        check_docker
        check_project_dir
        deploy_system
        ;;
    health)
        check_docker
        check_project_dir
        run_health_check
        ;;
    backup)
        check_docker
        check_project_dir
        backup_system
        ;;
    cleanup)
        check_docker
        cleanup_system
        ;;
    web)
        open_web_interface
        ;;
    ddns-update)
        update_ddns
        ;;
    help|--help|-h)
        show_menu
        ;;
    "")
        show_menu
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        show_menu
        exit 1
        ;;
esac