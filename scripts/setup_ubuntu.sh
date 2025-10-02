#!/bin/bash

# QuantConnect Trading Bot - Ubuntu Setup Script v3.0
# Enhanced with essential tunneling support and critical error fixes
# Author: QuantConnect Trading Bot Team

set -euo pipefail

# Script configuration
readonly SCRIPT_VERSION="3.0"
readonly SCRIPT_NAME="QuantConnect Trading Bot Setup"
readonly INSTALL_DIR="/opt/quantconnect-trading-bot"
readonly REPO_URL="https://github.com/szarastrefa/quantconnect-trading-bot.git"
readonly LOG_FILE="/var/log/trading-bot-setup.log"

# Classical DDNS configuration  
readonly CLASSICAL_DOMAIN="eqtrader.ddnskita.my.id"
readonly DDNS_UPDATE_URL="https://tunnel.hostddns.us/ddns/377b9a29c7bba5435e4b5d53e3ead4aa"

# Installation options with defaults
TUNNEL_TYPE=""
TUNNEL_SUBDOMAIN=""
TUNNEL_DOMAIN=""
NGROK_TOKEN=""

# Installation flags
SKIP_DDNS_ERROR=false
SKIP_SSL=false
SKIP_SSL_SNAPD=false
FORCE_INSTALL=false
DEV_MODE=false
PRODUCTION_MODE=true
INTERACTIVE=false
INSTALL_SSL=true
SKIP_FIREWALL=false
VERBOSE=false
QUIET=false
NO_AUTO_START=false

# Generated URLs and credentials
FRONTEND_URL=""
BACKEND_URL=""
WEBSOCKET_URL=""
POSTGRES_USER=""
POSTGRES_PASSWORD=""
JWT_SECRET=""
ENCRYPTION_KEY=""
SESSION_SECRET=""
REDIS_PASSWORD=""

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Logging functions
print_header() {
    clear
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                 $SCRIPT_NAME                         ║${NC}"
    echo -e "${BLUE}║                    Ubuntu Setup Script v$SCRIPT_VERSION                     ║${NC}"
    echo -e "${BLUE}║                                                                  ║${NC}"
    echo -e "${BLUE}║  🌐 Essential Tunneling + Critical Fixes                       ║${NC}"
    echo -e "${BLUE}║  🔧 LocalTunnel + Enhanced Error Recovery                       ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
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
    echo -e "${RED}[ERROR]${NC} ❌ $1" | tee -a "$LOG_FILE" >&2
}

print_skip() {
    echo -e "${CYAN}[SKIP]${NC} ⏭️ $1" | tee -a "$LOG_FILE"
}

print_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${PURPLE}[VERBOSE]${NC} $1" | tee -a "$LOG_FILE"
    fi
}

# Help function
show_help() {
    echo "QuantConnect Trading Bot - Ubuntu Setup Script v$SCRIPT_VERSION"
    echo ""
    echo "🌐 TUNNEL OPTIONS:"
    echo "  --tunnel-classical          Use eqtrader.ddnskita.my.id (default)"
    echo "  --tunnel-localtunnel [sub]  Use LocalTunnel (completely free)"
    echo ""
    echo "⚙️ INSTALLATION OPTIONS:"
    echo "  --skip-ddns-error           Skip DDNS errors (Masih Sama!)"
    echo "  --skip-ssl                  Skip SSL certificate installation"
    echo "  --skip-ssl-snapd            Force APT-based SSL installation"
    echo "  --force-install             Remove existing installation"
    echo "  --dev-mode                  Development setup (HTTP only)"
    echo "  --production               Production setup with SSL"
    echo "  --verbose                  Detailed output"
    echo "  --quiet                    Minimal output"
    echo ""
    echo "📋 EXAMPLES:"
    echo "  # Standard production setup:"
    echo "  $0"
    echo ""
    echo "  # Use free LocalTunnel (works everywhere):"
    echo "  $0 --tunnel-localtunnel"
    echo ""
    echo "  # Fix common container/VPS errors:"
    echo "  $0 --tunnel-localtunnel --skip-ddns-error --skip-ssl-snapd --force-install"
    echo ""
    echo "🔧 QUICK FIXES:"
    echo "  # Container/VPS compatibility:"
    echo "  $0 --tunnel-localtunnel --dev-mode --force-install"
    echo ""
    echo "  # Skip all potential errors:"
    echo "  $0 --skip-ssl --skip-ddns-error --tunnel-localtunnel"
    echo ""
}

