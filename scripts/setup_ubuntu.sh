#!/bin/bash

# QuantConnect Trading Bot - Ubuntu Setup Script
# Automatyczna instalacja i konfiguracja systemu z obsługą DDNS
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
DOMAIN="eqtrader.ddnskita.my.id"
DDNS_UPDATE_URL="https://tunnel.hostddns.us/ddns/377b9a29c7bba5435e4b5d53e3ead4aa"
PROJECT_NAME="quantconnect-trading-bot"
INSTALL_DIR="/opt/$PROJECT_NAME"
LOG_FILE="/var/log/trading-bot-setup.log"

# Generated credentials (will be set during installation)
POSTGRES_USER=""
POSTGRES_PASSWORD=""
JWT_SECRET=""
ENCRYPTION_KEY=""
SESSION_SECRET=""
REDIS_PASSWORD=""

# Default options
PRODUCTION_MODE=true
INSTALL_SSL=false
SKIP_DEPENDENCIES=false
SKIP_DDNS_ERROR=false
SKIP_SSL=false
SKIP_FIREWALL=false
SKIP_DOCKER_CHECK=false
SKIP_SYSTEM_UPDATE=false
SKIP_NGINX=false
SKIP_POSTGRES=false
SKIP_REDIS=false
SKIP_BROKER_SETUP=false
SKIP_ML_SETUP=false
FORCE_INSTALL=false
DEV_MODE=false
MINIMAL=false
INTERACTIVE=false
VERBOSE=false
QUIET=false
NO_AUTO_START=false
CUSTOM_PORT=""
DATA_DIR=""
CONFIG_FILE=""

print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                 QuantConnect Trading Bot                         ║"
    echo "║                    Ubuntu Setup Script v2.0                     ║"
    echo "║                                                                  ║"
    echo "║  Domain: eqtrader.ddnskita.my.id                                ║"
    echo "║  DDNS: hostddns.us tunnel integration                           ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_status() {
    if [ "$QUIET" = false ]; then
        echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
    fi
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

print_skip() {
    echo -e "${CYAN}[SKIP]${NC} ⏭️ $1" | tee -a "$LOG_FILE"
}

print_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${PURPLE}[VERBOSE]${NC} $1" | tee -a "$LOG_FILE"
    fi
}

generate_secure_password() {
    # Generate 32-character alphanumeric password (no special chars that could cause issues)
    openssl rand -base64 24 | tr -d "=+/" | cut -c1-32
}

generate_jwt_secret() {
    # Generate 64-character hex JWT secret
    openssl rand -hex 32
}

