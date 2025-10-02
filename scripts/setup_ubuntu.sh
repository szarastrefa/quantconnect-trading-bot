#!/bin/bash

# QuantConnect Trading Bot - LocalTunnel Setup Script
# Version: 3.0 - Zero Configuration Edition
# NO DDNS, NO SNAPD, ONLY LOCALTUNNEL

set -e

# Colors for beautiful output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="quantconnect-trading-bot"
INSTALL_DIR="/opt/$PROJECT_NAME"
LOG_FILE="/var/log/trading-bot-setup-$(date +%Y%m%d_%H%M%S).log"
VERSION="3.0-LocalTunnel-Only"

# Tunnel Configuration
TUNNEL_SUBDOMAIN="eqtrader-$(openssl rand -hex 4)"
FRONTEND_URL=""
BACKEND_URL=""
API_BASE_URL=""
WEBSOCKET_URL=""

# Generated credentials
POSTGRES_USER=""
POSTGRES_PASSWORD=""
JWT_SECRET=""
ENCRYPTION_KEY=""
SESSION_SECRET=""
REDIS_PASSWORD=""

# Installation options
VERBOSE=false
QUIET=false
FORCE_INSTALL=false
NO_AUTO_START=false

print_banner() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║          🚀 QuantConnect Trading Bot v${VERSION}          ║"
    echo "║                    LocalTunnel Zero-Config Edition              ║"
    echo "║                                                                  ║"
    echo "║  🌐 FREE Public URLs: https://eqtrader-xxxx-app.loca.lt        ║"
    echo "║  ⚡ Zero Configuration Required                                  ║"
    echo "║  🔒 HTTPS Included Automatically                                ║"
    echo "║  💰 100% FREE Forever                                          ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

print_status() {
    if [ "$QUIET" = false ]; then
        echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
    fi
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} ✅ $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} ⚠️ $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} ❌ $1" | tee -a "$LOG_FILE"
}

print_tunnel_info() {
    echo -e "${WHITE}[TUNNEL]${NC} 🌐 $1" | tee -a "$LOG_FILE"
}

print_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${PURPLE}[VERBOSE]${NC} $1" | tee -a "$LOG_FILE"
    fi
}

# Utility functions
generate_secure_password() {
    openssl rand -base64 24 | tr -d "=+/" | cut -c1-32
}

generate_jwt_secret() {
    openssl rand -hex 32
}