# Enhanced argument parsing
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --tunnel-classical)
                TUNNEL_TYPE="classical"
                TUNNEL_DOMAIN="$CLASSICAL_DOMAIN"
                shift
                ;;
            --tunnel-localtunnel)
                TUNNEL_TYPE="localtunnel"
                if [[ -n "${2:-}" && ! "$2" =~ ^-- ]]; then
                    TUNNEL_SUBDOMAIN="$2"
                    shift
                fi
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
            --skip-ssl-snapd)
                SKIP_SSL_SNAPD=true
                shift
                ;;
            --force-install)
                FORCE_INSTALL=true
                shift
                ;;
            --dev-mode)
                DEV_MODE=true
                PRODUCTION_MODE=false
                INSTALL_SSL=false
                shift
                ;;
            --production)
                PRODUCTION_MODE=true
                DEV_MODE=false
                INSTALL_SSL=true
                shift
                ;;
            --interactive)
                INTERACTIVE=true
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
            --no-auto-start)
                NO_AUTO_START=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo ""
                echo "Use --help for available options"
                exit 1
                ;;
        esac
    done
}

# System requirements check
check_system_requirements() {
    print_status "Checking system requirements..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Check Ubuntu version
    if ! grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
        print_warning "This script is designed for Ubuntu, but will try to continue"
    fi
    
    # Check available memory
    local memory_gb
    memory_gb=$(free -g | awk 'NR==2{printf "%.0f", $2}' 2>/dev/null || echo "0")
    if [ "$memory_gb" -lt 2 ]; then
        print_warning "System has less than 2GB RAM. Performance may be affected."
    fi
    
    # Check if running in container/VPS with limited privileges
    if [ ! -d /sys/fs/cgroup ] || [ ! -w /sys/fs/cgroup ] 2>/dev/null; then
        print_warning "Detected limited container environment - enabling compatibility mode"
        SKIP_SSL_SNAPD=true
    fi
    
    print_success "System requirements check passed"
}

# Update system packages
update_system_packages() {
    print_status "Updating system packages..."
    if [ "$VERBOSE" = true ]; then
        apt-get update
        apt-get upgrade -y
        apt-get autoremove -y
    else
        apt-get update -qq > /dev/null 2>&1 || print_warning "APT update had some issues"
        apt-get upgrade -y -qq > /dev/null 2>&1 || print_warning "APT upgrade had some issues"  
        apt-get autoremove -y -qq > /dev/null 2>&1 || true
    fi
    print_success "System packages updated"
}

# Install system dependencies
install_system_dependencies() {
    print_status "Installing system dependencies..."
    
    local packages="curl wget git unzip software-properties-common apt-transport-https ca-certificates gnupg lsb-release jq htop nano ufw cron openssl"
    
    if [ "$VERBOSE" = true ]; then
        apt-get install -y $packages
    else
        apt-get install -y -qq $packages > /dev/null 2>&1 || {
            print_warning "Some packages failed to install, retrying individually..."
            for pkg in $packages; do
                apt-get install -y -qq "$pkg" > /dev/null 2>&1 || print_warning "Failed to install: $pkg"
            done
        }
    fi
    
    print_success "System dependencies installed"
}