generate_database_user() {
    # Generate unique database username
    echo "trader_$(openssl rand -hex 4)"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_system_requirements() {
    if [ "$SKIP_SYSTEM_UPDATE" = true ]; then
        print_skip "System requirements check (--skip-system-update)"
        return
    fi
    
    print_status "Checking system requirements..."
    
    # Check Ubuntu version
    if ! grep -q "Ubuntu" /etc/os-release; then
        print_warning "This script is designed for Ubuntu. Other distributions may not be supported."
        if [ "$INTERACTIVE" = true ]; then
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    fi
    
    # Check available memory
    MEMORY_GB=$(free -g | awk 'NR==2{printf "%.0f", $2}')
    if [ "$MEMORY_GB" -lt 4 ]; then
        print_warning "System has less than 4GB RAM. Performance may be affected."
    fi
    
    # Check available disk space
    DISK_SPACE_GB=$(df / | awk 'NR==2 {printf "%.0f", $4/1024/1024}')
    if [ "$DISK_SPACE_GB" -lt 10 ]; then
        print_error "Less than 10GB free disk space available. Installation may fail."
        if [ "$FORCE_INSTALL" = false ]; then
            exit 1
        fi
    fi
    
    print_status "✅ System requirements check passed"
}

update_system() {
    if [ "$SKIP_SYSTEM_UPDATE" = true ]; then
        print_skip "System update (--skip-system-update)"
        return
    fi
    
    print_status "Updating system packages..."
    if [ "$VERBOSE" = true ]; then
        apt-get update
        apt-get upgrade -y
        apt-get autoremove -y
    else
        apt-get update -qq > /dev/null 2>&1
        apt-get upgrade -y -qq > /dev/null 2>&1
        apt-get autoremove -y -qq > /dev/null 2>&1
    fi
    print_status "✅ System packages updated"
}

install_dependencies() {
    if [ "$SKIP_DEPENDENCIES" = true ]; then
        print_skip "Dependencies installation (--skip-deps)"
        return
    fi
    
    print_status "Installing system dependencies..."
    
    # Essential packages
    if [ "$VERBOSE" = true ]; then
        apt-get install -y \
            curl wget git unzip software-properties-common \
            apt-transport-https ca-certificates gnupg lsb-release \
            jq htop nano ufw cron openssl
    else
        apt-get install -y -qq \
            curl wget git unzip software-properties-common \
            apt-transport-https ca-certificates gnupg lsb-release \
            jq htop nano ufw cron openssl \
            > /dev/null 2>&1
    fi
    
    print_status "✅ System dependencies installed"
}

install_docker() {
    if [ "$SKIP_DOCKER_CHECK" = true ]; then
        print_skip "Docker installation (--skip-docker-check)"
        return
    fi
    
    print_status "Installing Docker..."
    
    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        print_verbose "Docker already installed, checking version..."
        docker --version
        print_status "✅ Docker already installed"
        return
    fi
    
    # Remove old versions
    apt-get remove -y docker docker-engine docker.io containerd runc > /dev/null 2>&1 || true
    
    # Add Docker official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
    
    # Install Docker
    apt-get update -qq > /dev/null 2>&1
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Add current user to docker group (if not root)
    if [ "$SUDO_USER" ]; then
        usermod -aG docker "$SUDO_USER"
    fi
    
    print_status "✅ Docker installed and configured"
}

install_docker_compose() {
    print_status "Installing Docker Compose..."
    
    # Check if already installed
    if command -v docker-compose &> /dev/null; then
        print_verbose "Docker Compose already installed"
        docker-compose --version
        print_status "✅ Docker Compose already available"
        return
    fi
    
    # Get latest version
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
    
    # Download and install
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Create symlink
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    print_status "✅ Docker Compose ${DOCKER_COMPOSE_VERSION} installed"
}

handle_ddns_response() {
    local response="$1"
    
    # Handle all success cases including Indonesian responses
    if echo "$response" | grep -qi "success\|berhasil\|successfully update"; then
        print_status "✅ DDNS updated successfully"
        return 0
    elif echo "$response" | grep -qi "masih sama\|same address\|no change"; then
        print_status "✅ DDNS already up-to-date (IP unchanged)"
        return 0
    elif echo "$response" | grep -qi "update.*to.*[0-9]"; then
        print_status "✅ DDNS record updated"
        return 0
    else
        # Unknown response
        if [ "$SKIP_DDNS_ERROR" = true ]; then
            print_warning "⚠️ DDNS error ignored (--skip-ddns-error specified)"
            print_verbose "DDNS Response: $response"
            return 0
        else
            print_error "❌ DDNS update failed"
            echo "Response: $response"
            return 1
        fi
    fi
}

setup_ddns() {
    print_status "Setting up DDNS integration..."
    
    # Update DDNS record
    print_status "Updating DDNS record for $DOMAIN..."
    DDNS_RESPONSE=$(curl -s "$DDNS_UPDATE_URL" 2>/dev/null || echo "Connection failed")
    
    if handle_ddns_response "$DDNS_RESPONSE"; then
        # Display response for debugging
        echo "$DDNS_RESPONSE" | jq '.' 2>/dev/null || echo "$DDNS_RESPONSE"
        
        # Get current IP
        CURRENT_IP=$(echo "$DDNS_RESPONSE" | jq -r '.message' 2>/dev/null | grep -oE '([0-9]{1,3}\\.){3}[0-9]{1,3}' || curl -s ifconfig.me 2>/dev/null || echo "unknown")
        if [ "$CURRENT_IP" != "unknown" ]; then
            print_status "Current IP: $CURRENT_IP"
        fi
        
        # Setup automatic updates
        setup_ddns_cron
    else
        if [ "$SKIP_DDNS_ERROR" = false ]; then
            print_error "DDNS setup failed. Use --skip-ddns-error to continue anyway."
            exit 1
        fi
    fi
}

setup_ddns_cron() {
    print_status "Setting up automatic DDNS updates..."
    
    # Create DDNS update script
    cat > /usr/local/bin/update-ddns.sh << EOF
#!/bin/bash
# Automatic DDNS update script for QuantConnect Trading Bot
RESPONSE=\$(curl -s "$DDNS_UPDATE_URL" 2>/dev/null || echo "failed")
if echo "\$RESPONSE" | grep -qi "success\|berhasil\|masih sama\|update"; then
    logger "DDNS check completed for $DOMAIN"
else
    logger "DDNS update may have failed for $DOMAIN: \$RESPONSE"
fi
EOF
    
    chmod +x /usr/local/bin/update-ddns.sh
    
    # Add to crontab (every 5 minutes)
    (crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/update-ddns.sh >/dev/null 2>&1") | crontab -
    
    print_status "✅ DDNS auto-update configured (every 5 minutes)"
}

clone_repository() {
    print_status "Cloning QuantConnect Trading Bot repository..."
    
    # Force install removes existing directory
    if [ "$FORCE_INSTALL" = true ] && [ -d "$INSTALL_DIR" ]; then
        print_warning "Force install: removing existing directory"
        rm -rf "$INSTALL_DIR"
    elif [ -d "$INSTALL_DIR" ]; then
        print_warning "Existing installation found. Backing up..."
        mv "$INSTALL_DIR" "${INSTALL_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Clone repository
    if [ "$VERBOSE" = true ]; then
        git clone https://github.com/szarastrefa/quantconnect-trading-bot.git "$INSTALL_DIR"
    else
        git clone https://github.com/szarastrefa/quantconnect-trading-bot.git "$INSTALL_DIR" > /dev/null 2>&1
    fi
    
    cd "$INSTALL_DIR"
    
    # Set permissions
    if [ "$SUDO_USER" ]; then
        chown -R "$SUDO_USER:$SUDO_USER" "$INSTALL_DIR" 2>/dev/null || true
    fi
    
    print_status "✅ Repository cloned to $INSTALL_DIR"
}

generate_all_credentials() {
    print_status "Generating secure credentials..."
    
    # Generate all credentials
    POSTGRES_USER=$(generate_database_user)
    POSTGRES_PASSWORD=$(generate_secure_password)
    JWT_SECRET=$(generate_jwt_secret)
    ENCRYPTION_KEY=$(generate_secure_password)
    SESSION_SECRET=$(generate_secure_password)
    REDIS_PASSWORD=$(generate_secure_password)
    
    print_verbose "Generated credentials for database, JWT, encryption, and Redis"
    print_status "✅ Secure credentials generated"
}

setup_environment() {
    print_status "Setting up environment configuration..."
    
    cd "$INSTALL_DIR"
    
    # Generate credentials first
    generate_all_credentials
    
    # Determine URLs based on dev mode
    if [ "$DEV_MODE" = true ]; then
        API_BASE_URL="http://localhost:5000/api"
        FRONTEND_URL="http://localhost:3000"
        WEBSOCKET_URL="ws://localhost:5000/socket.io"
        CORS_ORIGINS="http://localhost:3000,http://localhost:5000"
        SSL_ENABLED_VAL="false"
    else
        API_BASE_URL="https://$DOMAIN/api"
        FRONTEND_URL="https://$DOMAIN"
        WEBSOCKET_URL="wss://$DOMAIN/socket.io"
        CORS_ORIGINS="https://$DOMAIN"
        SSL_ENABLED_VAL="true"
    fi
    
    # Create production environment file
    cat > .env << EOF
# QuantConnect Trading Bot - Environment Configuration
# Generated on $(date)
# Installation Mode: $([ "$DEV_MODE" = true ] && echo "Development" || echo "Production")

# Environment Configuration
NODE_ENV=$([ "$DEV_MODE" = true ] && echo "development" || echo "production")
ENVIRONMENT=$([ "$DEV_MODE" = true ] && echo "development" || echo "production")
DEBUG=$([ "$DEV_MODE" = true ] && echo "true" || echo "false")
FLASK_ENV=$([ "$DEV_MODE" = true ] && echo "development" || echo "production")
FLASK_DEBUG=$([ "$DEV_MODE" = true ] && echo "true" || echo "false")

# Domain and DDNS Configuration
DOMAIN=$DOMAIN
DDNS_UPDATE_URL=$DDNS_UPDATE_URL
DDNS_CHECK_INTERVAL=300
DDNS_UPDATE_INTERVAL=300
AUTO_UPDATE_DDNS=true

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
API_BASE_URL=$API_BASE_URL
FRONTEND_URL=$FRONTEND_URL
WEBSOCKET_URL=$WEBSOCKET_URL
CORS_ORIGINS=$CORS_ORIGINS
SOCKETIO_CORS_ORIGINS=$CORS_ORIGINS

# React App Configuration
REACT_APP_API_URL=$API_BASE_URL
REACT_APP_WS_URL=$WEBSOCKET_URL
REACT_APP_DOMAIN=$DOMAIN

# SSL Configuration
SSL_ENABLED=$SSL_ENABLED_VAL
SSL_CERT_PATH=/etc/letsencrypt/live/$DOMAIN/fullchain.pem
SSL_KEY_PATH=/etc/letsencrypt/live/$DOMAIN/privkey.pem

# QuantConnect Configuration (Configure these)
QC_USER_ID=
QC_API_TOKEN=
QC_ENVIRONMENT=live-trading

# Trading Configuration
MAX_DAILY_LOSS=0.05
MAX_POSITION_SIZE=0.10
SIGNAL_CONFIDENCE_THRESHOLD=0.60
MAX_CONCURRENT_TRADES=10
TRADE_TIMEOUT_SECONDS=300

# Logging Configuration
LOG_LEVEL=$([ "$DEV_MODE" = true ] && echo "DEBUG" || echo "INFO")
LOG_FILE_PATH=/app/logs/trading_bot.log
ENABLE_JSON_LOGGING=false

# Monitoring Configuration
ENABLE_HEALTH_CHECK=true
HEALTH_CHECK_INTERVAL=30
METRICS_RETENTION_DAYS=30

# Security Configuration
RATE_LIMIT_PER_MINUTE=$([ "$DEV_MODE" = true ] && echo "1000" || echo "60")
ENABLE_CORS=true
TRUSTED_HOSTS=$DOMAIN,localhost
MAX_CONTENT_LENGTH=16777216

# Data Directories
DATA_DIR=/opt/quantconnect-trading-bot/data
LOGS_DIR=/opt/quantconnect-trading-bot/logs
MODELS_DIR=/app/models/trained_models
CONFIGS_DIR=/app/models/model_configs

# Broker API Keys - CONFIGURE THESE FOR YOUR BROKERS
# ============================================================================

# Forex/CFD Brokers
XM_LOGIN=YOUR_XM_LOGIN_NUMBER
XM_PASSWORD=YOUR_XM_PASSWORD
XM_SERVER=XM-Real

XTB_USER_ID=YOUR_XTB_USER_ID
XTB_PASSWORD=YOUR_XTB_PASSWORD
XTB_DEMO=$([ "$DEV_MODE" = true ] && echo "true" || echo "false")

IC_MARKETS_API_KEY=YOUR_IC_MARKETS_API_KEY
IC_MARKETS_TOKEN=YOUR_IC_MARKETS_TOKEN
IC_MARKETS_DEMO=$([ "$DEV_MODE" = true ] && echo "true" || echo "false")

IG_API_KEY=YOUR_IG_API_KEY
IG_USERNAME=YOUR_IG_USERNAME
IG_PASSWORD=YOUR_IG_PASSWORD
IG_DEMO=$([ "$DEV_MODE" = true ] && echo "true" || echo "false")

ADMIRAL_LOGIN=YOUR_ADMIRAL_LOGIN
ADMIRAL_PASSWORD=YOUR_ADMIRAL_PASSWORD
ADMIRAL_SERVER=AdmiralMarkets-$([ "$DEV_MODE" = true ] && echo "Demo" || echo "Live")

ROBOFOREX_LOGIN=YOUR_ROBOFOREX_LOGIN
ROBOFOREX_PASSWORD=YOUR_ROBOFOREX_PASSWORD
ROBOFOREX_SERVER=RoboForex-$([ "$DEV_MODE" = true ] && echo "Demo" || echo "Pro")

FBS_LOGIN=YOUR_FBS_LOGIN
FBS_PASSWORD=YOUR_FBS_PASSWORD
FBS_SERVER=FBS-$([ "$DEV_MODE" = true ] && echo "Demo" || echo "Real")

INSTAFOREX_LOGIN=YOUR_INSTAFOREX_LOGIN
INSTAFOREX_PASSWORD=YOUR_INSTAFOREX_PASSWORD
INSTAFOREX_SERVER=InstaForex-Server

PLUS500_USERNAME=YOUR_PLUS500_USERNAME
PLUS500_PASSWORD=YOUR_PLUS500_PASSWORD

SABIOTRADE_API_KEY=YOUR_SABIOTRADE_API_KEY
SABIOTRADE_USERNAME=YOUR_SABIOTRADE_USERNAME
SABIOTRADE_PASSWORD=YOUR_SABIOTRADE_PASSWORD

# Cryptocurrency Exchanges
BINANCE_API_KEY=YOUR_BINANCE_API_KEY
BINANCE_SECRET_KEY=YOUR_BINANCE_SECRET_KEY
BINANCE_TESTNET=$([ "$DEV_MODE" = true ] && echo "true" || echo "false")

KRAKEN_API_KEY=YOUR_KRAKEN_API_KEY
KRAKEN_SECRET_KEY=YOUR_KRAKEN_SECRET_KEY

COINBASE_API_KEY=YOUR_COINBASE_API_KEY
COINBASE_SECRET_KEY=YOUR_COINBASE_SECRET_KEY
COINBASE_PASSPHRASE=YOUR_COINBASE_PASSPHRASE
COINBASE_SANDBOX=$([ "$DEV_MODE" = true ] && echo "true" || echo "false")

BYBIT_API_KEY=YOUR_BYBIT_API_KEY
BYBIT_SECRET_KEY=YOUR_BYBIT_SECRET_KEY
BYBIT_TESTNET=$([ "$DEV_MODE" = true ] && echo "true" || echo "false")

KUCOIN_API_KEY=YOUR_KUCOIN_API_KEY
KUCOIN_SECRET_KEY=YOUR_KUCOIN_SECRET_KEY
KUCOIN_PASSPHRASE=YOUR_KUCOIN_PASSPHRASE
KUCOIN_SANDBOX=$([ "$DEV_MODE" = true ] && echo "true" || echo "false")

OKX_API_KEY=YOUR_OKX_API_KEY
OKX_SECRET_KEY=YOUR_OKX_SECRET_KEY
OKX_PASSPHRASE=YOUR_OKX_PASSPHRASE
OKX_DEMO=$([ "$DEV_MODE" = true ] && echo "true" || echo "false")

BITFINEX_API_KEY=YOUR_BITFINEX_API_KEY
BITFINEX_SECRET_KEY=YOUR_BITFINEX_SECRET_KEY

GEMINI_API_KEY=YOUR_GEMINI_API_KEY
GEMINI_SECRET_KEY=YOUR_GEMINI_SECRET_KEY
GEMINI_SANDBOX=$([ "$DEV_MODE" = true ] && echo "true" || echo "false")

HUOBI_API_KEY=YOUR_HUOBI_API_KEY
HUOBI_SECRET_KEY=YOUR_HUOBI_SECRET_KEY

BITTREX_API_KEY=YOUR_BITTREX_API_KEY
BITTREX_SECRET_KEY=YOUR_BITTREX_SECRET_KEY

BITSTAMP_API_KEY=YOUR_BITSTAMP_API_KEY
BITSTAMP_SECRET_KEY=YOUR_BITSTAMP_SECRET_KEY
BITSTAMP_UID=YOUR_BITSTAMP_UID

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
    
    print_status "✅ Environment configuration created"
    
    if [ "$VERBOSE" = true ]; then
        print_verbose "Environment file created at: $INSTALL_DIR/.env"
        print_verbose "Generated $(wc -l < .env) configuration lines"
    fi
}

install_ssl_certificates() {
    if [ "$INSTALL_SSL" = false ] || [ "$SKIP_SSL" = true ]; then
        print_skip "SSL certificates installation"
        return
    fi
    
    print_status "Installing SSL certificates..."
    
    # Install certbot
    apt-get install -y -qq snapd > /dev/null 2>&1
    snap install core; snap refresh core > /dev/null 2>&1
    snap install --classic certbot > /dev/null 2>&1
    ln -sf /snap/bin/certbot /usr/bin/certbot
    
    # Stop nginx if running
    systemctl stop nginx 2>/dev/null || true
    
    # Get certificate
    print_status "Obtaining SSL certificate for $DOMAIN..."
    
    if [ "$INTERACTIVE" = true ]; then
        read -p "Enter email for SSL certificate: " SSL_EMAIL
    else
        SSL_EMAIL="admin@$DOMAIN"
        print_warning "Using default email: $SSL_EMAIL"
    fi
    
    certbot certonly \
        --standalone \
        --preferred-challenges http \
        --email "$SSL_EMAIL" \
        --agree-tos \
        --no-eff-email \
        --domains "$DOMAIN" \
        --non-interactive \
        > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        print_status "✅ SSL certificate obtained for $DOMAIN"
        
        # Setup auto-renewal
        (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
        print_status "✅ SSL auto-renewal configured"
    else
        print_error "Failed to obtain SSL certificate"
        if [ "$DEV_MODE" = false ]; then
            print_warning "Continuing without SSL (development mode)"
            INSTALL_SSL=false
        fi
    fi
}

create_production_compose() {
    print_status "Preparing Docker Compose configuration..."
    
    cd "$INSTALL_DIR"
    
    # Choose compose file based on mode
    if [ "$DEV_MODE" = true ]; then
        COMPOSE_FILE="docker-compose.yml"
    else
        COMPOSE_FILE="docker-compose.production.yml"
    fi
    
    if [ -f "$COMPOSE_FILE" ]; then
        chmod 644 "$COMPOSE_FILE"
        print_status "✅ Docker Compose configuration ready ($COMPOSE_FILE)"
    else
        print_error "$COMPOSE_FILE not found in repository"
        exit 1
    fi
}

create_nginx_config() {
    if [ "$SKIP_NGINX" = true ]; then
        print_skip "Nginx configuration (--skip-nginx)"
        return
    fi
    
    print_status "Preparing Nginx configuration..."
    
    mkdir -p "$INSTALL_DIR/nginx"
    
    if [ -f "$INSTALL_DIR/nginx/production.conf" ]; then
        chmod 644 "$INSTALL_DIR/nginx/production.conf"
        print_status "✅ Nginx configuration ready"
    else
        print_warning "nginx/production.conf not found, services will run without reverse proxy"
    fi
}

setup_firewall() {
    if [ "$SKIP_FIREWALL" = true ]; then
        print_skip "Firewall configuration (--skip-firewall)"
        return
    fi
    
    print_status "Configuring firewall..."
    
    # Reset UFW
    ufw --force reset > /dev/null 2>&1
    
    # Default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH
    ufw allow ssh
    
    # Allow HTTP and HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Development mode - allow additional ports
    if [ "$DEV_MODE" = true ]; then
        ufw allow 3000/tcp  # React dev server
        ufw allow 5000/tcp  # Flask dev server
        print_verbose "Opened development ports 3000 and 5000"
    fi
    
    # Enable firewall
    ufw --force enable > /dev/null 2>&1
    
    print_status "✅ Firewall configured"
}

create_systemd_service() {
    print_status "Creating systemd service..."
    
    # Choose compose file
    local compose_file="docker-compose.production.yml"
    if [ "$DEV_MODE" = true ]; then
        compose_file="docker-compose.yml"
    fi
    
    cat > /etc/systemd/system/quantconnect-trading-bot.service << EOF
[Unit]
Description=QuantConnect Trading Bot
Documentation=https://github.com/szarastrefa/quantconnect-trading-bot
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=true
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/local/bin/docker-compose -f $compose_file up -d
ExecStop=/usr/local/bin/docker-compose -f $compose_file down
ExecReload=/usr/local/bin/docker-compose -f $compose_file restart
TimeoutStartSec=300
TimeoutStopSec=120

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable quantconnect-trading-bot.service
    
    print_status "✅ Systemd service created and enabled"
}

setup_ddns_service() {
    print_status "Setting up DDNS monitoring service..."
    
    # Create DDNS service directory
    mkdir -p "$INSTALL_DIR/services/ddns"
    
    # Create DDNS Dockerfile (already exists in repo, just ensure permissions)
    if [ ! -f "$INSTALL_DIR/services/ddns/Dockerfile" ]; then
        cat > "$INSTALL_DIR/services/ddns/Dockerfile" << 'EOF'
FROM python:3.11-alpine

WORKDIR /app

RUN pip install --no-cache-dir aiohttp schedule

COPY ddns_updater.py .

CMD ["python", "ddns_updater.py"]
EOF
    fi
    
    print_status "✅ DDNS service configured"
}

create_management_script() {
    print_status "Setting up system management..."
    
    # The manage.sh script should exist in repo
    if [ -f "$INSTALL_DIR/scripts/manage.sh" ]; then
        chmod +x "$INSTALL_DIR/scripts/manage.sh"
        
        # Create system-wide symlink
        ln -sf "$INSTALL_DIR/scripts/manage.sh" /usr/local/bin/trading-bot
        
        print_status "✅ Management script ready (use 'trading-bot' command globally)"
    else
        print_warning "scripts/manage.sh not found, creating basic management"
        
        # Create basic management script
        cat > /usr/local/bin/trading-bot << 'EOF'
#!/bin/bash
cd /opt/quantconnect-trading-bot
case "$1" in
    start)
        docker-compose -f docker-compose.production.yml up -d
        ;;
    stop)
        docker-compose -f docker-compose.production.yml down
        ;;
    status)
        docker-compose -f docker-compose.production.yml ps
        ;;
    logs)
        docker-compose -f docker-compose.production.yml logs -f
        ;;
    *)
        echo "Usage: $0 {start|stop|status|logs}"
        ;;