generate_database_user() {
    echo "trader_$(openssl rand -hex 4)"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

cleanup_system() {
    print_status "🧹 Cleaning up system for fresh installation..."
    
    # Stop any existing services
    systemctl stop quantconnect-trading-bot 2>/dev/null || true
    systemctl stop trading-bot-tunnel 2>/dev/null || true
    
    # Remove old Docker containers
    if command -v docker >/dev/null 2>&1; then
        print_verbose "Cleaning Docker containers..."
        docker ps -a --format "{{.Names}}" | grep -E "trading|quantconnect" | xargs -r docker rm -f 2>/dev/null || true
        docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "trading|quantconnect" | xargs -r docker rmi -f 2>/dev/null || true
    fi
    
    # Clean old tunnels
    pkill -f "localtunnel\\|lt --port" 2>/dev/null || true
    
    print_success "System cleanup completed"
}

check_system_requirements() {
    print_status "🔍 Checking system requirements..."
    
    # Check OS
    if ! command -v lsb_release >/dev/null 2>&1 || ! lsb_release -d | grep -qi ubuntu; then
        print_warning "This script is optimized for Ubuntu. Other distributions may work but aren't fully tested."
    fi
    
    # Check memory
    local memory_gb
    memory_gb=$(free -g | awk 'NR==2{printf "%.0f", $2}')
    if [ "$memory_gb" -lt 2 ]; then
        print_warning "System has less than 2GB RAM. Consider upgrading for better performance."
    fi
    
    # Check disk space
    local disk_space_gb
    disk_space_gb=$(df / | awk 'NR==2 {printf "%.0f", $4/1024/1024}')
    if [ "$disk_space_gb" -lt 5 ]; then
        print_error "Less than 5GB free disk space available. Installation may fail."
        if [ "$FORCE_INSTALL" = false ]; then
            exit 1
        fi
    fi
    
    print_success "System requirements check passed"
}

update_system() {
    print_status "📦 Updating system packages..."
    
    if [ "$VERBOSE" = true ]; then
        apt-get update && apt-get upgrade -y && apt-get autoremove -y
    else
        apt-get update -qq >/dev/null 2>&1
        apt-get upgrade -y -qq >/dev/null 2>&1
        apt-get autoremove -y -qq >/dev/null 2>&1
    fi
    
    print_success "System packages updated"
}

install_dependencies() {
    print_status "🔧 Installing system dependencies..."
    
    local packages=(
        curl wget git unzip software-properties-common
        apt-transport-https ca-certificates gnupg lsb-release
        jq htop nano ufw cron openssl
        build-essential python3 python3-pip
    )
    
    if [ "$VERBOSE" = true ]; then
        apt-get install -y "${packages[@]}"
    else
        apt-get install -y -qq "${packages[@]}" >/dev/null 2>&1
    fi
    
    print_success "System dependencies installed"
}

install_docker() {
    if command -v docker >/dev/null 2>&1; then
        print_verbose "Docker already installed: $(docker --version)"
        print_success "Docker already available"
        return
    fi
    
    print_status "🐳 Installing Docker..."
    
    # Remove old versions
    apt-get remove -y docker docker-engine docker.io containerd runc >/dev/null 2>&1 || true
    
    # Add Docker repository
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
    
    # Install Docker
    apt-get update -qq >/dev/null 2>&1
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Add user to docker group
    if [ "$SUDO_USER" ]; then
        usermod -aG docker "$SUDO_USER"
    fi
    
    print_success "Docker installed and configured"
}

install_docker_compose() {
    if command -v docker-compose >/dev/null 2>&1; then
        print_verbose "Docker Compose already installed: $(docker-compose --version)"
        print_success "Docker Compose already available"
        return
    fi
    
    print_status "📦 Installing Docker Compose..."
    
    # Get latest version and install
    local version
    version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
    curl -L "https://github.com/docker/compose/releases/download/${version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    print_success "Docker Compose $version installed"
}

setup_localtunnel() {
    print_status "🌐 Setting up LocalTunnel (FREE public access)..."
    
    # Install Node.js and npm if not present
    if ! command -v npm >/dev/null 2>&1; then
        print_status "Installing Node.js and npm..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash - >/dev/null 2>&1
        apt-get install -y nodejs >/dev/null 2>&1
    fi
    
    # Install LocalTunnel
    print_status "Installing LocalTunnel..."
    npm install -g localtunnel >/dev/null 2>&1
    
    # Generate unique subdomain
    TUNNEL_SUBDOMAIN="eqtrader-$(openssl rand -hex 4)"
    
    # Set tunnel URLs
    FRONTEND_URL="https://${TUNNEL_SUBDOMAIN}-app.loca.lt"
    BACKEND_URL="https://${TUNNEL_SUBDOMAIN}-api.loca.lt"
    API_BASE_URL="$BACKEND_URL/api"
    WEBSOCKET_URL="wss://${TUNNEL_SUBDOMAIN}-api.loca.lt/socket.io"
    
    print_tunnel_info "Frontend: $FRONTEND_URL"
    print_tunnel_info "Backend: $BACKEND_URL"
    print_tunnel_info "API: $API_BASE_URL"
    print_tunnel_info "WebSocket: $WEBSOCKET_URL"
    print_tunnel_info "Cost: FREE ✅"
    
    # Create LocalTunnel systemd service
    cat > /etc/systemd/system/trading-bot-tunnel.service << EOF
[Unit]
Description=QuantConnect Trading Bot LocalTunnel
After=network.target
Wants=network.target

[Service]
Type=forking
User=root
WorkingDirectory=/opt/quantconnect-trading-bot
ExecStart=/bin/bash -c 'nohup lt --port 3000 --subdomain ${TUNNEL_SUBDOMAIN}-app > /var/log/tunnel-frontend.log 2>&1 & echo \$! > /var/run/tunnel-frontend.pid; nohup lt --port 5000 --subdomain ${TUNNEL_SUBDOMAIN}-api > /var/log/tunnel-backend.log 2>&1 & echo \$! > /var/run/tunnel-backend.pid'
ExecStop=/bin/bash -c 'kill \$(cat /var/run/tunnel-frontend.pid 2>/dev/null) 2>/dev/null || true; kill \$(cat /var/run/tunnel-backend.pid 2>/dev/null) || true'
PIDFile=/var/run/tunnel-frontend.pid
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable tunnel service
    systemctl daemon-reload
    systemctl enable trading-bot-tunnel.service
    
    print_success "LocalTunnel configured successfully"
}

clone_repository() {
    print_status "📥 Cloning QuantConnect Trading Bot repository..."
    
    if [ "$FORCE_INSTALL" = true ] && [ -d "$INSTALL_DIR" ]; then
        print_warning "Force install: removing existing directory"
        rm -rf "$INSTALL_DIR"
    elif [ -d "$INSTALL_DIR" ]; then
        print_warning "Existing installation found. Backing up..."
        mv "$INSTALL_DIR" "${INSTALL_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    if [ "$VERBOSE" = true ]; then
        git clone https://github.com/szarastrefa/quantconnect-trading-bot.git "$INSTALL_DIR"
    else
        git clone https://github.com/szarastrefa/quantconnect-trading-bot.git "$INSTALL_DIR" >/dev/null 2>&1
    fi
    
    cd "$INSTALL_DIR"
    
    # Set permissions
    if [ "$SUDO_USER" ]; then
        chown -R "$SUDO_USER:$SUDO_USER" "$INSTALL_DIR" 2>/dev/null || true
    fi
    
    print_success "Repository cloned to $INSTALL_DIR"
}

generate_all_credentials() {
    print_status "🔐 Generating secure credentials..."
    
    POSTGRES_USER=$(generate_database_user)
    POSTGRES_PASSWORD=$(generate_secure_password)
    JWT_SECRET=$(generate_jwt_secret)
    ENCRYPTION_KEY=$(generate_secure_password)
    SESSION_SECRET=$(generate_secure_password)
    REDIS_PASSWORD=$(generate_secure_password)
    
    print_verbose "Generated credentials for database, JWT, encryption, and Redis"
    print_success "Secure credentials generated"
}

setup_environment() {
    print_status "⚙️ Setting up environment configuration..."
    
    cd "$INSTALL_DIR"
    
    # Generate credentials first
    generate_all_credentials
    
    # Set CORS origins based on tunnel URLs
    local cors_origins="$FRONTEND_URL,$BACKEND_URL"
    
    # Create comprehensive environment file
    cat > .env << EOF
# QuantConnect Trading Bot - Environment Configuration
# Generated on $(date)
# Tunnel Method: LocalTunnel (FREE)
# Installation Mode: Production

# Environment Configuration
NODE_ENV=production
ENVIRONMENT=production
DEBUG=false
FLASK_ENV=production
FLASK_DEBUG=false

# Tunnel Configuration
TUNNEL_TYPE=localtunnel
TUNNEL_SUBDOMAIN=$TUNNEL_SUBDOMAIN
FRONTEND_URL=$FRONTEND_URL
BACKEND_URL=$BACKEND_URL
API_BASE_URL=$API_BASE_URL
WEBSOCKET_URL=$WEBSOCKET_URL

# Database Configuration
POSTGRES_DB=quantconnect_trading
POSTGRES_USER=$POSTGRES_USER
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
DATABASE_URL=postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@db:5432/quantconnect_trading

# Redis Configuration
REDIS_PASSWORD=$REDIS_PASSWORD
REDIS_URL=redis://:$REDIS_PASSWORD@redis:6379/0

# Flask Security Configuration
SECRET_KEY=$SESSION_SECRET
JWT_SECRET_KEY=$JWT_SECRET
JWT_ACCESS_TOKEN_EXPIRES=1800
JWT_REFRESH_TOKEN_EXPIRES=2592000
ENCRYPTION_KEY=$ENCRYPTION_KEY

# API Configuration
CORS_ORIGINS=$cors_origins
SOCKETIO_CORS_ORIGINS=$cors_origins

# React App Configuration
REACT_APP_API_URL=$API_BASE_URL
REACT_APP_WS_URL=$WEBSOCKET_URL
REACT_APP_BACKEND_URL=$BACKEND_URL

# SSL Configuration (LocalTunnel provides HTTPS)
SSL_ENABLED=true
SSL_CERT_PATH=/etc/ssl/certs/trading-bot.pem
SSL_KEY_PATH=/etc/ssl/private/trading-bot.key

# QuantConnect Configuration
QC_USER_ID=
QC_API_TOKEN=
QC_ENVIRONMENT=paper-trading

# Trading Configuration
MAX_DAILY_LOSS=0.05
MAX_POSITION_SIZE=0.10
SIGNAL_CONFIDENCE_THRESHOLD=0.60
MAX_CONCURRENT_TRADES=10
TRADE_TIMEOUT_SECONDS=300

# Logging Configuration
LOG_LEVEL=INFO
LOG_FILE_PATH=/app/logs/trading_bot.log
ENABLE_JSON_LOGGING=false

# Monitoring Configuration
ENABLE_HEALTH_CHECK=true
HEALTH_CHECK_INTERVAL=30
METRICS_RETENTION_DAYS=30

# Security Configuration
RATE_LIMIT_PER_MINUTE=60
ENABLE_CORS=true
TRUSTED_HOSTS=localhost,127.0.0.1,*.loca.lt
MAX_CONTENT_LENGTH=16777216

# Data Directories
DATA_DIR=/opt/quantconnect-trading-bot/data
LOGS_DIR=/opt/quantconnect-trading-bot/logs
MODELS_DIR=/app/models/trained_models
CONFIGS_DIR=/app/models/model_configs

# Broker API Keys - CONFIGURE THESE FOR YOUR BROKERS
# ============================================================================

# Cryptocurrency Exchanges
BINANCE_API_KEY=YOUR_BINANCE_API_KEY
BINANCE_SECRET_KEY=YOUR_BINANCE_SECRET_KEY
BINANCE_TESTNET=false

KRAKEN_API_KEY=YOUR_KRAKEN_API_KEY
KRAKEN_SECRET_KEY=YOUR_KRAKEN_SECRET_KEY

COINBASE_API_KEY=YOUR_COINBASE_API_KEY
COINBASE_SECRET_KEY=YOUR_COINBASE_SECRET_KEY
COINBASE_PASSPHRASE=YOUR_COINBASE_PASSPHRASE
COINBASE_SANDBOX=false

# Forex/CFD Brokers
XTB_USER_ID=YOUR_XTB_USER_ID
XTB_PASSWORD=YOUR_XTB_PASSWORD
XTB_DEMO=false

IG_API_KEY=YOUR_IG_API_KEY
IG_USERNAME=YOUR_IG_USERNAME
IG_PASSWORD=YOUR_IG_PASSWORD
IG_DEMO=false

# Interactive Brokers (Optional)
IB_HOST=127.0.0.1
IB_PORT=7497
IB_CLIENT_ID=1

# Backup Configuration
BACKUP_ENABLED=true
BACKUP_INTERVAL=86400
BACKUP_RETENTION_DAYS=30
EOF
    
    # Secure the environment file
    chmod 600 .env
    
    print_success "Environment configuration created"
    
    if [ "$VERBOSE" = true ]; then
        print_verbose "Environment file: $INSTALL_DIR/.env"
        print_verbose "Generated $(wc -l < .env) configuration lines"
    fi
}

setup_firewall() {
    print_status "🛡️ Configuring firewall..."
    
    # Reset and configure UFW
    ufw --force reset >/dev/null 2>&1
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH
    ufw allow ssh
    
    # Allow HTTP and HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Allow application ports
    ufw allow 3000/tcp  # Frontend
    ufw allow 5000/tcp  # Backend
    
    # Enable firewall
    ufw --force enable >/dev/null 2>&1
    
    print_success "Firewall configured"
}

create_systemd_service() {
    print_status "⚙️ Creating systemd service..."
    
    cat > /etc/systemd/system/quantconnect-trading-bot.service << EOF
[Unit]
Description=QuantConnect Trading Bot with LocalTunnel
Documentation=https://github.com/szarastrefa/quantconnect-trading-bot
Requires=docker.service trading-bot-tunnel.service
After=docker.service network.target trading-bot-tunnel.service

[Service]
Type=oneshot
RemainAfterExit=true
WorkingDirectory=$INSTALL_DIR
ExecStartPre=-/usr/local/bin/docker-compose -f docker-compose.production.yml down
ExecStart=/usr/local/bin/docker-compose -f docker-compose.production.yml up -d
ExecStop=/usr/local/bin/docker-compose -f docker-compose.production.yml down
ExecReload=/usr/local/bin/docker-compose -f docker-compose.production.yml restart
TimeoutStartSec=300
TimeoutStopSec=120
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable service
    systemctl daemon-reload
    systemctl enable quantconnect-trading-bot.service
    
    print_success "Systemd service created and enabled"
}

create_management_script() {
    print_status "🛠️ Setting up system management..."
    
    # Create comprehensive management script
    cat > /usr/local/bin/trading-bot << 'EOF'
#!/bin/bash
# QuantConnect Trading Bot Management Script

INSTALL_DIR="/opt/quantconnect-trading-bot"
COMPOSE_FILE="docker-compose.production.yml"

cd "$INSTALL_DIR" 2>/dev/null || {
    echo "❌ Installation directory not found: $INSTALL_DIR"
    exit 1
}

case "$1" in
    start)
        echo "🚀 Starting QuantConnect Trading Bot..."
        systemctl start trading-bot-tunnel
        docker-compose -f "$COMPOSE_FILE" up -d
        echo "✅ System started"
        echo ""
        echo "🌐 Access URLs:"
        if [ -f .env ]; then
            grep -E "FRONTEND_URL|BACKEND_URL" .env | sed 's/^/   /'
        fi
        ;;
    stop)
        echo "⏹️ Stopping QuantConnect Trading Bot..."
        docker-compose -f "$COMPOSE_FILE" down
        systemctl stop trading-bot-tunnel
        echo "✅ System stopped"
        ;;
    restart)
        echo "🔄 Restarting QuantConnect Trading Bot..."
        systemctl restart trading-bot-tunnel
        docker-compose -f "$COMPOSE_FILE" restart
        echo "✅ System restarted"
        ;;
    status)
        echo "📊 System Status:"
        echo ""
        echo "🐳 Docker Containers:"
        docker-compose -f "$COMPOSE_FILE" ps
        echo ""
        echo "🌐 Tunnel Status:"
        systemctl status trading-bot-tunnel --no-pager -l
        ;;
    logs)
        echo "📋 System Logs:"
        docker-compose -f "$COMPOSE_FILE" logs -f --tail=100
        ;;
    tunnel-logs)
        echo "🌐 Tunnel Logs:"
        echo "Frontend tunnel:"
        tail -20 /var/log/tunnel-frontend.log 2>/dev/null || echo "No frontend tunnel logs"
        echo ""
        echo "Backend tunnel:"
        tail -20 /var/log/tunnel-backend.log 2>/dev/null || echo "No backend tunnel logs"
        ;;
    urls)
        echo "🌐 Access URLs:"
        if [ -f .env ]; then
            grep -E "FRONTEND_URL|BACKEND_URL|API_BASE_URL|WEBSOCKET_URL" .env
        else
            echo "❌ Environment file not found"
        fi
        ;;
    health)
        echo "🏥 Health Check:"
        curl -f -s http://localhost:5000/api/health && echo "✅ API healthy" || echo "❌ API not responding"
        ;;
    update)
        echo "⬇️ Updating system..."
        git pull origin main
        docker-compose -f "$COMPOSE_FILE" build --no-cache
        docker-compose -f "$COMPOSE_FILE" up -d
        echo "✅ System updated"
        ;;
    backup)
        echo "💾 Creating backup..."
        tar -czf "/tmp/trading-bot-backup-$(date +%Y%m%d_%H%M%S).tar.gz" "$INSTALL_DIR"
        echo "✅ Backup created in /tmp/"
        ;;
    *)
        echo "QuantConnect Trading Bot Management"
        echo ""
        echo "Usage: $0 {command}"
        echo ""
        echo "Commands:"
        echo "  start         🚀 Start the trading system"
        echo "  stop          ⏹️ Stop the trading system"
        echo "  restart       🔄 Restart the trading system"
        echo "  status        📊 Show system status"
        echo "  logs          📋 Show system logs"
        echo "  tunnel-logs   🌐 Show tunnel logs"
        echo "  urls          🌐 Show access URLs"
        echo "  health        🏥 Check system health"
        echo "  update        ⬇️ Update from repository"
        echo "  backup        💾 Create system backup"
        echo ""
        exit 1
        ;;