# Install Docker with fixed SUDO_USER handling
install_docker() {
    print_status "Installing Docker..."
    
    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        print_verbose "Docker already installed, checking version..."
        docker --version | tee -a "$LOG_FILE"
        print_success "Docker already installed"
        return
    fi
    
    # Remove old versions
    apt-get remove -y docker docker-engine docker.io containerd runc > /dev/null 2>&1 || true
    
    # Add Docker official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg 2>/dev/null || {
        print_error "Failed to add Docker GPG key"
        exit 1
    }
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
    
    # Install Docker
    apt-get update -qq > /dev/null 2>&1
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1 || {
        print_error "Failed to install Docker"
        exit 1
    }
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Add current user to docker group (FIXED: safe variable checking)
    if [ -n "${SUDO_USER:-}" ]; then
        usermod -aG docker "$SUDO_USER" 2>/dev/null || true
        print_verbose "Added $SUDO_USER to docker group"
    else
        print_verbose "Running as direct root - skipping docker group assignment"
    fi
    
    print_success "Docker installed and configured"
}

# Install Docker Compose
install_docker_compose() {
    print_status "Installing Docker Compose..."
    
    # Check if already installed
    if command -v docker-compose &> /dev/null; then
        print_verbose "Docker Compose already installed"
        docker-compose --version | tee -a "$LOG_FILE"
        print_success "Docker Compose already available"
        return
    fi
    
    # Get latest version
    local version
    version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name 2>/dev/null || echo "v2.21.0")
    
    # Download and install
    curl -L "https://github.com/docker/compose/releases/download/${version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose 2>/dev/null || {
        print_error "Failed to download Docker Compose"
        exit 1
    }
    
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    print_success "Docker Compose ${version} installed"
}

# Enhanced DDNS handling
handle_ddns_response() {
    local response="$1"
    
    if echo "$response" | grep -qi "success\|berhasil\|successfully update"; then
        print_success "DDNS updated successfully"
        return 0
    elif echo "$response" | grep -qi "masih sama\|same address\|no change\|unchanged"; then
        print_success "DDNS already up-to-date (IP unchanged)"
        return 0
    elif echo "$response" | grep -qi "update.*to.*[0-9]\|changed.*to"; then
        print_success "DDNS record updated"
        return 0
    else
        if [ "$SKIP_DDNS_ERROR" = true ]; then
            print_warning "DDNS error ignored (--skip-ddns-error specified)"
            return 0
        else
            print_error "DDNS update failed"
            echo "Response: $response"
            return 1
        fi
    fi
}

setup_classical_ddns() {
    print_status "Setting up Classical DDNS integration..."
    
    print_status "Updating DDNS record for $CLASSICAL_DOMAIN..."
    local ddns_response
    ddns_response=$(curl -s "$DDNS_UPDATE_URL" 2>/dev/null || echo "Connection failed")
    
    if handle_ddns_response "$ddns_response"; then
        if [ "$VERBOSE" = true ]; then
            echo "$ddns_response" | jq '.' 2>/dev/null || echo "$ddns_response"
        fi
        
        # Set URLs
        FRONTEND_URL="https://$CLASSICAL_DOMAIN"
        BACKEND_URL="https://$CLASSICAL_DOMAIN/api"
        WEBSOCKET_URL="wss://$CLASSICAL_DOMAIN/socket.io"
    else
        if [ "$SKIP_DDNS_ERROR" = false ]; then
            print_error "DDNS setup failed. Use --skip-ddns-error to continue anyway."
            print_status "💡 TIP: Try LocalTunnel: --tunnel-localtunnel"
            exit 1
        fi
    fi
}