esac
EOF
        chmod +x /usr/local/bin/trading-bot
        print_status "✅ Basic management script created"
    fi
}

validate_environment() {
    print_status "Validating environment configuration..."
    
    cd "$INSTALL_DIR"
    
    # Choose compose file
    local compose_file="docker-compose.production.yml"
    if [ "$DEV_MODE" = true ]; then
        compose_file="docker-compose.yml"
    fi
    
    # Test docker-compose configuration
    if docker-compose -f "$compose_file" config > /dev/null 2>&1; then
        print_status "✅ Docker Compose configuration valid"
    else
        print_error "❌ Invalid Docker Compose configuration"
        if [ "$VERBOSE" = true ]; then
            print_error "Configuration test output:"
            docker-compose -f "$compose_file" config 2>&1
        fi
        exit 1
    fi
    
    # Check .env file format
    if grep -E "^[A-Z_][A-Z0-9_]*=[^=]*$" .env > /dev/null; then
        print_status "✅ Environment file format valid"
    else
        print_error "❌ Environment file contains invalid format"
        if [ "$VERBOSE" = true ]; then
            print_error "Problematic lines:"
            grep -v -E "^[A-Z_][A-Z0-9_]*=[^=]*$|^[[:space:]]*#|^[[:space:]]*$" .env | head -5
        fi
        exit 1
    fi
}