esac
EOF
    
    chmod +x /usr/local/bin/trading-bot
    
    print_success "Management script created (use 'trading-bot' command globally)"
}

validate_environment() {
    print_status "✅ Validating environment configuration..."
    
    cd "$INSTALL_DIR"
    
    # Test docker-compose configuration
    if docker-compose -f "docker-compose.production.yml" config >/dev/null 2>&1; then
        print_success "Docker Compose configuration valid"
    else
        print_error "Invalid Docker Compose configuration"
        if [ "$VERBOSE" = true ]; then
            docker-compose -f "docker-compose.production.yml" config 2>&1
        fi
        exit 1
    fi
    
    # Check .env file
    if [ -f .env ] && grep -q "POSTGRES_PASSWORD" .env; then
        print_success "Environment file format valid"
    else
        print_error "Environment file missing or invalid"
        exit 1
    fi
}

build_and_start_system() {
    if [ "$NO_AUTO_START" = true ]; then
        print_warning "System build and start skipped (--no-auto-start specified)"
        return
    fi
    
    print_status "🚀 Building and starting the system..."
    
    cd "$INSTALL_DIR"
    validate_environment
    
    # Build images
    print_status "Building Docker images..."
    if [ "$VERBOSE" = true ]; then
        docker-compose -f "docker-compose.production.yml" build --parallel
    else
        docker-compose -f "docker-compose.production.yml" build --parallel >/dev/null 2>&1
    fi
    
    # Start tunnel service
    print_status "Starting LocalTunnel..."
    systemctl start trading-bot-tunnel
    
    # Start services
    print_status "Starting application services..."
    docker-compose -f "docker-compose.production.yml" up -d
    
    # Wait for services
    print_status "Waiting for services to start..."
    sleep 45
    
    check_service_health
    print_success "System built and started successfully"
}