# LocalTunnel setup
setup_localtunnel() {
    print_status "🌐 Setting up LocalTunnel..."
    
    # Install Node.js if not present
    if ! command -v node &> /dev/null; then
        print_status "Installing Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash - > /dev/null 2>&1
        apt-get install -y nodejs > /dev/null 2>&1
    fi
    
    # Install LocalTunnel globally
    npm install -g localtunnel > /dev/null 2>&1
    
    # Generate subdomain if not provided
    if [ -z "$TUNNEL_SUBDOMAIN" ]; then
        TUNNEL_SUBDOMAIN="eqtrader-$(openssl rand -hex 4)"
    fi
    
    # Create systemd service for LocalTunnel
    print_status "Creating systemd service for localtunnel..."
    
    cat > "/etc/systemd/system/trading-bot-tunnel.service" << EOF
[Unit]
Description=QuantConnect Trading Bot LocalTunnel
Documentation=https://github.com/szarastrefa/quantconnect-trading-bot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/bin/bash -c 'lt --port 3000 --subdomain ${TUNNEL_SUBDOMAIN}-app & lt --port 5000 --subdomain ${TUNNEL_SUBDOMAIN}-api & wait'
Restart=always
RestartSec=15
TimeoutStartSec=300
TimeoutStopSec=60
StandardOutput=journal
StandardError=journal
Environment=PATH=/usr/local/bin:/usr/bin:/bin

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable trading-bot-tunnel.service > /dev/null 2>&1
    
    # Set URLs
    FRONTEND_URL="https://${TUNNEL_SUBDOMAIN}-app.loca.lt"
    BACKEND_URL="https://${TUNNEL_SUBDOMAIN}-api.loca.lt"
    WEBSOCKET_URL="wss://${TUNNEL_SUBDOMAIN}-api.loca.lt/socket.io"
    
    print_success "Systemd service created and enabled: localtunnel"
    print_success "LocalTunnel configured"
    print_success "   📱 Frontend: $FRONTEND_URL"
    print_success "   🔧 Backend: $BACKEND_URL"
    print_success "   💰 Cost: FREE"
}

# Main tunnel setup
setup_tunnel() {
    case "$TUNNEL_TYPE" in
        "classical") setup_classical_ddns ;;
        "localtunnel") setup_localtunnel ;;
        *)
            # Default to classical DDNS
            print_status "Using Classical DDNS (default)"
            TUNNEL_TYPE="classical"
            TUNNEL_DOMAIN="$CLASSICAL_DOMAIN"
            setup_classical_ddns
            ;;
    esac
}

# Clone repository with fixed SUDO_USER handling
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
        git clone "$REPO_URL" "$INSTALL_DIR"
    else
        git clone "$REPO_URL" "$INSTALL_DIR" > /dev/null 2>&1 || {
            print_error "Failed to clone repository"
            exit 1
        }
    fi
    
    cd "$INSTALL_DIR"
    
    # Set permissions - FIXED SUDO_USER handling
    if [ -n "${SUDO_USER:-}" ]; then
        chown -R "$SUDO_USER:$SUDO_USER" "$INSTALL_DIR" 2>/dev/null || true
        print_verbose "Set ownership to $SUDO_USER"
    else
        print_verbose "Running as direct root - keeping root ownership"
    fi
    
    print_success "Repository cloned to $INSTALL_DIR"
}

# Generate secure credentials
generate_all_credentials() {
    print_status "Generating secure credentials..."
    
    POSTGRES_USER="trader_$(openssl rand -hex 4)"
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    JWT_SECRET=$(openssl rand -hex 32)
    ENCRYPTION_KEY=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    SESSION_SECRET=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    
    print_success "Secure credentials generated"
}