build_and_start_system() {
    if [ "$NO_AUTO_START" = true ]; then
        print_skip "System build and start (--no-auto-start)"
        print_status "✅ Installation completed without starting services"
        return
    fi
    
    print_status "Building and starting the system..."
    
    cd "$INSTALL_DIR"
    
    # Validate first
    validate_environment
    
    # Choose compose file
    local compose_file="docker-compose.production.yml"
    if [ "$DEV_MODE" = true ]; then
        compose_file="docker-compose.yml"
    fi
    
    # Build images
    print_status "Building Docker images..."
    if [ "$VERBOSE" = true ]; then
        docker-compose -f "$compose_file" build --parallel
    else
        docker-compose -f "$compose_file" build --parallel > /dev/null 2>&1
    fi
    
    # Start services
    print_status "Starting services..."
    docker-compose -f "$compose_file" up -d
    
    # Wait for services to be healthy
    print_status "Waiting for services to start..."
    local wait_time=45
    if [ "$DEV_MODE" = true ]; then
        wait_time=30
    fi
    sleep $wait_time
    
    # Check service health
    check_service_health
    
    print_status "✅ System built and started"
}

check_service_health() {
    print_status "Checking service health..."
    
    # Check if containers are running
    local running_containers=$(docker ps --filter "name=trading" --format "{{.Names}}" | wc -l)
    local expected_containers=5
    
    if [ "$DEV_MODE" = true ]; then
        expected_containers=3
    fi
    
    if [ "$running_containers" -ge "$expected_containers" ]; then
        print_status "✅ Services are running ($running_containers containers)"
    else
        print_warning "⚠️ Some services may not be running ($running_containers containers)"
        if [ "$VERBOSE" = true ]; then
            print_status "Container status:"
            docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        fi
    fi
    
    # Test endpoints
    sleep 10
    local api_url
    if [ "$DEV_MODE" = true ]; then
        api_url="http://localhost:5000/api/health"
    elif [ "$INSTALL_SSL" = true ]; then
        api_url="https://$DOMAIN/health"
    else
        api_url="http://localhost:80/health"
    fi
    
    if curl -f -s "$api_url" > /dev/null 2>&1; then
        print_status "✅ System is responding"
    else
        print_warning "⚠️ System may not be ready yet (services are still starting)"
    fi
}