check_service_health() {
    print_status "🏥 Checking service health..."
    
    local running_containers
    running_containers=$(docker ps --format "{{.Names}}" | grep -E "trading|quantconnect" | wc -l)
    
    if [ "$running_containers" -ge 3 ]; then
        print_success "Services are running ($running_containers containers)"
    else
        print_warning "Some services may not be running ($running_containers containers)"
    fi
    
    # Test API endpoint
    sleep 10
    if curl -f -s http://localhost:5000/api/health >/dev/null 2>&1; then
        print_success "API is responding"
    else
        print_warning "API may not be ready yet (services are still starting)"
    fi
    
    # Check tunnel status
    if systemctl is-active --quiet trading-bot-tunnel; then
        print_success "LocalTunnel service is running"
    else
        print_warning "LocalTunnel service may not be running"
    fi
}

display_installation_summary() {
    echo ""
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                 🎉 INSTALLATION COMPLETED!                      ║"
    echo "║              QuantConnect Trading Bot v$VERSION                      ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    echo -e "${BLUE}🌐 Access Information:${NC}"
    echo "   🌐 Mode: Public Access (LocalTunnel)"
    echo "   🌐 Frontend: $FRONTEND_URL"
    echo "   📊 Backend: $BACKEND_URL"
    echo "   📈 API: $API_BASE_URL"
    echo "   🔌 WebSocket: $WEBSOCKET_URL"
    echo "   📁 Install Path: $INSTALL_DIR"
    echo ""
    
    echo -e "${YELLOW}🔐 GENERATED CREDENTIALS (SAVE THESE!):${NC}"
    echo "   ├─ Database User: $POSTGRES_USER"
    echo "   ├─ Database Password: $POSTGRES_PASSWORD"
    echo "   ├─ JWT Secret: $JWT_SECRET"
    echo "   ├─ Encryption Key: $ENCRYPTION_KEY"
    echo "   ├─ Session Secret: $SESSION_SECRET"
    echo "   └─ Redis Password: $REDIS_PASSWORD"
    echo ""
    
    echo -e "${CYAN}🛠️ MANAGEMENT COMMANDS:${NC}"
    echo "   ├─ Start system: trading-bot start"
    echo "   ├─ Stop system: trading-bot stop"
    echo "   ├─ View status: trading-bot status"
    echo "   ├─ View logs: trading-bot logs"
    echo "   ├─ Show URLs: trading-bot urls"
    echo "   ├─ Health check: trading-bot health"
    echo "   ├─ Update system: trading-bot update"
    echo "   └─ Create backup: trading-bot backup"
    echo ""
    
    echo -e "${PURPLE}📋 NEXT STEPS:${NC}"
    echo "   1. 🔧 Configure broker API keys:"
    echo "      nano $INSTALL_DIR/.env"
    echo ""
    echo "   2. 🌐 Access the web interface:"
    echo "      $FRONTEND_URL"
    echo ""
    echo "   3. 📈 Upload ML models and begin trading!"
    echo ""
    
    echo -e "${WHITE}🆓 LocalTunnel Benefits:${NC}"
    echo "   • 💰 Completely FREE"
    echo "   • ⚡ Instant setup (no tokens required)"
    echo "   • 🔒 HTTPS included automatically"
    echo "   • 🌍 Works globally"
    echo "   • 🔄 Auto-reconnects if needed"
    echo ""
    
    echo -e "${GREEN}🎊 Installation Features:${NC}"
    echo "   ├─ Tunnel Method: LOCALTUNNEL ✅"
    echo "   ├─ SSL/HTTPS: ✅ Enabled (via LocalTunnel)"
    echo "   ├─ Docker: ✅ Configured"
    echo "   ├─ Firewall: ✅ Configured"
    echo "   ├─ Auto-Start: ✅ Enabled"
    echo "   └─ Management: ✅ Ready (trading-bot command)"
    echo ""
    
    echo -e "${RED}⚠️ SECURITY REMINDERS:${NC}"
    echo "   • 💾 Save credentials in password manager"
    echo "   • 🔑 Configure broker API keys before trading"
    echo "   • 🧪 Use demo accounts for testing"
    echo "   • 📊 Monitor logs: trading-bot logs"
    echo ""
    
    echo -e "${GREEN}✅ QuantConnect Trading Bot is ready!${NC}"
    echo ""
    echo "🌐 Your trading bot is now accessible worldwide!"
    echo "🎯 Access URL: $FRONTEND_URL"
    echo ""
}

