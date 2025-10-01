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

setup_environment() {
    print_status "Setting up environment configuration..."
    
    cd "$INSTALL_DIR"
    
    # Create production environment file
    cat > .env << EOF
# QuantConnect Trading Bot - Production Environment
# Generated on $(date)

# Environment
NODE_ENV=production
ENVIRONMENT=production
DOMAIN=$DOMAIN
DEBUG=false

# DDNS Configuration
DDNS_UPDATE_URL=$DDNS_UPDATE_URL
DDNS_CHECK_INTERVAL=300
AUTO_UPDATE_DDNS=true

# Database Configuration
POSTGRES_DB=trading_bot
POSTGRES_USER=postgres
POSTGRES_PASSWORD=$(openssl rand -base64 32)

# Redis Configuration
REDIS_URL=redis://redis:6379/0

# Flask Configuration
SECRET_KEY=$(openssl rand -base64 64)
JWT_SECRET_KEY=$(openssl rand -base64 64)
FLASK_ENV=production

# API Configuration
API_BASE_URL=https://$DOMAIN/api
FRONTEND_URL=https://$DOMAIN
CORS_ORIGINS=https://$DOMAIN

# WebSocket Configuration  
SOCKETIO_CORS_ORIGINS=https://$DOMAIN

# QuantConnect Configuration
QC_USER_ID=
QC_API_TOKEN=

# Logging
LOG_LEVEL=INFO
LOG_FILE_PATH=/app/logs/trading_bot.log

# Security
RATE_LIMIT_PER_MINUTE=60
ENABLE_CORS=true
TRUSTED_HOSTS=$DOMAIN,localhost

# Trading Configuration
MAX_DAILY_LOSS=0.05
MAX_POSITION_SIZE=0.10
SIGNAL_CONFIDENCE_THRESHOLD=0.60
MAX_CONCURRENT_TRADES=10

# SSL Configuration
SSL_ENABLED=true
SSL_CERT_PATH=/etc/letsencrypt/live/$DOMAIN/fullchain.pem
SSL_KEY_PATH=/etc/letsencrypt/live/$DOMAIN/privkey.pem

# Monitoring
ENABLE_HEALTH_CHECK=true
HEALTH_CHECK_INTERVAL=30
METRICS_RETENTION_DAYS=30

# Broker API Keys (Configure these for your brokers)
# Forex Brokers
XM_LOGIN=
XM_PASSWORD=
XM_SERVER=

XTB_USER_ID=
XTB_PASSWORD=
XTB_DEMO=true

# Crypto Exchanges
BINANCE_API_KEY=
BINANCE_SECRET_KEY=
BINANCE_TESTNET=true

KRAKEN_API_KEY=
KRAKEN_SECRET_KEY=

COINBASE_API_KEY=
COINBASE_SECRET_KEY=
COINBASE_PASSPHRASE=
COINBASE_SANDBOX=true

# Add more broker credentials as needed
EOF
    
    # Secure the environment file
    chmod 600 .env
    
    print_status "✅ Environment configuration created"
    
    if [ "$PRODUCTION_MODE" = true ]; then
        print_warning "⚠️  IMPORTANT: Edit .env file and configure broker API keys:"
        print_warning "   nano $INSTALL_DIR/.env"
    fi
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
    
    cat > docker-compose.production.yml << 'EOF'
version: '3.8'

services:
  # Nginx Reverse Proxy with SSL
  nginx:
    image: nginx:alpine
    container_name: trading_bot_nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/production.conf:/etc/nginx/conf.d/default.conf:ro
      - /etc/letsencrypt:/etc/letsencrypt:ro
    depends_on:
      - api
      - frontend
    networks:
      - trading_network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Backend Flask API
  api:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: trading_bot_api
    environment:
      - NODE_ENV=production
      - ENVIRONMENT=production
      - DOMAIN=${DOMAIN}
      - DDNS_UPDATE_URL=${DDNS_UPDATE_URL}
      - SSL_ENABLED=true
    env_file:
      - .env
    volumes:
      - ./lean:/app/lean
      - ./models:/app/models
      - ./data:/app/data
      - ./logs:/app/logs
    depends_on:
      - db
      - redis
      - lean_engine
    networks:
      - trading_network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  # Frontend React
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: trading_bot_frontend
    environment:
      - REACT_APP_API_URL=https://${DOMAIN}/api
      - REACT_APP_WS_URL=wss://${DOMAIN}/socket.io
      - NODE_ENV=production
    depends_on:
      - api
    networks:
      - trading_network
    restart: unless-stopped

  # QuantConnect Lean Engine
  lean_engine:
    image: quantconnect/lean:latest
    container_name: lean_engine
    volumes:
      - ./lean:/Lean
      - ./data:/Data
      - ./algorithms:/Algorithms
      - ./models:/Models
    environment:
      - environment=live-trading
      - debugging=false
    env_file:
      - .env
    networks:
      - trading_network
    restart: unless-stopped

  # PostgreSQL Database
  db:
    image: postgres:15-alpine
    container_name: trading_bot_db
    environment:
      - POSTGRES_DB=trading_bot
      - POSTGRES_USER=postgres
    env_file:
      - .env
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./database/init.sql:/docker-entrypoint-initdb.d/init.sql
    networks:
      - trading_network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 30s
      timeout: 5s
      retries: 5

  # Redis Cache
  redis:
    image: redis:7-alpine
    container_name: trading_bot_redis
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD:-redis123}
    volumes:
      - redis_data:/data
    networks:
      - trading_network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 5s
      retries: 3

  # DDNS Updater Service
  ddns_updater:
    build:
      context: ./services/ddns
      dockerfile: Dockerfile
    container_name: ddns_updater
    environment:
      - DDNS_UPDATE_URL=${DDNS_UPDATE_URL}
      - DOMAIN=${DOMAIN}
      - UPDATE_INTERVAL=300
    restart: unless-stopped
    networks:
      - trading_network

volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local

networks:
  trading_network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
EOF
    
    print_status "✅ Production Docker Compose created"
}

create_nginx_config() {
    print_status "Creating Nginx production configuration..."
    
    mkdir -p "$INSTALL_DIR/nginx"
    
    if [ "$INSTALL_SSL" = true ]; then
        # SSL configuration
        cat > "$INSTALL_DIR/nginx/production.conf" << EOF
# HTTP to HTTPS redirect
server {
    listen 80;
    server_name $DOMAIN;
    
    # ACME challenge for SSL renewal
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    # Redirect all other traffic to HTTPS
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

# Main HTTPS server
server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    
    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 10m;
    ssl_session_cache shared:SSL:10m;
    
    # Security Headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Frontend (React)
    location / {
        proxy_pass http://frontend:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # Backend API
    location /api/ {
        proxy_pass http://api:5000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Increase timeout for long-running operations
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # WebSocket endpoint
    location /socket.io/ {
        proxy_pass http://api:5000/socket.io/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\\n";
        add_header Content-Type text/plain;
    }
}
EOF
    else
        # HTTP only configuration
        cat > "$INSTALL_DIR/nginx/production.conf" << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    # Frontend
    location / {
        proxy_pass http://frontend:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    # Backend API
    location /api/ {
        proxy_pass http://api:5000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    # WebSocket
    location /socket.io/ {
        proxy_pass http://api:5000/socket.io/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    location /health {
        return 200 "healthy\\n";
        add_header Content-Type text/plain;
    }
}
EOF
    fi
    
    print_status "✅ Nginx configuration created"
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

build_and_start_system() {
    print_status "Building and starting the system..."
    
    cd "$INSTALL_DIR"
    
    # Build images
    print_status "Building Docker images..."
    if [ "$PRODUCTION_MODE" = true ]; then
        docker-compose -f docker-compose.production.yml build --parallel
    else
        docker-compose build --parallel
    fi
    
    # Start services
    print_status "Starting services..."
    if [ "$PRODUCTION_MODE" = true ]; then
        docker-compose -f docker-compose.production.yml up -d
    else
        docker-compose up -d
    fi
    
    # Wait for services to be healthy
    print_status "Waiting for services to start..."
    sleep 30
    
    # Check service health
    check_service_health
    
    print_status "✅ System built and started"
}

check_service_health() {
    print_status "Checking service health..."
    
    # Check if containers are running
    RUNNING_CONTAINERS=$(docker ps --filter "name=trading_bot" --format "table {{.Names}}\t{{.Status}}" | grep -c "Up")
    TOTAL_CONTAINERS=5
    
    if [ "$RUNNING_CONTAINERS" -eq "$TOTAL_CONTAINERS" ]; then
        print_status "✅ All containers are running ($RUNNING_CONTAINERS/$TOTAL_CONTAINERS)"
    else
        print_warning "⚠️  Some containers may not be running ($RUNNING_CONTAINERS/$TOTAL_CONTAINERS)"
        print_status "Container status:"
        docker ps --filter "name=trading_bot" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    fi
    
    # Test API endpoint
    sleep 10
    if [ "$INSTALL_SSL" = true ]; then
        API_URL="https://$DOMAIN/api/health"
    else
        API_URL="http://localhost:5000/api/health"
    fi
    
    if curl -f -s "$API_URL" > /dev/null; then
        print_status "✅ Backend API is responding"
    else
        print_warning "⚠️  Backend API may not be ready yet"
    fi
}

create_management_script() {
    print_status "Creating system management script..."
    
    cat > "$INSTALL_DIR/manage.sh" << 'EOF'
#!/bin/bash
# QuantConnect Trading Bot Management Script

COMPOSE_FILE="docker-compose.production.yml"
if [ ! -f "$COMPOSE_FILE" ]; then
    COMPOSE_FILE="docker-compose.yml"
fi

case "$1" in
    start)
        echo "🚀 Starting QuantConnect Trading Bot..."
        docker-compose -f $COMPOSE_FILE up -d
        ;;
    stop)
        echo "🛑 Stopping QuantConnect Trading Bot..."
        docker-compose -f $COMPOSE_FILE down
        ;;
    restart)
        echo "🔄 Restarting QuantConnect Trading Bot..."
        docker-compose -f $COMPOSE_FILE restart
        ;;
    status)
        echo "📊 System Status:"
        docker-compose -f $COMPOSE_FILE ps
        echo ""
        echo "🔍 Container Health:"
        docker ps --filter "name=trading_bot" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        ;;
    logs)
        if [ -n "$2" ]; then
            docker-compose -f $COMPOSE_FILE logs -f "$2"
        else
            docker-compose -f $COMPOSE_FILE logs -f
        fi
        ;;
    update)
        echo "🔄 Updating system..."
        git pull origin main
        docker-compose -f $COMPOSE_FILE build --pull
        docker-compose -f $COMPOSE_FILE up -d
        ;;
    backup)
        echo "💾 Creating system backup..."
        ./scripts/backup_system.sh
        ;;
    ddns-update)
        echo "🌐 Updating DDNS record..."
        curl -s "${DDNS_UPDATE_URL}"
        ;;
    health)
        echo "🏥 Running health check..."
        python3 scripts/check_system_integrity.py --verbose
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|update|backup|ddns-update|health}"
        echo ""
        echo "Examples:"
        echo "  $0 start              # Start the system"
        echo "  $0 logs api           # Show API logs"
        echo "  $0 status             # Show system status"
        echo "  $0 health             # Run health check"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$INSTALL_DIR/manage.sh"
    
    # Create system-wide symlink
    ln -sf "$INSTALL_DIR/manage.sh" /usr/local/bin/trading-bot
    
    print_status "✅ Management script created (use 'trading-bot' command globally)"
}