display_installation_summary() {
    echo ""
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                 🎉 INSTALLATION COMPLETED!                      ║"
    echo "║              QuantConnect Trading Bot v2.0                      ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${BLUE}📍 System Information:${NC}"
    if [ "$DEV_MODE" = true ]; then
        echo "   🧪 Mode: Development"
        echo "   🌐 Frontend: http://localhost:3000"
        echo "   📊 Backend API: http://localhost:5000"
        echo "   📈 API Docs: http://localhost:5000/docs"
    else
        echo "   🏭 Mode: Production"
        echo "   🌐 Domain: https://$DOMAIN"
        echo "   📊 API: https://$DOMAIN/api"
        echo "   📈 Health: https://$DOMAIN/health"
        echo "   🔌 WebSocket: wss://$DOMAIN/socket.io"
    fi
    echo "   📁 Install Path: $INSTALL_DIR"
    echo ""
    
    echo -e "${YELLOW}🔐 GENERATED CREDENTIALS (SAVE THESE SAFELY!):${NC}"
    echo "   ├─ Database User: $POSTGRES_USER"
    echo "   ├─ Database Password: $POSTGRES_PASSWORD"
    echo "   ├─ JWT Secret: $JWT_SECRET"
    echo "   ├─ Encryption Key: $ENCRYPTION_KEY"
    echo "   ├─ Session Secret: $SESSION_SECRET"
    echo "   └─ Redis Password: $REDIS_PASSWORD"
    echo ""
    
    echo -e "${CYAN}🛠️ SYSTEM MANAGEMENT COMMANDS:${NC}"
    echo "   ├─ Start system: trading-bot start"
    echo "   ├─ Stop system: trading-bot stop"
    echo "   ├─ View status: trading-bot status"
    echo "   ├─ View logs: trading-bot logs"
    echo "   ├─ Health check: trading-bot health"
    echo "   ├─ Update DDNS: trading-bot ddns-update"
    echo "   ├─ Update system: trading-bot update"
    echo "   └─ Full restart: trading-bot restart"
    echo ""
    
    echo -e "${PURPLE}📋 NEXT STEPS:${NC}"
    echo "   1. 🔧 Configure broker API keys:"
    echo "      nano $INSTALL_DIR/.env"
    echo ""
    echo "   2. 🚀 Start the trading system:"
    echo "      trading-bot start"
    echo ""
    echo "   3. 🌐 Access the web interface:"
    if [ "$DEV_MODE" = true ]; then
        echo "      http://localhost:3000"
    else
        echo "      https://$DOMAIN"
    fi
    echo ""
    echo "   4. 📈 Upload ML models and begin trading!"
    echo ""
    
    # Show enabled/disabled features
    echo -e "${BLUE}🔧 Installation Features:${NC}"
    echo "   ├─ Production Mode: $([ "$PRODUCTION_MODE" = true ] && echo "✅ Enabled" || echo "❌ Disabled")"
    echo "   ├─ SSL/HTTPS: $([ "$INSTALL_SSL" = true ] && echo "✅ Enabled" || echo "❌ Disabled")"
    echo "   ├─ DDNS Auto-Update: $([ "$SKIP_DDNS_ERROR" = false ] && echo "✅ Enabled" || echo "⚠️ Error Handling")"
    echo "   ├─ Firewall: $([ "$SKIP_FIREWALL" = false ] && echo "✅ Configured" || echo "⏭️ Skipped")"
    echo "   ├─ Nginx Proxy: $([ "$SKIP_NGINX" = false ] && echo "✅ Configured" || echo "⏭️ Skipped")"
    echo "   └─ Auto-Start: $([ "$NO_AUTO_START" = false ] && echo "✅ Enabled" || echo "⏭️ Manual Start")"
    echo ""
    
    echo -e "${GREEN}📚 DOCUMENTATION & SUPPORT:${NC}"
    echo "   📖 README: $INSTALL_DIR/README.md"
    echo "   🔧 Troubleshooting: $INSTALL_DIR/docs/TROUBLESHOOTING.md"
    echo "   📊 Broker Integration: $INSTALL_DIR/docs/BROKER_WORKFLOWS.md"
    echo "   🆘 GitHub Issues: https://github.com/szarastrefa/quantconnect-trading-bot/issues"
    echo ""
    
    echo -e "${RED}⚠️  SECURITY REMINDERS:${NC}"
    echo "   • 💾 Save generated credentials in a password manager"
    echo "   • 🔑 Configure broker API keys before live trading"
    echo "   • 🧪 Use demo/testnet accounts for initial testing"
    echo "   • 📊 Monitor system logs and performance regularly"
    echo "   • 🔄 Keep system updated with: trading-bot update"
    echo ""
    
    echo -e "${GREEN}✅ QuantConnect Trading Bot is ready for algorithmic trading!${NC}"
    echo ""
    
    # Final instructions based on mode
    if [ "$DEV_MODE" = true ]; then
        echo "🧪 Development mode enabled - start coding and testing!"
        echo "🌐 Access: http://localhost:3000"
    else
        echo "🏭 Production system deployed successfully!"
        echo "🌐 Access: https://$DOMAIN"
    fi
}