show_help() {
    echo "QuantConnect Trading Bot - LocalTunnel Setup Script v$VERSION"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "🔧 Installation Options:"
    echo "  --force-install         Remove existing installation"
    echo "  --no-auto-start         Don't start services"
    echo "  --verbose               Detailed output"
    echo "  --quiet                 Minimal output"
    echo ""
    echo "📋 Examples:"
    echo "  $0                      # Standard LocalTunnel setup"
    echo "  $0 --force-install      # Clean installation"
    echo "  $0 --verbose            # Detailed installation"
    echo ""
    echo "📚 Documentation: https://github.com/szarastrefa/quantconnect-trading-bot"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force-install)
            FORCE_INSTALL=true
            shift
            ;;
        --no-auto-start)
            NO_AUTO_START=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --quiet)
            QUIET=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo ""
            echo "Use --help to see available options"
            exit 1
            ;;
    esac
done

# Main installation flow
main() {
    print_banner
    
    # Create log file
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    
    print_status "🚀 Starting QuantConnect Trading Bot installation..."
    print_status "📅 Installation started: $(date)"
    print_status "🌐 Tunnel method: LocalTunnel (FREE)"
    print_verbose "Installation mode: Production with LocalTunnel"
    
    # System checks
    check_root
    
    # System preparation
    cleanup_system
    check_system_requirements
    update_system
    install_dependencies
    install_docker
    install_docker_compose
    
    # Repository and configuration
    clone_repository
    
    # Tunnel setup
    setup_localtunnel
    
    # Environment configuration
    setup_environment
    
    # System setup
    setup_firewall
    create_systemd_service
    create_management_script
    
    # Build and start system
    build_and_start_system
    
    # Final summary
    display_installation_summary
}

# Run main installation
main "$@"