setup_ddns_service() {
    print_status "Setting up DDNS monitoring service..."
    
    # Create DDNS service directory
    mkdir -p "$INSTALL_DIR/services/ddns"
    
    # Create DDNS Dockerfile
    cat > "$INSTALL_DIR/services/ddns/Dockerfile" << 'EOF'
FROM python:3.11-alpine

WORKDIR /app

RUN pip install requests schedule

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
import requests
import schedule
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
        
    def get_public_ip(self):
        """Get current public IP address"""
        try:
            response = requests.get('https://ifconfig.me/ip', timeout=10)
            return response.text.strip()
        except Exception as e:
            logger.error(f"Failed to get public IP: {e}")
            return None
    
    def update_ddns(self):
        """Update DDNS record"""
        try:
            current_ip = self.get_public_ip()
            if not current_ip:
                return False
                
            # Only update if IP changed
            if current_ip == self.last_ip:
                logger.debug("IP hasn't changed, skipping update")
                return True
                
            logger.info(f"Updating DDNS for {self.domain} to IP {current_ip}")
            
            response = requests.get(self.update_url, timeout=30)
            response_data = response.json() if response.headers.get('content-type') == 'application/json' else {'message': response.text}
            
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
    
    def run_scheduler(self):
        """Run the DDNS updater scheduler"""
        logger.info(f"🚀 DDNS Updater started for {self.domain}")
        logger.info(f"📡 Update interval: {self.update_interval} seconds")
        
        # Initial update
        self.update_ddns()
        
        # Schedule regular updates
        schedule.every(self.update_interval // 60).minutes.do(self.update_ddns)
        
        while True:
            schedule.run_pending()
            time.sleep(60)

if __name__ == "__main__":
    updater = DDNSUpdater()
    updater.run_scheduler()
EOF
    
    print_status "✅ DDNS service configured"
}

print_completion_message() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    🎉 INSTALLATION COMPLETE! 🎉                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${BLUE}📍 Installation Details:${NC}"
    echo "   📂 Install Directory: $INSTALL_DIR"
    echo "   🌐 Domain: $DOMAIN"
    echo "   🔗 DDNS URL: $DDNS_UPDATE_URL"
    echo "   🐳 Docker Compose: $([ "$PRODUCTION_MODE" = true ] && echo "Production" || echo "Development")"
    echo "   🔒 SSL: $([ "$INSTALL_SSL" = true ] && echo "Enabled" || echo "Disabled")"
    echo ""
    
    echo -e "${GREEN}🚀 Quick Start Commands:${NC}"
    echo "   trading-bot start     # Start the system"
    echo "   trading-bot status    # Check system status"  
    echo "   trading-bot logs      # View logs"
    echo "   trading-bot health    # Run health check"
    echo ""
    
    if [ "$PRODUCTION_MODE" = true ]; then
        echo -e "${YELLOW}⚠️  IMPORTANT NEXT STEPS:${NC}"
        echo "   1. Configure broker API keys in .env file:"
        echo "      nano $INSTALL_DIR/.env"
        echo ""
        echo "   2. Start the system:"
        echo "      trading-bot start"
        echo ""
        if [ "$INSTALL_SSL" = true ]; then
            echo "   3. Access your trading bot:"
            echo "      🌐 https://$DOMAIN"
        else
            echo "   3. Access your trading bot:"
            echo "      🌐 http://$DOMAIN"
        fi
    else
        echo -e "${GREEN}🎯 Development Mode:${NC}"
        echo "   🌐 Frontend: http://localhost:3000"
        echo "   🔌 Backend API: http://localhost:5000"
        echo "   📊 System Status: http://localhost:5000/api/health"
    fi
    
    echo ""
    echo -e "${BLUE}📚 Additional Resources:${NC}"
    echo "   📖 Documentation: $INSTALL_DIR/docs/"
    echo "   🔧 Management: $INSTALL_DIR/manage.sh"
    echo "   📋 Logs: $INSTALL_DIR/logs/"
    echo "   🔍 Health Check: trading-bot health"
    
    echo ""
    echo -e "${GREEN}✅ QuantConnect Trading Bot is ready to use!${NC}"
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
    
    print_completion_message
}

# Run main function
main "$@"