show_help() {
    echo "QuantConnect Trading Bot - Ubuntu Setup Script v2.0"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "🔧 Installation Modes:"
    echo "  --production          Full production setup with SSL (default)"
    echo "  --dev-mode           Development setup (HTTP, local ports)"
    echo "  --minimal            Minimal installation (core services only)"
    echo "  --interactive        Interactive setup with prompts"
    echo ""
    echo "⏭️ Skip Options:"
    echo "  --skip-ddns-error    Continue if DDNS update fails"
    echo "  --skip-ssl           Skip SSL certificate installation"
    echo "  --skip-firewall      Skip UFW firewall configuration"
    echo "  --skip-docker-check  Skip Docker version checks"
    echo "  --skip-system-update Skip apt package updates"
    echo "  --skip-nginx         Skip Nginx reverse proxy"
    echo "  --skip-deps          Skip dependency installation"
    echo ""
    echo "🛠️ Advanced Options:"
    echo "  --force-install      Remove existing installation"
    echo "  --no-auto-start      Don't start services after build"
    echo "  --verbose            Detailed output and logging"
    echo "  --quiet              Minimal output"
    echo ""
    echo "⚙️ Customization:"
    echo "  --domain DOMAIN      Custom domain (default: eqtrader.ddnskita.my.id)"
    echo "  --port PORT          Custom port override"
    echo "  --data-dir DIR       Custom data directory"
    echo "  --config-file FILE   Custom configuration file"
    echo ""
    echo "📋 Examples:"
    echo "  $0                                    # Standard production setup"
    echo "  $0 --skip-ddns-error --force-install # Skip DDNS issues"
    echo "  $0 --dev-mode --skip-ssl             # Development setup"
    echo "  $0 --minimal --skip-firewall         # Minimal installation"
    echo "  $0 --interactive                     # Interactive setup"
    echo ""
    echo "📚 Documentation: https://github.com/szarastrefa/quantconnect-trading-bot"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --production)
            PRODUCTION_MODE=true
            shift
            ;;
        --dev-mode)
            DEV_MODE=true
            PRODUCTION_MODE=false
            INSTALL_SSL=false
            shift
            ;;
        --minimal)
            MINIMAL=true
            SKIP_SSL=true
            SKIP_FIREWALL=true
            SKIP_NGINX=true
            shift
            ;;
        --interactive)
            INTERACTIVE=true
            shift
            ;;
        --ssl)
            INSTALL_SSL=true
            shift
            ;;
        --skip-ddns-error)
            SKIP_DDNS_ERROR=true
            shift
            ;;
        --skip-ssl)
            SKIP_SSL=true
            INSTALL_SSL=false
            shift
            ;;
        --skip-firewall)
            SKIP_FIREWALL=true
            shift
            ;;
        --skip-docker-check)
            SKIP_DOCKER_CHECK=true
            shift
            ;;
        --skip-system-update)
            SKIP_SYSTEM_UPDATE=true
            shift
            ;;
        --skip-nginx)
            SKIP_NGINX=true
            shift
            ;;
        --skip-postgres)
            SKIP_POSTGRES=true
            shift
            ;;
        --skip-redis)
            SKIP_REDIS=true
            shift
            ;;
        --skip-broker-setup)
            SKIP_BROKER_SETUP=true
            shift
            ;;
        --skip-ml-setup)
            SKIP_ML_SETUP=true
            shift
            ;;
        --skip-deps)
            SKIP_DEPENDENCIES=true
            shift
            ;;
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
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --port)
            CUSTOM_PORT="$2"
            shift 2
            ;;
        --data-dir)
            DATA_DIR="$2"
            shift 2
            ;;
        --config-file)
            CONFIG_FILE="$2"
            shift 2
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

