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
PRODUCTION_MODE=false
INSTALL_SSL=false
SKIP_DEPENDENCIES=false
CUSTOM_PORT=""
DATA_DIR=""
CONFIG_FILE=""

print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                 QuantConnect Trading Bot                         ║"
    echo "║                    Ubuntu Setup Script                          ║"
    echo "║                                                                  ║"
    echo "║  Domain: eqtrader.ddnskita.my.id                                ║"
    echo "║  DDNS: hostddns.us tunnel integration                           ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
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
    print_status "Checking system requirements..."
    
    # Check Ubuntu version
    if ! grep -q "Ubuntu" /etc/os-release; then
        print_error "This script is designed for Ubuntu. Other distributions may not be supported."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
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
        exit 1
    fi
    
    print_status "✅ System requirements check passed"
}

update_system() {
    print_status "Updating system packages..."
    apt-get update -qq > /dev/null 2>&1
    apt-get upgrade -y -qq > /dev/null 2>&1
    apt-get autoremove -y -qq > /dev/null 2>&1
    print_status "✅ System packages updated"
}

install_dependencies() {
    if [ "$SKIP_DEPENDENCIES" = true ]; then
        print_status "Skipping dependencies installation"
        return
    fi
    
    print_status "Installing system dependencies..."
    
    # Essential packages
    apt-get install -y -qq \
        curl \
        wget \
        git \
        unzip \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        jq \
        htop \
        nano \
        ufw \
        cron \
        openssl \
        > /dev/null 2>&1
    
    print_status "✅ System dependencies installed"
}

install_docker() {
    print_status "Installing Docker..."
    
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
    
    # Get latest version
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
    
    # Download and install
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Create symlink
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    print_status "✅ Docker Compose ${DOCKER_COMPOSE_VERSION} installed"
}