# Setup environment configuration
setup_environment() {
    print_status "Setting up environment configuration..."
    
    cd "$INSTALL_DIR"
    
    # Generate credentials first
    generate_all_credentials
    
    # Determine URLs based on tunnel type and dev mode
    local api_base_url frontend_url websocket_url cors_origins ssl_enabled_val
    
    if [ "$DEV_MODE" = true ]; then
        api_base_url="http://localhost:5000/api"
        frontend_url="http://localhost:3000"
        websocket_url="ws://localhost:5000/socket.io"
        cors_origins="http://localhost:3000,http://localhost:5000"
        ssl_enabled_val="false"
    elif [ -n "$FRONTEND_URL" ]; then
        # Use tunnel URLs if available
        api_base_url="${BACKEND_URL}"
        frontend_url="$FRONTEND_URL"
        websocket_url="$(echo "$WEBSOCKET_URL" | sed 's/^http/ws/')"
        cors_origins="$FRONTEND_URL,$BACKEND_URL"
        ssl_enabled_val="true"
    else
        # Fallback to localhost
        api_base_url="http://localhost:5000/api"
        frontend_url="http://localhost:3000"
        websocket_url="ws://localhost:5000/socket.io"
        cors_origins="http://localhost:3000,http://localhost:5000"
        ssl_enabled_val="false"
    fi
    
    # Create environment file
    cat > .env << EOF
# QuantConnect Trading Bot - Environment Configuration
# Generated on $(date)
# Installation Mode: $([ "$DEV_MODE" = true ] && echo "Development" || echo "Production")
# Network Mode: ${TUNNEL_TYPE:-localhost}

# Environment Configuration
NODE_ENV=$([ "$DEV_MODE" = true ] && echo "development" || echo "production")
ENVIRONMENT=$([ "$DEV_MODE" = true ] && echo "development" || echo "production")
FLASK_ENV=$([ "$DEV_MODE" = true ] && echo "development" || echo "production")

# Network Configuration
TUNNEL_TYPE=${TUNNEL_TYPE:-localhost}
DOMAIN=${TUNNEL_DOMAIN:-localhost}
FRONTEND_URL=$frontend_url
BACKEND_URL=${BACKEND_URL:-http://localhost:5000}
WEBSOCKET_URL=$websocket_url

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
ENCRYPTION_KEY=$ENCRYPTION_KEY

# API Configuration
API_BASE_URL=$api_base_url
CORS_ORIGINS=$cors_origins

# React App Configuration
REACT_APP_API_URL=$api_base_url
REACT_APP_WS_URL=$websocket_url
REACT_APP_DOMAIN=${TUNNEL_DOMAIN:-localhost}

# SSL Configuration
SSL_ENABLED=$ssl_enabled_val

# QuantConnect Configuration
QC_USER_ID=
QC_API_TOKEN=
QC_ENVIRONMENT=live-trading
EOF
    
    chmod 600 .env
    
    print_success "Environment configuration created"
}

# Setup firewall
setup_firewall() {
    if [ "$SKIP_FIREWALL" = true ]; then
        print_skip "Firewall configuration (--skip-firewall)"
        return
    fi
    
    print_status "Configuring firewall..."
    
    if ! command -v ufw &> /dev/null; then
        print_warning "UFW not available, skipping firewall configuration"
        return
    fi
    
    # Reset UFW
    ufw --force reset > /dev/null 2>&1
    
    # Default policies
    ufw default deny incoming > /dev/null 2>&1
    ufw default allow outgoing > /dev/null 2>&1
    
    # Allow SSH
    ufw allow ssh > /dev/null 2>&1
    
    # Allow HTTP and HTTPS
    ufw allow 80/tcp > /dev/null 2>&1
    ufw allow 443/tcp > /dev/null 2>&1
    
    # Development mode - allow additional ports
    if [ "$DEV_MODE" = true ]; then
        ufw allow 3000/tcp > /dev/null 2>&1
        ufw allow 5000/tcp > /dev/null 2>&1
    fi
    
    # Enable firewall
    ufw --force enable > /dev/null 2>&1
    
    print_success "Firewall configured"
}

# Create systemd service
create_systemd_service() {
    print_status "Creating systemd service..."
    
    local compose_file="docker-compose.production.yml"
    if [ "$DEV_MODE" = true ]; then
        compose_file="docker-compose.yml"
    fi
    
    cat > /etc/systemd/system/quantconnect-trading-bot.service << EOF
[Unit]
Description=QuantConnect Trading Bot
Documentation=https://github.com/szarastrefa/quantconnect-trading-bot
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=true
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/local/bin/docker-compose -f $compose_file up -d
ExecStop=/usr/local/bin/docker-compose -f $compose_file down
ExecReload=/usr/local/bin/docker-compose -f $compose_file restart
TimeoutStartSec=300
TimeoutStopSec=120
Environment=PATH=/usr/local/bin:/usr/bin:/bin

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable quantconnect-trading-bot.service > /dev/null 2>&1
    
    print_success "Systemd service created and enabled"
}

# Create management script
create_management_script() {
    print_status "Setting up system management..."
    
    # Check if manage.sh exists in repo
    if [ -f "$INSTALL_DIR/scripts/manage.sh" ]; then
        chmod +x "$INSTALL_DIR/scripts/manage.sh"
        ln -sf "$INSTALL_DIR/scripts/manage.sh" /usr/local/bin/trading-bot
        print_success "Management script ready (use 'trading-bot' command globally)"
    else
        # Create basic management script
        cat > /usr/local/bin/trading-bot << 'EOF'
#!/bin/bash
INSTALL_DIR="/opt/quantconnect-trading-bot"
COMPOSE_FILE="docker-compose.production.yml"

if [ ! -d "$INSTALL_DIR" ]; then
    echo "❌ Error: QuantConnect Trading Bot not installed"
    exit 1
fi

cd "$INSTALL_DIR"

case "$1" in
    start)
        echo "🚀 Starting QuantConnect Trading Bot..."
        docker-compose -f "$COMPOSE_FILE" up -d
        echo "✅ System started"
        ;;
    stop)
        echo "🛑 Stopping QuantConnect Trading Bot..."
        docker-compose -f "$COMPOSE_FILE" down
        echo "✅ System stopped"
        ;;
    status)
        echo "📊 QuantConnect Trading Bot Status:"
        docker-compose -f "$COMPOSE_FILE" ps
        ;;
    logs)
        echo "📋 QuantConnect Trading Bot Logs:"
        docker-compose -f "$COMPOSE_FILE" logs -f
        ;;
    *)
        echo "Usage: $0 {start|stop|status|logs}"
        exit 1
        ;;