# Interactive mode prompts
if [ "$INTERACTIVE" = true ]; then
    echo ""
    echo "🔧 Interactive Setup Mode"
    echo ""
    
    read -p "Enable production mode? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        PRODUCTION_MODE=false
        DEV_MODE=true
    fi
    
    if [ "$PRODUCTION_MODE" = true ]; then
        read -p "Install SSL certificates? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            INSTALL_SSL=true
        fi
        
        read -p "Configure firewall? (Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            SKIP_FIREWALL=true
        fi
    fi
    
    read -p "Skip DDNS errors if they occur? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        SKIP_DDNS_ERROR=true
    fi
fi

# Auto-enable SSL in production mode (if not explicitly disabled)
if [ "$PRODUCTION_MODE" = true ] && [ "$SKIP_SSL" = false ] && [ "$INSTALL_SSL" = false ]; then
    if [ "$INTERACTIVE" = false ]; then
        INSTALL_SSL=true
    fi
fi

# Main installation flow
main() {
    print_header
    
    # Show selected options in verbose mode
    if [ "$VERBOSE" = true ]; then
        echo -e "${PURPLE}📋 Installation Configuration:${NC}"
        echo "   Production Mode: $PRODUCTION_MODE"
        echo "   Development Mode: $DEV_MODE"
        echo "   Install SSL: $INSTALL_SSL"
        echo "   Skip DDNS Error: $SKIP_DDNS_ERROR"
        echo "   Skip Firewall: $SKIP_FIREWALL"
        echo "   Force Install: $FORCE_INSTALL"
        echo "   Install Directory: $INSTALL_DIR"
        echo ""
    fi
    
    # System checks
    check_root
    check_system_requirements
    
    # Create log file
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    
    print_status "🔧 Starting QuantConnect Trading Bot installation..."
    print_status "📅 Installation started at: $(date)"
    print_verbose "Installation mode: $([ "$DEV_MODE" = true ] && echo "Development" || echo "Production")"
    
    # Installation steps with skip options
    update_system
    install_dependencies
    install_docker
    install_docker_compose
    setup_ddns
    clone_repository
    setup_environment
    
    # SSL installation
    if [ "$INSTALL_SSL" = true ] && [ "$SKIP_SSL" = false ]; then
        install_ssl_certificates
    else
        print_skip "SSL certificates installation"
    fi
    
    create_production_compose
    create_nginx_config
    setup_firewall
    setup_ddns_service
    create_systemd_service
    create_management_script
    
    # Build and start (unless skipped)
    build_and_start_system
    
    # Show completion summary with all details
    display_installation_summary
}

# Run main function
main "$@"