setup_ddns() {
    print_status "Setting up DDNS integration..."
    
    # Update DDNS record
    print_status "Updating DDNS record for $DOMAIN..."
    DDNS_RESPONSE=$(curl -s "$DDNS_UPDATE_URL")
    
    if echo "$DDNS_RESPONSE" | grep -q "success"; then
        print_status "✅ DDNS updated successfully"
        echo "$DDNS_RESPONSE" | jq '.' 2>/dev/null || echo "$DDNS_RESPONSE"
        
        # Get current IP
        CURRENT_IP=$(echo "$DDNS_RESPONSE" | jq -r '.message' | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' || curl -s ifconfig.me)
        print_status "Current IP: $CURRENT_IP"
        
        # Setup automatic updates
        setup_ddns_cron
        
    else
        print_error "Failed to update DDNS record"
        echo "$DDNS_RESPONSE"
        exit 1
    fi
}

setup_ddns_cron() {
    print_status "Setting up automatic DDNS updates..."
    
    # Create DDNS update script
    cat > /usr/local/bin/update-ddns.sh << EOF
#!/bin/bash
# Automatic DDNS update script
RESPONSE=\$(curl -s "$DDNS_UPDATE_URL")
if echo "\$RESPONSE" | grep -q "success"; then
    logger "DDNS updated successfully for $DOMAIN"
else
    logger "DDNS update failed for $DOMAIN: \$RESPONSE"
fi
EOF
    
    chmod +x /usr/local/bin/update-ddns.sh
    
    # Add to crontab (every 5 minutes)
    (crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/update-ddns.sh") | crontab -
    
    print_status "✅ DDNS auto-update configured (every 5 minutes)"
}

clone_repository() {
    print_status "Cloning QuantConnect Trading Bot repository..."
    
    # Remove existing directory if present
    if [ -d "$INSTALL_DIR" ]; then
        print_warning "Existing installation found. Backing up..."
        mv "$INSTALL_DIR" "${INSTALL_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Clone repository
    git clone https://github.com/szarastrefa/quantconnect-trading-bot.git "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # Set permissions
    chown -R "$SUDO_USER:$SUDO_USER" "$INSTALL_DIR" 2>/dev/null || true
    
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
    
    print_status "✅ Secure credentials generated"
}

setup_environment() {
    print_status "Setting up environment configuration..."
    
    cd "$INSTALL_DIR"
    
    # Generate credentials first
    generate_all_credentials
    
    # Create production environment file
    cat > .env << EOF
# QuantConnect Trading Bot - Production Environment
# Generated on $(date)

# Environment Configuration
NODE_ENV=production
ENVIRONMENT=production
DEBUG=false
FLASK_ENV=production
FLASK_DEBUG=false

# Domain & DDNS Configuration
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
API_BASE_URL=https://$DOMAIN/api
FRONTEND_URL=https://$DOMAIN
WEBSOCKET_URL=wss://$DOMAIN/socket.io
CORS_ORIGINS=https://$DOMAIN
SOCKETIO_CORS_ORIGINS=https://$DOMAIN

# React App Configuration
REACT_APP_API_URL=https://$DOMAIN/api
REACT_APP_WS_URL=wss://$DOMAIN/socket.io
REACT_APP_DOMAIN=$DOMAIN

# SSL Configuration
SSL_ENABLED=true
SSL_CERT_PATH=/etc/letsencrypt/live/$DOMAIN/fullchain.pem
SSL_KEY_PATH=/etc/letsencrypt/live/$DOMAIN/privkey.pem

# QuantConnect Configuration
QC_USER_ID=
QC_API_TOKEN=
QC_ENVIRONMENT=live-trading

# Trading Configuration
MAX_DAILY_LOSS=0.05
MAX_POSITION_SIZE=0.10
SIGNAL_CONFIDENCE_THRESHOLD=0.60
MAX_CONCURRENT_TRADES=10

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
TRUSTED_HOSTS=$DOMAIN,localhost
MAX_CONTENT_LENGTH=16777216

# Data Directories
DATA_DIR=/opt/quantconnect-trading-bot/data
LOGS_DIR=/opt/quantconnect-trading-bot/logs
MODELS_DIR=/app/models/trained_models
CONFIGS_DIR=/app/models/model_configs

# Broker API Keys - CONFIGURE THESE FOR YOUR BROKERS
# ============================================================================

# Forex Brokers
XM_LOGIN=YOUR_XM_LOGIN_NUMBER
XM_PASSWORD=YOUR_XM_PASSWORD
XM_SERVER=XM-Real

XTB_USER_ID=YOUR_XTB_USER_ID
XTB_PASSWORD=YOUR_XTB_PASSWORD
XTB_DEMO=false

IC_MARKETS_API_KEY=YOUR_IC_MARKETS_API_KEY
IC_MARKETS_TOKEN=YOUR_IC_MARKETS_TOKEN
IC_MARKETS_DEMO=false

IG_API_KEY=YOUR_IG_API_KEY
IG_USERNAME=YOUR_IG_USERNAME
IG_PASSWORD=YOUR_IG_PASSWORD
IG_DEMO=false

ADMIRAL_LOGIN=YOUR_ADMIRAL_LOGIN
ADMIRAL_PASSWORD=YOUR_ADMIRAL_PASSWORD
ADMIRAL_SERVER=AdmiralMarkets-Live

ROBOFOREX_LOGIN=YOUR_ROBOFOREX_LOGIN
ROBOFOREX_PASSWORD=YOUR_ROBOFOREX_PASSWORD
ROBOFOREX_SERVER=RoboForex-Pro

FBS_LOGIN=YOUR_FBS_LOGIN
FBS_PASSWORD=YOUR_FBS_PASSWORD
FBS_SERVER=FBS-Real

INSTAFOREX_LOGIN=YOUR_INSTAFOREX_LOGIN
INSTAFOREX_PASSWORD=YOUR_INSTAFOREX_PASSWORD
INSTAFOREX_SERVER=InstaForex-Server

SABIOTRADE_API_KEY=YOUR_SABIOTRADE_API_KEY
SABIOTRADE_USERNAME=YOUR_SABIOTRADE_USERNAME
SABIOTRADE_PASSWORD=YOUR_SABIOTRADE_PASSWORD

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

BYBIT_API_KEY=YOUR_BYBIT_API_KEY
BYBIT_SECRET_KEY=YOUR_BYBIT_SECRET_KEY
BYBIT_TESTNET=false

KUCOIN_API_KEY=YOUR_KUCOIN_API_KEY
KUCOIN_SECRET_KEY=YOUR_KUCOIN_SECRET_KEY
KUCOIN_PASSPHRASE=YOUR_KUCOIN_PASSPHRASE
KUCOIN_SANDBOX=false

OKX_API_KEY=YOUR_OKX_API_KEY
OKX_SECRET_KEY=YOUR_OKX_SECRET_KEY
OKX_PASSPHRASE=YOUR_OKX_PASSPHRASE
OKX_DEMO=false

BITFINEX_API_KEY=YOUR_BITFINEX_API_KEY
BITFINEX_SECRET_KEY=YOUR_BITFINEX_SECRET_KEY

GEMINI_API_KEY=YOUR_GEMINI_API_KEY
GEMINI_SECRET_KEY=YOUR_GEMINI_SECRET_KEY
GEMINI_SANDBOX=false

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

# Custom Settings
CUSTOM_SETTING_1=
CUSTOM_SETTING_2=
EOF
    
    # Secure the environment file
    chmod 600 .env
    
    print_status "✅ Environment configuration created"
}

install_ssl_certificates() {
    if [ "$INSTALL_SSL" = false ]; then
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
    
    read -p "Enter email for SSL certificate: " SSL_EMAIL
    
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
        INSTALL_SSL=false
    fi
}

create_production_compose() {
    print_status "Creating production Docker Compose configuration..."
    
    cd "$INSTALL_DIR"
    
    # The docker-compose.production.yml file already exists in repo
    # Just ensure it has the right permissions
    if [ -f "docker-compose.production.yml" ]; then
        chmod 644 docker-compose.production.yml
        print_status "✅ Production Docker Compose configuration ready"
    else
        print_error "docker-compose.production.yml not found in repository"
        exit 1
    fi
}

create_nginx_config() {
    print_status "Creating Nginx production configuration..."
    
    # The nginx/production.conf file already exists in repo
    # Just ensure directory and permissions
    mkdir -p "$INSTALL_DIR/nginx"
    
    if [ -f "$INSTALL_DIR/nginx/production.conf" ]; then
        chmod 644 "$INSTALL_DIR/nginx/production.conf"
        print_status "✅ Nginx configuration ready"
    else
        print_error "nginx/production.conf not found in repository"
        exit 1
    fi
}

setup_firewall() {
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
    
    # Enable firewall
    ufw --force enable > /dev/null 2>&1
    
    print_status "✅ Firewall configured"
}

create_systemd_service() {
    print_status "Creating systemd service..."
    
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
ExecStart=/usr/local/bin/docker-compose -f docker-compose.production.yml up -d
ExecStop=/usr/local/bin/docker-compose -f docker-compose.production.yml down
ExecReload=/usr/local/bin/docker-compose -f docker-compose.production.yml restart
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
    
    # Create DDNS Dockerfile
    cat > "$INSTALL_DIR/services/ddns/Dockerfile" << 'EOF'
FROM python:3.11-alpine

WORKDIR /app

RUN pip install --no-cache-dir aiohttp schedule

COPY ddns_updater.py .

CMD ["python", "ddns_updater.py"]
EOF
    
    # Create DDNS updater script
    cat > "$INSTALL_DIR/services/ddns/ddns_updater.py" << 'EOF'
#!/usr/bin/env python3
"""
DDNS Updater Service
Automatically updates DDNS record for eqtrader.ddnskita.my.id
"""

import os
import time
import json
import asyncio
import aiohttp
import logging
from datetime import datetime

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class DDNSUpdater:
    def __init__(self):
        self.update_url = os.getenv('DDNS_UPDATE_URL')
        self.domain = os.getenv('DOMAIN', 'eqtrader.ddnskita.my.id')
        self.update_interval = int(os.getenv('UPDATE_INTERVAL', '300'))  # 5 minutes
        self.last_ip = None
        
    async def get_public_ip(self):
        """Get current public IP address"""
        ip_services = [
            'https://ifconfig.me/ip',
            'https://api.ipify.org',
            'https://icanhazip.com'
        ]
        
        async with aiohttp.ClientSession() as session:
            for service in ip_services:
                try:
                    async with session.get(service, timeout=10) as response:
                        if response.status == 200:
                            ip = (await response.text()).strip()
                            if self.validate_ip(ip):
                                return ip
                except Exception as e:
                    logger.debug(f"Failed to get IP from {service}: {e}")
                    continue
        
        return None
    
    def validate_ip(self, ip):
        """Validate IP address format"""
        import re
        pattern = re.compile(
            r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}'
            r'(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
        )
        return bool(pattern.match(ip))
    
    async def update_ddns(self):
        """Update DDNS record"""
        try:
            current_ip = await self.get_public_ip()
            if not current_ip:
                logger.error("Could not determine public IP")
                return False
                
            # Only update if IP changed
            if current_ip == self.last_ip:
                logger.debug("IP hasn't changed, skipping update")
                return True
                
            logger.info(f"Updating DDNS for {self.domain} to IP {current_ip}")
            
            async with aiohttp.ClientSession() as session:
                async with session.get(self.update_url, timeout=30) as response:
                    response_text = await response.text()
                    
                    try:
                        response_data = json.loads(response_text)
                    except json.JSONDecodeError:
                        response_data = {'message': response_text}
                    
                    if response_data.get('result') == 'success':
                        self.last_ip = current_ip
                        logger.info(f"✅ DDNS updated successfully: {response_data.get('message', '')}")
                        return True
                    else:
                        logger.error(f"❌ DDNS update failed: {response_data}")
                        return False
                        
        except Exception as e:
            logger.error(f"Error updating DDNS: {e}")
            return False
    
    async def run(self):
        """Run the DDNS updater"""
        logger.info(f"🚀 DDNS Updater started for {self.domain}")
        logger.info(f"📡 Update interval: {self.update_interval} seconds")
        
        # Initial update
        await self.update_ddns()
        
        # Main loop
        while True:
            try:
                await asyncio.sleep(self.update_interval)
                await self.update_ddns()
            except KeyboardInterrupt:
                logger.info("DDNS updater stopped")
                break
            except Exception as e:
                logger.error(f"Error in main loop: {e}")
                await asyncio.sleep(60)  # Wait before retry

if __name__ == "__main__":
    updater = DDNSUpdater()
    asyncio.run(updater.run())
EOF
    
    print_status "✅ DDNS service configured"
}

create_management_script() {
    print_status "Creating system management script..."
    
    # The manage.sh script already exists in repo
    if [ -f "$INSTALL_DIR/scripts/manage.sh" ]; then
        chmod +x "$INSTALL_DIR/scripts/manage.sh"
        
        # Create system-wide symlink
        ln -sf "$INSTALL_DIR/scripts/manage.sh" /usr/local/bin/trading-bot
        
        print_status "✅ Management script ready (use 'trading-bot' command globally)"
    else
        print_error "scripts/manage.sh not found in repository"
        exit 1
    fi
}

validate_environment() {
    print_status "Validating environment configuration..."
    
    cd "$INSTALL_DIR"
    
    # Test docker-compose configuration
    if docker-compose -f docker-compose.production.yml config > /dev/null 2>&1; then
        print_status "✅ Docker Compose configuration valid"
    else
        print_error "❌ Invalid Docker Compose configuration"
        print_error "Running config test for debugging:"
        docker-compose -f docker-compose.production.yml config
        exit 1
    fi
    
    # Check .env file format
    if grep -q "^[A-Z_][A-Z0-9_]*=[^=]*$" .env; then
        print_status "✅ Environment file format valid"
    else
        print_error "❌ Environment file contains invalid format"
        exit 1
    fi
}

build_and_start_system() {
    print_status "Building and starting the system..."
    
    cd "$INSTALL_DIR"
    
    # Validate first
    validate_environment
    
    # Build images
    print_status "Building Docker images..."
    docker-compose -f docker-compose.production.yml build --parallel
    
    # Start services
    print_status "Starting services..."
    docker-compose -f docker-compose.production.yml up -d
    
    # Wait for services to be healthy
    print_status "Waiting for services to start..."
    sleep 45
    
    # Check service health
    check_service_health
    
    print_status "✅ System built and started"
}

check_service_health() {
    print_status "Checking service health..."
    
    # Check if containers are running
    RUNNING_CONTAINERS=$(docker ps --filter "name=trading_bot" --format "table {{.Names}}\t{{.Status}}" | grep -c "Up")
    TOTAL_CONTAINERS=8
    
    if [ "$RUNNING_CONTAINERS" -ge 5 ]; then
        print_status "✅ Most containers are running ($RUNNING_CONTAINERS/$TOTAL_CONTAINERS)"
    else
        print_warning "⚠️ Some containers may not be running ($RUNNING_CONTAINERS/$TOTAL_CONTAINERS)"
        print_status "Container status:"
        docker ps --filter "name=trading_bot" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    fi
    
    # Test API endpoint
    sleep 10
    if [ "$INSTALL_SSL" = true ]; then
        API_URL="https://$DOMAIN/health"
    else
        API_URL="http://localhost:80/health"
    fi
    
    if curl -f -s "$API_URL" > /dev/null 2>&1; then
        print_status "✅ System is responding"
    else
        print_warning "⚠️ System may not be ready yet (this is normal, services are starting)"
    fi
}

display_installation_summary() {
    echo ""
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                 🎉 INSTALLATION COMPLETED!                      ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${BLUE}📍 System Information:${NC}"
    echo "   🌐 Domain: https://$DOMAIN"
    echo "   📊 API: https://$DOMAIN/api"
    echo "   📈 Health: https://$DOMAIN/health"
    echo "   🔌 WebSocket: wss://$DOMAIN/socket.io"
    echo ""
    
    echo -e "${YELLOW}🔐 GENERATED CREDENTIALS (SAVE THESE SAFELY!):${NC}"
    echo "   ├─ Database User: $POSTGRES_USER"
    echo "   ├─ Database Password: $POSTGRES_PASSWORD"
    echo "   ├─ JWT Secret: $JWT_SECRET"
    echo "   ├─ Encryption Key: $ENCRYPTION_KEY"
    echo "   ├─ Session Secret: $SESSION_SECRET"
    echo "   └─ Redis Password: $REDIS_PASSWORD"
    echo ""
    
    echo -e "${CYAN}🛠️ SYSTEM MANAGEMENT:${NC}"
    echo "   ├─ Start system: trading-bot start"
    echo "   ├─ Stop system: trading-bot stop"
    echo "   ├─ View logs: trading-bot logs"
    echo "   ├─ System status: trading-bot status"
    echo "   ├─ Health check: trading-bot health"
    echo "   ├─ Update DDNS: trading-bot ddns-update"
    echo "   └─ Update system: trading-bot update"
    echo ""
    
    echo -e "${PURPLE}📋 IMPORTANT NEXT STEPS:${NC}"
    echo "   1. 🔧 Configure broker API keys:"
    echo "      nano $INSTALL_DIR/.env"
    echo ""
    echo "   2. 🚀 Start the trading system:"
    echo "      trading-bot start"
    echo ""
    echo "   3. 🌐 Access web interface:"
    echo "      https://$DOMAIN"
    echo ""
    echo "   4. 📈 Begin trading!"
    echo "      Configure your strategies and models"
    echo ""
    
    echo -e "${RED}⚠️  SECURITY REMINDER:${NC}"
    echo "   • Save the generated passwords in a secure location"
    echo "   • Configure broker API keys before starting trading"
    echo "   • Use demo/testnet accounts for initial testing"
    echo "   • Monitor system logs regularly"
    echo ""
    
    echo -e "${GREEN}✅ QuantConnect Trading Bot is ready to use!${NC}"
    echo ""
    echo "📚 Documentation: https://github.com/szarastrefa/quantconnect-trading-bot"
    echo "🆘 Support: https://github.com/szarastrefa/quantconnect-trading-bot/issues"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --production)
            PRODUCTION_MODE=true
            shift
            ;;
        --ssl)
            INSTALL_SSL=true
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
        --skip-deps)
            SKIP_DEPENDENCIES=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --production          Enable production mode"
            echo "  --ssl                 Install SSL certificates"
            echo "  --domain DOMAIN       Custom domain (default: eqtrader.ddnskita.my.id)"
            echo "  --port PORT           Custom port"
            echo "  --data-dir DIR        Custom data directory"
            echo "  --config-file FILE    Custom config file"
            echo "  --skip-deps           Skip dependency installation"
            echo "  --help                Show this help"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Auto-enable production mode with SSL
PRODUCTION_MODE=true
if [ "$INSTALL_SSL" = false ] && [ "$PRODUCTION_MODE" = true ]; then
    echo ""
    read -p "🔒 Enable SSL certificates for production? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        INSTALL_SSL=true
    fi
fi

# Main installation flow
main() {
    print_header
    
    # System checks
    check_root
    check_system_requirements
    
    # Create log file
    touch "$LOG_FILE"
    
    print_status "🔧 Starting QuantConnect Trading Bot installation..."
    print_status "📅 Installation started at: $(date)"
    
    # Installation steps
    update_system
    install_dependencies
    install_docker
    install_docker_compose
    setup_ddns
    clone_repository
    setup_environment
    
    if [ "$INSTALL_SSL" = true ]; then
        install_ssl_certificates
    fi
    
    create_production_compose
    create_nginx_config
    setup_firewall
    setup_ddns_service
    create_systemd_service
    create_management_script
    
    # Build and start
    build_and_start_system
    
    # Show completion summary
    display_installation_summary
}

# Run main function
main "$@"