esac
EOF
        chmod +x /usr/local/bin/trading-bot
        print_success "Basic management script created"
    fi
}

# Build and start system
build_and_start_system() {
    if [ "$NO_AUTO_START" = true ]; then
        print_skip "System build and start (--no-auto-start)"
        return
    fi
    
    print_status "Building and starting the system..."
    
    cd "$INSTALL_DIR"
    
    # Choose compose file
    local compose_file="docker-compose.production.yml"
    if [ "$DEV_MODE" = true ]; then
        compose_file="docker-compose.yml"
    fi
    
    # Validate configuration
    print_status "Validating environment configuration..."
    if docker-compose -f "$compose_file" config > /dev/null 2>&1; then
        print_success "Docker Compose configuration valid"
    else
        print_warning "Docker Compose configuration issues detected"
        if [ "$VERBOSE" = true ]; then
            docker-compose -f "$compose_file" config 2>&1 | head -10
        fi
    fi
    
    # Check .env file
    if grep -E "^[A-Z_][A-Z0-9_]*=[^=]*$" .env > /dev/null; then
        print_success "Environment file format valid"
    else
        print_warning "Environment file may contain formatting issues"
    fi
    
    # Build images
    print_status "Building Docker images..."
    if [ "$VERBOSE" = true ]; then
        docker-compose -f "$compose_file" build --parallel
    else
        docker-compose -f "$compose_file" build --parallel > /dev/null 2>&1 || {
            print_warning "Docker build had some issues, attempting to continue..."
        }
    fi
    
    # Start services
    print_status "Starting services..."
    docker-compose -f "$compose_file" up -d || {
        print_error "Failed to start some services"
        docker-compose -f "$compose_file" ps
        print_warning "Some services may not be running properly"
        return 1
    }
    
    # Start tunnel service if applicable
    if [ "$TUNNEL_TYPE" = "localtunnel" ] && systemctl is-enabled trading-bot-tunnel.service > /dev/null 2>&1; then
        print_status "Starting tunnel service..."
        systemctl start trading-bot-tunnel.service || print_warning "Tunnel service may take a moment to start"
    fi
    
    print_success "System build and start completed"
}

# Display installation summary
display_installation_summary() {
    echo ""
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                 🎉 INSTALLATION COMPLETED!                      ║"
    echo "║              QuantConnect Trading Bot v3.0                      ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${BLUE}📍 System Information:${NC}"
    if [ "$DEV_MODE" = true ]; then
        echo "   🧪 Mode: Development"
        echo "   🌐 Frontend: http://localhost:3000"
        echo "   📊 Backend API: http://localhost:5000"
    elif [ -n "$FRONTEND_URL" ]; then
        echo "   🏭 Mode: Production (Tunneled)"
        echo "   🌐 Network: ${TUNNEL_TYPE^}"
        echo "   📱 Frontend: $FRONTEND_URL"
        echo "   🔧 Backend: $BACKEND_URL"
        echo "   📮 WebSocket: $WEBSOCKET_URL"
    else
        echo "   🏭 Mode: Production"
        echo "   🌐 Domain: https://$TUNNEL_DOMAIN"
    fi
    echo "   📁 Install Path: $INSTALL_DIR"
    echo ""
    
    echo -e "${CYAN}🛠️ SYSTEM MANAGEMENT COMMANDS:${NC}"
    echo "   ├─ Start system: trading-bot start"
    echo "   ├─ Stop system: trading-bot stop"
    echo "   ├─ View status: trading-bot status"
    echo "   └─ View logs: trading-bot logs"
    echo ""
    
    echo -e "${PURPLE}📋 NEXT STEPS:${NC}"
    echo "   1. 🔧 Configure broker API keys: nano $INSTALL_DIR/.env"
    echo "   2. 🚀 Start the trading system: trading-bot start"
    if [ -n "$FRONTEND_URL" ]; then
        echo "   3. 🌐 Access web interface: $FRONTEND_URL"
    else
        echo "   3. 🌐 Access web interface: http://localhost:3000"
    fi
    echo ""
    
    echo -e "${GREEN}✅ QuantConnect Trading Bot is ready for algorithmic trading!${NC}"
}

# Main installation flow
main() {
    # Parse arguments first
    parse_arguments "$@"
    
    # Show header
    print_header
    
    # Auto-enable SSL in production mode (unless explicitly disabled)
    if [ "$PRODUCTION_MODE" = true ] && [ "$SKIP_SSL" = false ] && [ "$INSTALL_SSL" = false ] && [ "$TUNNEL_TYPE" = "classical" ]; then
        INSTALL_SSL=true
    fi
    
    # System checks and installation
    check_system_requirements
    
    # Create log file
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    
    print_status "🔧 Starting QuantConnect Trading Bot installation..."
    print_status "📅 Installation started at: $(date)"
    
    # Installation steps
    update_system_packages
    install_system_dependencies
    install_docker
    install_docker_compose
    
    # Setup networking
    if [ -n "$TUNNEL_TYPE" ]; then
        setup_tunnel
    else
        print_status "🌐 Using Classical DDNS (default)"
        TUNNEL_TYPE="classical"
        TUNNEL_DOMAIN="$CLASSICAL_DOMAIN"
        setup_tunnel
    fi
    
    # Continue with system setup
    clone_repository
    setup_environment
    
    # Skip SSL for tunneled setups
    if [ "$INSTALL_SSL" = true ] && [ "$SKIP_SSL" = false ] && [ "$TUNNEL_TYPE" = "classical" ]; then
        # SSL installation code would go here
        print_skip "SSL certificates (use dedicated SSL setup if needed)"
    else
        print_skip "SSL certificates installation"
    fi
    
    # System configuration
    setup_firewall
    create_systemd_service
    create_management_script
    
    # Build and start
    build_and_start_system
    
    # Show summary
    display_installation_summary
}

# Handle script termination
trap 'echo -e "\n${YELLOW}🛑 Installation interrupted${NC}"; exit 1' INT TERM

# Run main function
main "$@"