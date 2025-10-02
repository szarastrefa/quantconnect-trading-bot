#!/bin/bash

# QuantConnect Trading Bot - Ubuntu Setup Script v3.0
# Enhanced with comprehensive tunneling support and error recovery
# Supports 7 professional tunneling platforms + classical DDNS
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
TUNNEL_TOKEN=""
NGROK_TOKEN=""
CLOUDFLARE_DOMAIN=""
PAGEKITE_NAME=""
TELEBIT_SECRET=""

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
SKIP_DEPENDENCIES=false
SKIP_DOCKER_CHECK=false
SKIP_SYSTEM_UPDATE=false
SKIP_NGINX=false
VERBOSE=false
QUIET=false
NO_AUTO_START=false
SHOW_TUNNEL_MENU=false

# Generated URLs and credentials
FRONTEND_URL=""
BACKEND_URL=""
WEBSOCKET_URL=""
DASHBOARD_URL=""
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
    echo -e "${BLUE}║  🌐 7 Professional Tunneling Platforms                       ║${NC}"
    echo -e "${BLUE}║  🔧 Enhanced SSL + Error Recovery                               ║${NC}"
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

# Comprehensive tunnel selection menu
show_tunnel_menu() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    🌐 SELECT TUNNEL PLATFORM                    ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Choose your preferred tunneling solution:${NC}"
    echo ""
    echo -e "1. 🏠 ${GREEN}Classical DDNS${NC} (eqtrader.ddnskita.my.id)     ${CYAN}[STABLE]${NC}"
    echo -e "   • Dedicated domain with auto-DDNS updates"
    echo -e "   • SSL certificates, professional setup"
    echo -e "   • Best for: Production deployments"
    echo ""
    echo -e "2. 🚀 ${GREEN}Ngrok Professional${NC} (ngrok.io)              ${CYAN}[POPULAR]${NC}"
    echo -e "   • Custom subdomains, enterprise features"
    echo -e "   • Real-time dashboard, traffic inspection"
    echo -e "   • Best for: Development and professional use"
    echo ""
    echo -e "3. 🌐 ${GREEN}LocalTunnel${NC} (loca.lt)                      ${CYAN}[FREE]${NC}"
    echo -e "   • Completely free, zero-configuration"
    echo -e "   • No account required, instant setup"
    echo -e "   • Best for: Quick testing and demos"
    echo ""
    echo -e "4. 🔒 ${GREEN}Serveo SSH${NC} (serveo.net)                    ${CYAN}[SIMPLE]${NC}"
    echo -e "   • SSH-based tunneling, no installation"
    echo -e "   • Works anywhere SSH is available"
    echo -e "   • Best for: Minimal setups and SSH experts"
    echo ""
    echo -e "5. ☁️ ${GREEN}Cloudflare Tunnel${NC} (cloudflare.com)         ${CYAN}[ENTERPRISE]${NC}"
    echo -e "   • Enterprise-grade with DDoS protection"
    echo -e "   • Global CDN, zero-trust security"
    echo -e "   • Best for: High-traffic production systems"
    echo ""
    echo -e "6. 🎪 ${GREEN}PageKite${NC} (pagekite.net)                   ${CYAN}[COMMERCIAL]${NC}"
    echo -e "   • Commercial tunneling with custom domains"
    echo -e "   • Reliable, paid service with support"
    echo -e "   • Best for: Commercial applications"
    echo ""
    echo -e "7. 🔧 ${GREEN}Telebit${NC} (telebit.cloud)                   ${CYAN}[MODERN]${NC}"
    echo -e "   • Modern P2P tunneling technology"
    echo -e "   • End-to-end encryption, decentralized"
    echo -e "   • Best for: Privacy-focused deployments"
    echo ""
    read -p "Enter your choice [1-7]: " tunnel_choice
    
    case $tunnel_choice in
        1) 
            TUNNEL_TYPE="classical"
            TUNNEL_DOMAIN="$CLASSICAL_DOMAIN"
            print_success "Selected: Classical DDNS ($CLASSICAL_DOMAIN)"
            ;;
        2) 
            TUNNEL_TYPE="ngrok"
            echo ""
            echo -e "${CYAN}Ngrok Professional Setup${NC}"
            echo "Get your auth token from: https://dashboard.ngrok.com/get-started/your-authtoken"
            echo ""
            read -p "Enter your Ngrok auth token: " NGROK_TOKEN
            if [ -z "$NGROK_TOKEN" ]; then
                print_error "Ngrok token is required!"
                exit 1
            fi
            read -p "Custom subdomain (leave empty for eqtrader): " custom_sub
            if [ -n "$custom_sub" ]; then
                TUNNEL_SUBDOMAIN="$custom_sub"
            else
                TUNNEL_SUBDOMAIN="eqtrader"
            fi
            print_success "Selected: Ngrok Professional (${TUNNEL_SUBDOMAIN}-app.ngrok.io)"
            ;;
        3) 
            TUNNEL_TYPE="localtunnel"
            echo ""
            echo -e "${CYAN}LocalTunnel Setup${NC}"
            read -p "Custom subdomain (leave empty for random): " TUNNEL_SUBDOMAIN
            if [ -z "$TUNNEL_SUBDOMAIN" ]; then
                TUNNEL_SUBDOMAIN="eqtrader-$(openssl rand -hex 4)"
            fi
            print_success "Selected: LocalTunnel (${TUNNEL_SUBDOMAIN}-app.loca.lt)"
            ;;
        4) 
            TUNNEL_TYPE="serveo"
            echo ""
            echo -e "${CYAN}Serveo SSH Tunneling Setup${NC}"
            read -p "Custom subdomain (leave empty for random): " TUNNEL_SUBDOMAIN
            if [ -z "$TUNNEL_SUBDOMAIN" ]; then
                TUNNEL_SUBDOMAIN="eqtrader-$(openssl rand -hex 4)"
            fi
            print_success "Selected: Serveo SSH Tunneling (${TUNNEL_SUBDOMAIN}-app.serveo.net)"
            ;;
        5) 
            TUNNEL_TYPE="cloudflare"
            echo ""
            echo -e "${CYAN}Cloudflare Tunnel Setup${NC}"
            echo "You need a domain managed by Cloudflare for this option."
            echo ""
            read -p "Enter your domain (e.g., yourdomain.com): " CLOUDFLARE_DOMAIN
            if [ -z "$CLOUDFLARE_DOMAIN" ]; then
                print_error "Domain is required for Cloudflare Tunnel!"
                exit 1
            fi
            print_success "Selected: Cloudflare Tunnel (app.${CLOUDFLARE_DOMAIN})"
            ;;
        6) 
            TUNNEL_TYPE="pagekite"
            echo ""
            echo -e "${CYAN}PageKite Commercial Tunneling${NC}"
            echo "PageKite requires a paid account. Sign up at: https://pagekite.net/"
            echo ""
            read -p "Enter your PageKite name: " PAGEKITE_NAME
            if [ -z "$PAGEKITE_NAME" ]; then
                print_error "PageKite name is required!"
                exit 1
            fi
            print_success "Selected: PageKite Commercial (${PAGEKITE_NAME}.pagekite.me)"
            ;;
        7) 
            TUNNEL_TYPE="telebit"
            echo ""
            echo -e "${CYAN}Telebit Modern Tunneling${NC}"
            echo "Generate a secret key for secure tunneling."
            echo ""
            read -p "Enter Telebit secret (leave empty to generate): " TELEBIT_SECRET
            if [ -z "$TELEBIT_SECRET" ]; then
                TELEBIT_SECRET=$(openssl rand -hex 32)
                echo "Generated secret: $TELEBIT_SECRET"
            fi
            TUNNEL_SUBDOMAIN="eqtrader-$(openssl rand -hex 4)"
            print_success "Selected: Telebit Modern Tunneling (${TUNNEL_SUBDOMAIN}.telebit.cloud)"
            ;;
        *) 
            print_warning "Invalid choice. Using Classical DDNS as default."
            TUNNEL_TYPE="classical"
            TUNNEL_DOMAIN="$CLASSICAL_DOMAIN"
            ;;
    esac
    echo ""
}

# Help function with comprehensive examples
show_help() {
    echo "QuantConnect Trading Bot - Ubuntu Setup Script v$SCRIPT_VERSION"
    echo ""
    echo "🌐 TUNNEL OPTIONS:"
    echo "  --tunnel-classical          Use eqtrader.ddnskita.my.id (default)"
    echo "  --tunnel-ngrok [token]      Use Ngrok professional tunneling"
    echo "  --tunnel-localtunnel [sub]  Use LocalTunnel (completely free)"
    echo "  --tunnel-serveo [subdomain] Use Serveo SSH tunneling"
    echo "  --tunnel-cloudflare [domain] Use Cloudflare Tunnel"
    echo "  --tunnel-pagekite [name]    Use PageKite commercial tunneling"
    echo "  --tunnel-telebit [secret]   Use Telebit P2P tunneling"
    echo "  --interactive-tunnel        Show interactive tunnel selection menu"
    echo ""
    echo "⚙️ INSTALLATION OPTIONS:"
    echo "  --skip-ddns-error           Skip DDNS errors (Masih Sama!)"
    echo "  --skip-ssl                  Skip SSL certificate installation"
    echo "  --skip-ssl-snapd            Force APT-based SSL installation"
    echo "  --force-install             Remove existing installation"
    echo "  --dev-mode                  Development setup (HTTP only)"
    echo "  --production               Production setup with SSL"
    echo "  --interactive              Interactive mode"
    echo "  --verbose                  Detailed output"
    echo "  --quiet                    Minimal output"
    echo ""
    echo "📋 EXAMPLES:"
    echo "  # Interactive tunnel menu:"
    echo "  $0"
    echo ""
    echo "  # Fix VPS/container SSL snapd errors:"
    echo "  $0 --skip-ssl-snapd --skip-ddns-error"
    echo ""
    echo "  # Use free LocalTunnel (works everywhere):"
    echo "  $0 --tunnel-localtunnel"
    echo ""
    echo "  # Professional Ngrok setup:"
    echo "  $0 --tunnel-ngrok your_token_here"
    echo ""
    echo "  # Cloudflare Enterprise:"
    echo "  $0 --tunnel-cloudflare yourdomain.com"
    echo ""
    echo "🔧 QUICK FIXES:"
    echo "  # Container/VPS compatibility:"
    echo "  $0 --tunnel-localtunnel --dev-mode --force-install"
    echo ""
    echo "  # Skip common errors:"
    echo "  $0 --skip-ssl --skip-ddns-error --tunnel-serveo"
    echo ""
}

# Enhanced argument parsing with all tunnel options
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            # Tunnel options
            --tunnel-classical)
                TUNNEL_TYPE="classical"
                TUNNEL_DOMAIN="$CLASSICAL_DOMAIN"
                shift
                ;;
            --tunnel-ngrok)
                TUNNEL_TYPE="ngrok"
                if [[ -n "${2:-}" && ! "$2" =~ ^-- ]]; then
                    NGROK_TOKEN="$2"
                    shift
                fi
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
            --tunnel-serveo)
                TUNNEL_TYPE="serveo"
                if [[ -n "${2:-}" && ! "$2" =~ ^-- ]]; then
                    TUNNEL_SUBDOMAIN="$2"
                    shift
                fi
                shift
                ;;
            --tunnel-cloudflare)
                TUNNEL_TYPE="cloudflare"
                if [[ -n "${2:-}" && ! "$2" =~ ^-- ]]; then
                    CLOUDFLARE_DOMAIN="$2"
                    shift
                fi
                shift
                ;;
            --tunnel-pagekite)
                TUNNEL_TYPE="pagekite"
                if [[ -n "${2:-}" && ! "$2" =~ ^-- ]]; then
                    PAGEKITE_NAME="$2"
                    shift
                fi
                shift
                ;;
            --tunnel-telebit)
                TUNNEL_TYPE="telebit"
                if [[ -n "${2:-}" && ! "$2" =~ ^-- ]]; then
                    TELEBIT_SECRET="$2"
                    shift
                fi
                shift
                ;;
            --interactive-tunnel)
                SHOW_TUNNEL_MENU=true
                shift
                ;;
            
            # Skip options
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
            --skip-firewall)
                SKIP_FIREWALL=true
                shift
                ;;
            --skip-dependencies)
                SKIP_DEPENDENCIES=true
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
            
            # Installation modes
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
            
            # Help
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

# System requirements check with container detection
check_system_requirements() {
    if [ "$SKIP_SYSTEM_UPDATE" = true ]; then
        print_skip "System requirements check (--skip-system-update)"
        return
    fi
    
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
    
    # Check available disk space
    local disk_space_gb
    disk_space_gb=$(df / | awk 'NR==2 {printf "%.0f", $4/1024/1024}' 2>/dev/null || echo "0")
    if [ "$disk_space_gb" -lt 5 ]; then
        print_warning "Less than 5GB free disk space available."
        if [ "$FORCE_INSTALL" = false ]; then
            print_error "Use --force-install to continue anyway"
            exit 1
        fi
    fi
    
    # Check if running in container/VPS with limited privileges
    if [ ! -d /sys/fs/cgroup ] || [ ! -w /sys/fs/cgroup ] 2>/dev/null; then
        print_warning "Detected limited container environment - enabling compatibility mode"
        SKIP_SSL_SNAPD=true
    fi
    
    print_success "System requirements check passed"
}

# Update system packages with better error handling
update_system_packages() {
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
        apt-get update -qq > /dev/null 2>&1 || print_warning "APT update had some issues"
        apt-get upgrade -y -qq > /dev/null 2>&1 || print_warning "APT upgrade had some issues"
        apt-get autoremove -y -qq > /dev/null 2>&1 || true
    fi
    print_success "System packages updated"
}

# Install system dependencies with fallback handling
install_system_dependencies() {
    if [ "$SKIP_DEPENDENCIES" = true ]; then
        print_skip "Dependencies installation (--skip-deps)"
        return
    fi
    
    print_status "Installing system dependencies..."
    
    # Essential packages list
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

# Install Docker with version checking and fixed SUDO_USER handling
install_docker() {
    if [ "$SKIP_DOCKER_CHECK" = true ]; then
        print_skip "Docker installation (--skip-docker-check)"
        return
    fi
    
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
    
    # Add current user to docker group (if not running as direct root)
    # Fixed: Check if SUDO_USER exists and is not empty before using it
    if [ -n "${SUDO_USER:-}" ]; then
        usermod -aG docker "$SUDO_USER" 2>/dev/null || true
        print_verbose "Added $SUDO_USER to docker group"
    else
        print_verbose "Running as direct root - skipping docker group assignment"
    fi
    
    print_success "Docker installed and configured"
}

# Install Docker Compose with latest version
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
    
    # Create symlink
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    print_success "Docker Compose ${version} installed"
}

# Enhanced DDNS setup with comprehensive error handling
handle_ddns_response() {
    local response="$1"
    
    # Handle all success cases including Indonesian responses
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
        # Unknown response
        if [ "$SKIP_DDNS_ERROR" = true ]; then
            print_warning "DDNS error ignored (--skip-ddns-error specified)"
            print_verbose "DDNS Response: $response"
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
    
    # Update DDNS record
    print_status "Updating DDNS record for $CLASSICAL_DOMAIN..."
    local ddns_response
    ddns_response=$(curl -s "$DDNS_UPDATE_URL" 2>/dev/null || echo "Connection failed")
    
    if handle_ddns_response "$ddns_response"; then
        # Display response for debugging if verbose
        if [ "$VERBOSE" = true ]; then
            echo "$ddns_response" | jq '.' 2>/dev/null || echo "$ddns_response"
        fi
        
        # Get current IP
        local current_ip
        current_ip=$(echo "$ddns_response" | jq -r '.message' 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 || curl -s ifconfig.me 2>/dev/null || echo "unknown")
        if [ "$current_ip" != "unknown" ]; then
            print_status "Current IP: $current_ip"
        fi
        
        # Setup automatic updates
        setup_ddns_cron
        
        # Set URLs
        FRONTEND_URL="https://$CLASSICAL_DOMAIN"
        BACKEND_URL="https://$CLASSICAL_DOMAIN/api"
        WEBSOCKET_URL="wss://$CLASSICAL_DOMAIN/socket.io"
        
    else
        if [ "$SKIP_DDNS_ERROR" = false ]; then
            print_error "DDNS setup failed. Use --skip-ddns-error to continue anyway."
            print_status "💡 TIP: Try a tunnel: --tunnel-localtunnel"
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
if echo "\$RESPONSE" | grep -qi "success\|berhasil\|masih sama\|update\|unchanged"; then
    logger "DDNS check completed for $CLASSICAL_DOMAIN"
else
    logger "DDNS update may have failed for $CLASSICAL_DOMAIN: \$RESPONSE"
fi
EOF
    
    chmod +x /usr/local/bin/update-ddns.sh
    
    # Add to crontab (every 5 minutes)
    (crontab -l 2>/dev/null || echo "") | grep -v update-ddns.sh > /tmp/cron_tmp || true
    echo "*/5 * * * * /usr/local/bin/update-ddns.sh >/dev/null 2>&1" >> /tmp/cron_tmp
    crontab /tmp/cron_tmp
    rm -f /tmp/cron_tmp
    
    print_success "DDNS auto-update configured (every 5 minutes)"
}

# Individual tunnel setup functions
setup_ngrok_tunnel() {
    print_status "🚀 Setting up Ngrok tunnel..."
    
    # Install ngrok
    if ! command -v ngrok &> /dev/null; then
        print_status "Installing Ngrok..."
        curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | gpg --dearmor -o /etc/apt/keyrings/ngrok.gpg 2>/dev/null || {
            print_error "Failed to add Ngrok GPG key"
            exit 1
        }
        echo "deb [signed-by=/etc/apt/keyrings/ngrok.gpg] https://ngrok-agent.s3.amazonaws.com buster main" > /etc/apt/sources.list.d/ngrok.list
        apt-get update -qq && apt-get install -y ngrok > /dev/null 2>&1
    fi
    
    # Configure auth token
    if [ -z "$NGROK_TOKEN" ]; then
        if [ "$INTERACTIVE" = true ]; then
            read -p "Enter your Ngrok auth token: " NGROK_TOKEN
        else
            print_error "Ngrok token required. Get from: https://dashboard.ngrok.com/"
            exit 1
        fi
    fi
    
    ngrok config add-authtoken "$NGROK_TOKEN" > /dev/null 2>&1
    
    # Setup default subdomain if not provided
    if [ -z "$TUNNEL_SUBDOMAIN" ]; then
        TUNNEL_SUBDOMAIN="eqtrader"
    fi
    
    # Setup tunnels configuration
    mkdir -p ~/.ngrok2
    cat > ~/.ngrok2/ngrok.yml << EOF
version: "2"
authtoken: $NGROK_TOKEN
tunnels:
  frontend:
    addr: 3000
    proto: http
    subdomain: ${TUNNEL_SUBDOMAIN}-app
  backend:
    addr: 5000
    proto: http
    subdomain: ${TUNNEL_SUBDOMAIN}-api
EOF
    
    # Create systemd service for ngrok
    create_tunnel_service "ngrok" "ngrok start --all --config ~/.ngrok2/ngrok.yml"
    
    # Set URLs
    FRONTEND_URL="https://${TUNNEL_SUBDOMAIN}-app.ngrok.io"
    BACKEND_URL="https://${TUNNEL_SUBDOMAIN}-api.ngrok.io"
    WEBSOCKET_URL="wss://${TUNNEL_SUBDOMAIN}-api.ngrok.io/socket.io"
    DASHBOARD_URL="http://localhost:4040"
    
    print_success "Ngrok tunnel configured"
    print_success "   📱 Frontend: $FRONTEND_URL"
    print_success "   🔧 Backend: $BACKEND_URL"
    print_success "   📊 Dashboard: $DASHBOARD_URL"
}

setup_localtunnel() {
    print_status "🌐 Setting up LocalTunnel..."
    
    # Install Node.js if not present
    if ! command -v node &> /dev/null; then
        print_status "Installing Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash - > /dev/null 2>&1
        apt-get install -y nodejs > /dev/null 2>&1
    fi
    
    # Install LocalTunnel
    npm install -g localtunnel > /dev/null 2>&1
    
    # Generate subdomain if not provided
    if [ -z "$TUNNEL_SUBDOMAIN" ]; then
        TUNNEL_SUBDOMAIN="eqtrader-$(openssl rand -hex 4)"
    fi
    
    # Create systemd service
    create_tunnel_service "localtunnel" "lt --port 3000 --subdomain ${TUNNEL_SUBDOMAIN}-app & lt --port 5000 --subdomain ${TUNNEL_SUBDOMAIN}-api & wait"
    
    # Set URLs
    FRONTEND_URL="https://${TUNNEL_SUBDOMAIN}-app.loca.lt"
    BACKEND_URL="https://${TUNNEL_SUBDOMAIN}-api.loca.lt"
    WEBSOCKET_URL="wss://${TUNNEL_SUBDOMAIN}-api.loca.lt/socket.io"
    
    print_success "LocalTunnel configured"
    print_success "   📱 Frontend: $FRONTEND_URL"
    print_success "   🔧 Backend: $BACKEND_URL"
    print_success "   💰 Cost: FREE"
}

setup_serveo_tunnel() {
    print_status "🔒 Setting up Serveo SSH tunnel..."
    
    # Generate subdomain if not provided
    if [ -z "$TUNNEL_SUBDOMAIN" ]; then
        TUNNEL_SUBDOMAIN="eqtrader-$(openssl rand -hex 4)"
    fi
    
    # Create systemd service
    create_tunnel_service "serveo" "ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=60 -R ${TUNNEL_SUBDOMAIN}-app:80:localhost:3000 serveo.net & ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=60 -R ${TUNNEL_SUBDOMAIN}-api:80:localhost:5000 serveo.net & wait"
    
    # Set URLs
    FRONTEND_URL="https://${TUNNEL_SUBDOMAIN}-app.serveo.net"
    BACKEND_URL="https://${TUNNEL_SUBDOMAIN}-api.serveo.net"
    WEBSOCKET_URL="wss://${TUNNEL_SUBDOMAIN}-api.serveo.net/socket.io"
    
    print_success "Serveo tunnel configured"
    print_success "   📱 Frontend: $FRONTEND_URL"
    print_success "   🔧 Backend: $BACKEND_URL"
    print_success "   🔐 Protocol: SSH forwarding"
}

setup_cloudflare_tunnel() {
    print_status "☁️ Setting up Cloudflare Tunnel..."
    
    # Install cloudflared
    if ! command -v cloudflared &> /dev/null; then
        print_status "Installing cloudflared..."
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -O /tmp/cloudflared.deb || {
            print_error "Failed to download cloudflared"
            exit 1
        }
        dpkg -i /tmp/cloudflared.deb > /dev/null 2>&1
        rm -f /tmp/cloudflared.deb
    fi
    
    # Get domain if not provided
    if [ -z "$CLOUDFLARE_DOMAIN" ]; then
        if [ "$INTERACTIVE" = true ]; then
            read -p "Enter your Cloudflare domain: " CLOUDFLARE_DOMAIN
        else
            print_error "Cloudflare domain required for tunnel setup"
            exit 1
        fi
    fi
    
    print_status "Please login to your Cloudflare account when prompted..."
    cloudflared tunnel login || {
        print_error "Cloudflare login failed"
        exit 1
    }
    
    # Create tunnel
    local tunnel_name="eqtrader-$(openssl rand -hex 4)"
    cloudflared tunnel create "$tunnel_name" > /dev/null 2>&1 || {
        print_error "Failed to create Cloudflare tunnel"
        exit 1
    }
    
    # Get tunnel UUID
    local tunnel_uuid
    tunnel_uuid=$(cloudflared tunnel list | grep "$tunnel_name" | awk '{print $1}')
    
    # Configure tunnel
    mkdir -p ~/.cloudflared
    cat > ~/.cloudflared/config.yml << EOF
tunnel: $tunnel_uuid
credentials-file: ~/.cloudflared/$tunnel_uuid.json

ingress:
  - hostname: app.${CLOUDFLARE_DOMAIN}
    service: http://localhost:3000
  - hostname: api.${CLOUDFLARE_DOMAIN}
    service: http://localhost:5000
  - service: http_status:404
EOF
    
    # Create systemd service
    create_tunnel_service "cloudflare" "cloudflared tunnel run $tunnel_name"
    
    # Set URLs
    FRONTEND_URL="https://app.${CLOUDFLARE_DOMAIN}"
    BACKEND_URL="https://api.${CLOUDFLARE_DOMAIN}"
    WEBSOCKET_URL="wss://api.${CLOUDFLARE_DOMAIN}/socket.io"
    
    print_success "Cloudflare Tunnel created: $tunnel_name"
    print_success "   📱 Frontend: $FRONTEND_URL"
    print_success "   🔧 Backend: $BACKEND_URL"
    print_warning "⚠️ Configure DNS records in Cloudflare dashboard"
}

setup_pagekite_tunnel() {
    print_status "🎪 Setting up PageKite tunnel..."
    
    # Install PageKite
    if ! command -v pagekite &> /dev/null; then
        print_status "Installing PageKite..."
        apt-get update -qq
        apt-get install -y pagekite > /dev/null 2>&1
    fi
    
    # Get name if not provided
    if [ -z "$PAGEKITE_NAME" ]; then
        if [ "$INTERACTIVE" = true ]; then
            read -p "Enter your PageKite name: " PAGEKITE_NAME
        else
            print_error "PageKite name required for tunnel setup"
            exit 1
        fi
    fi
    
    # Create PageKite configuration
    mkdir -p ~/.pagekite.d
    cat > ~/.pagekite.d/10_account.rc << EOF
kitename   = ${PAGEKITE_NAME}
kitesecret = your_pagekite_secret
EOF
    
    print_warning "Please configure your PageKite secret in ~/.pagekite.d/10_account.rc"
    
    # Set URLs
    FRONTEND_URL="http://${PAGEKITE_NAME}-app.pagekite.me"
    BACKEND_URL="http://${PAGEKITE_NAME}-api.pagekite.me"
    WEBSOCKET_URL="ws://${PAGEKITE_NAME}-api.pagekite.me/socket.io"
    
    local service_cmd="pagekite --defaults --service_on=http:${PAGEKITE_NAME}-app.pagekite.me:localhost:3000:your_secret --service_on=http:${PAGEKITE_NAME}-api.pagekite.me:localhost:5000:your_secret"
    
    create_tunnel_service "pagekite" "$service_cmd"
    
    print_success "PageKite tunnel configured"
    print_success "   📱 Frontend: $FRONTEND_URL"
    print_success "   🔧 Backend: $BACKEND_URL"
}

setup_telebit_tunnel() {
    print_status "🔧 Setting up Telebit tunnel..."
    
    # Install Telebit
    if ! command -v telebit &> /dev/null; then
        print_status "Installing Telebit..."
        # Download and install telebit binary
        wget -q https://telebit.cloud/install.sh -O - | bash > /dev/null 2>&1 || {
            print_warning "Failed to install Telebit automatically"
        }
    fi
    
    # Generate secret if not provided
    if [ -z "$TELEBIT_SECRET" ]; then
        TELEBIT_SECRET=$(openssl rand -hex 32)
    fi
    
    # Generate subdomain if not provided
    if [ -z "$TUNNEL_SUBDOMAIN" ]; then
        TUNNEL_SUBDOMAIN="eqtrader-$(openssl rand -hex 4)"
    fi
    
    # Create Telebit configuration
    cat > ~/.telebit.env << EOF
SECRET=$TELEBIT_SECRET
TUNNEL_RELAY_URL=https://telebit.cloud/
LOCALS=https:*:3000,https:*:5000
ACME_AGREE=true
ACME_EMAIL=admin@${TUNNEL_SUBDOMAIN}.telebit.cloud
EOF
    
    # Set URLs
    FRONTEND_URL="https://${TUNNEL_SUBDOMAIN}.telebit.cloud"
    BACKEND_URL="https://${TUNNEL_SUBDOMAIN}-api.telebit.cloud"
    WEBSOCKET_URL="wss://${TUNNEL_SUBDOMAIN}-api.telebit.cloud/socket.io"
    
    create_tunnel_service "telebit" "telebit --env ~/.telebit.env --verbose"
    
    print_success "Telebit tunnel configured"
    print_success "   📱 Frontend: $FRONTEND_URL"
    print_success "   🔧 Backend: $BACKEND_URL"
}

# Create systemd service for tunnel management
create_tunnel_service() {
    local service_name="$1"
    local exec_command="$2"
    
    print_status "Creating systemd service for $service_name..."
    
    cat > "/etc/systemd/system/trading-bot-tunnel.service" << EOF
[Unit]
Description=QuantConnect Trading Bot Tunnel ($service_name)
Documentation=https://github.com/szarastrefa/quantconnect-trading-bot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/bin/bash -c '$exec_command'
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
    
    print_success "Systemd service created and enabled: $service_name"
}

# Main tunnel setup function
setup_tunnel() {
    case "$TUNNEL_TYPE" in
        "classical") setup_classical_ddns ;;
        "ngrok") setup_ngrok_tunnel ;;
        "localtunnel") setup_localtunnel ;;
        "serveo") setup_serveo_tunnel ;;
        "cloudflare") setup_cloudflare_tunnel ;;
        "pagekite") setup_pagekite_tunnel ;;
        "telebit") setup_telebit_tunnel ;;
        *)
            print_error "Unknown tunnel type: $TUNNEL_TYPE"
            exit 1
            ;;
    esac
}

# Clone repository with backup handling and fixed SUDO_USER
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
    
    # Set permissions - Fixed SUDO_USER handling
    if [ -n "${SUDO_USER:-}" ]; then
        chown -R "$SUDO_USER:$SUDO_USER" "$INSTALL_DIR" 2>/dev/null || true
        print_verbose "Set ownership to $SUDO_USER"
    else
        print_verbose "Running as direct root - keeping root ownership"
    fi
    
    print_success "Repository cloned to $INSTALL_DIR"
}

# Generate secure credentials with enhanced security
generate_all_credentials() {
    print_status "Generating secure credentials..."
    
    # Generate all credentials
    POSTGRES_USER="trader_$(openssl rand -hex 4)"
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    JWT_SECRET=$(openssl rand -hex 32)
    ENCRYPTION_KEY=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    SESSION_SECRET=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    
    print_verbose "Generated credentials for database, JWT, encryption, and Redis"
    print_success "Secure credentials generated"
}

# Setup environment configuration with tunnel support
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
        api_base_url="${BACKEND_URL}/api"
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
    
    # Create comprehensive environment file
    cat > .env << EOF
# QuantConnect Trading Bot - Environment Configuration
# Generated on $(date)
# Installation Mode: $([ "$DEV_MODE" = true ] && echo "Development" || echo "Production")
# Network Mode: ${TUNNEL_TYPE:-localhost}

# Environment Configuration
NODE_ENV=$([ "$DEV_MODE" = true ] && echo "development" || echo "production")
ENVIRONMENT=$([ "$DEV_MODE" = true ] && echo "development" || echo "production")
DEBUG=$([ "$DEV_MODE" = true ] && echo "true" || echo "false")
FLASK_ENV=$([ "$DEV_MODE" = true ] && echo "development" || echo "production")
FLASK_DEBUG=$([ "$DEV_MODE" = true ] && echo "true" || echo "false")

# Network Configuration
TUNNEL_TYPE=${TUNNEL_TYPE:-localhost}
DOMAIN=${TUNNEL_DOMAIN:-localhost}
FRONTEND_URL=$frontend_url
BACKEND_URL=${BACKEND_URL:-http://localhost:5000}
WEBSOCKET_URL=$websocket_url
DASHBOARD_URL=${DASHBOARD_URL:-}

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
API_BASE_URL=$api_base_url
CORS_ORIGINS=$cors_origins
SOCKETIO_CORS_ORIGINS=$cors_origins

# React App Configuration
REACT_APP_API_URL=$api_base_url
REACT_APP_WS_URL=$websocket_url
REACT_APP_DOMAIN=${TUNNEL_DOMAIN:-localhost}

# SSL Configuration
SSL_ENABLED=$ssl_enabled_val
SSL_CERT_PATH=/etc/letsencrypt/live/${TUNNEL_DOMAIN:-localhost}/fullchain.pem
SSL_KEY_PATH=/etc/letsencrypt/live/${TUNNEL_DOMAIN:-localhost}/privkey.pem

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
TRUSTED_HOSTS=${TUNNEL_DOMAIN:-localhost},localhost
MAX_CONTENT_LENGTH=16777216

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
    
    print_success "Environment configuration created"
    
    if [ "$VERBOSE" = true ]; then
        print_verbose "Environment file created at: $INSTALL_DIR/.env"
        print_verbose "Generated $(wc -l < .env) configuration lines"
        print_verbose "Network mode: ${TUNNEL_TYPE:-localhost}"
        print_verbose "Frontend URL: $frontend_url"
        print_verbose "Backend URL: ${BACKEND_URL:-http://localhost:5000}"
    fi
}

# SSL Certificate installation with multiple fallback methods
install_ssl_snapd() {
    print_status "Attempting SSL installation via snapd..."
    
    # Install snapd and certbot
    apt-get install -y -qq snapd > /dev/null 2>&1
    snap install core > /dev/null 2>&1
    snap refresh core > /dev/null 2>&1
    snap install --classic certbot > /dev/null 2>&1
    ln -sf /snap/bin/certbot /usr/bin/certbot
    
    return 0
}

install_ssl_alternative() {
    print_status "Using alternative SSL installation method..."
    
    # Install certbot via APT (more compatible with VPS/containers)
    apt-get update -qq > /dev/null 2>&1
    apt-get install -y certbot python3-certbot-nginx > /dev/null 2>&1 || {
        print_error "Failed to install certbot via APT"
        return 1
    }
    
    return 0
}

install_ssl_certificates() {
    if [ "$INSTALL_SSL" = false ] || [ "$SKIP_SSL" = true ]; then
        print_skip "SSL certificates installation"
        return 0
    fi
    
    # Skip SSL for tunnel types that provide their own SSL
    if [ "$TUNNEL_TYPE" != "classical" ]; then
        print_skip "SSL certificates (tunnel provides SSL)"
        return 0
    fi
    
    print_status "Installing SSL certificates..."
    
    # Try snapd method first, fallback to APT method
    if [ "$SKIP_SSL_SNAPD" = false ] && install_ssl_snapd 2>/dev/null; then
        print_verbose "Using snapd-based certbot"
    else
        print_warning "Snapd method failed or skipped, using APT-based installation"
        if ! install_ssl_alternative; then
            print_error "All SSL installation methods failed"
            return 1
        fi
    fi
    
    # Stop nginx if running
    systemctl stop nginx 2>/dev/null || true
    
    # Get certificate
    print_status "Obtaining SSL certificate for ${TUNNEL_DOMAIN:-localhost}..."
    
    local ssl_email
    if [ "$INTERACTIVE" = true ]; then
        read -p "Enter email for SSL certificate: " ssl_email
    else
        ssl_email="admin@${TUNNEL_DOMAIN:-localhost}"
        print_warning "Using default email: $ssl_email"
    fi
    
    # Try to get certificate
    if certbot certonly \
        --standalone \
        --preferred-challenges http \
        --email "$ssl_email" \
        --agree-tos \
        --no-eff-email \
        --domains "${TUNNEL_DOMAIN:-localhost}" \
        --non-interactive > /dev/null 2>&1; then
        
        print_success "SSL certificate obtained for ${TUNNEL_DOMAIN:-localhost}"
        
        # Setup auto-renewal
        (crontab -l 2>/dev/null || echo "") | grep -v certbot > /tmp/cron_tmp || true
        echo "0 12 * * * /usr/bin/certbot renew --quiet" >> /tmp/cron_tmp
        crontab /tmp/cron_tmp
        rm -f /tmp/cron_tmp
        
        print_success "SSL auto-renewal configured"
        return 0
    else
        print_warning "Failed to obtain SSL certificate for ${TUNNEL_DOMAIN:-localhost}"
        if [ "$DEV_MODE" = false ]; then
            print_warning "Continuing without SSL - you can retry later"
            INSTALL_SSL=false
        fi
        return 1
    fi
}

# Create production Docker Compose configuration
create_production_compose() {
    print_status "Preparing Docker Compose configuration..."
    
    cd "$INSTALL_DIR"
    
    # Choose compose file based on mode
    local compose_file
    if [ "$DEV_MODE" = true ]; then
        compose_file="docker-compose.yml"
    else
        compose_file="docker-compose.production.yml"
    fi
    
    if [ -f "$compose_file" ]; then
        chmod 644 "$compose_file"
        print_success "Docker Compose configuration ready ($compose_file)"
    else
        print_warning "$compose_file not found in repository"
        print_status "Services will use direct port access"
    fi
}

# Setup firewall with proper port management
setup_firewall() {
    if [ "$SKIP_FIREWALL" = true ]; then
        print_skip "Firewall configuration (--skip-firewall)"
        return
    fi
    
    print_status "Configuring firewall..."
    
    # Check if ufw is available
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
        ufw allow 3000/tcp > /dev/null 2>&1  # React dev server
        ufw allow 5000/tcp > /dev/null 2>&1  # Flask dev server
        print_verbose "Opened development ports 3000 and 5000"
    fi
    
    # Enable firewall
    ufw --force enable > /dev/null 2>&1
    
    print_success "Firewall configured"
}

# Create systemd service for system management
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
    
    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable quantconnect-trading-bot.service > /dev/null 2>&1
    
    print_success "Systemd service created and enabled"
}

# Create comprehensive management script
create_management_script() {
    print_status "Setting up system management..."
    
    # Check if manage.sh exists in repo
    if [ -f "$INSTALL_DIR/scripts/manage.sh" ]; then
        chmod +x "$INSTALL_DIR/scripts/manage.sh"
        
        # Create system-wide symlink
        ln -sf "$INSTALL_DIR/scripts/manage.sh" /usr/local/bin/trading-bot
        
        print_success "Management script ready (use 'trading-bot' command globally)"
    else
        print_warning "scripts/manage.sh not found, creating basic management script"
        
        # Create enhanced management script
        create_basic_management_script
    fi
}

create_basic_management_script() {
    cat > /usr/local/bin/trading-bot << 'EOF'
#!/bin/bash

INSTALL_DIR="/opt/quantconnect-trading-bot"
COMPOSE_FILE="docker-compose.production.yml"

if [ ! -d "$INSTALL_DIR" ]; then
    echo "❌ Error: QuantConnect Trading Bot not installed in $INSTALL_DIR"
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
    restart)
        echo "🔄 Restarting QuantConnect Trading Bot..."
        docker-compose -f "$COMPOSE_FILE" down
        docker-compose -f "$COMPOSE_FILE" up -d
        echo "✅ System restarted"
        ;;
    status)
        echo "📊 QuantConnect Trading Bot Status:"
        docker-compose -f "$COMPOSE_FILE" ps
        ;;
    logs)
        echo "📋 QuantConnect Trading Bot Logs:"
        docker-compose -f "$COMPOSE_FILE" logs -f
        ;;
    health)
        echo "🏥 Health Check:"
        curl -f http://localhost:5000/api/health 2>/dev/null && echo "✅ API healthy" || echo "❌ API not responding"
        ;;
    update)
        echo "🔄 Updating system..."
        git pull origin main
        docker-compose -f "$COMPOSE_FILE" build --no-cache
        docker-compose -f "$COMPOSE_FILE" up -d
        echo "✅ System updated"
        ;;
    tunnel)
        case "$2" in
            status)
                echo "🌐 Tunnel Status:"
                systemctl status trading-bot-tunnel.service --no-pager 2>/dev/null || echo "❌ No tunnel service found"
                ;;
            start)
                echo "🚀 Starting tunnels..."
                systemctl start trading-bot-tunnel.service
                ;;
            stop)
                echo "🛑 Stopping tunnels..."
                systemctl stop trading-bot-tunnel.service
                ;;
            restart)
                echo "🔄 Restarting tunnels..."
                systemctl restart trading-bot-tunnel.service
                ;;
            *)
                echo "Usage: $0 tunnel {status|start|stop|restart}"
                ;;
        esac
        ;;
    *)
        echo "QuantConnect Trading Bot Management Script v3.0"
        echo ""
        echo "Usage: $0 {start|stop|restart|status|logs|health|update|tunnel}"
        echo ""
        echo "Commands:"
        echo "  start    - Start all services"
        echo "  stop     - Stop all services"  
        echo "  restart  - Restart all services"
        echo "  status   - Show container status"
        echo "  logs     - Show and follow logs"
        echo "  health   - Check API health"
        echo "  update   - Update from repository"
        echo "  tunnel   - Manage tunnels (status|start|stop|restart)"
        echo ""
        echo "Examples:"
        echo "  trading-bot start"
        echo "  trading-bot logs"
        echo "  trading-bot tunnel status"
        exit 1
        ;;
esac
EOF
    
    chmod +x /usr/local/bin/trading-bot
    print_success "Basic management script created"
}

# Validate environment configuration
validate_environment() {
    print_status "Validating environment configuration..."
    
    cd "$INSTALL_DIR"
    
    # Choose compose file
    local compose_file="docker-compose.production.yml"
    if [ "$DEV_MODE" = true ]; then
        compose_file="docker-compose.yml"
    fi
    
    # Test docker-compose configuration if file exists
    if [ -f "$compose_file" ]; then
        if docker-compose -f "$compose_file" config > /dev/null 2>&1; then
            print_success "Docker Compose configuration valid"
        else
            print_warning "Docker Compose configuration issues detected"
            if [ "$VERBOSE" = true ]; then
                print_error "Configuration test output:"
                docker-compose -f "$compose_file" config 2>&1 | head -10
            fi
        fi
    fi
    
    # Check .env file format
    if [ -f ".env" ]; then
        if grep -E "^[A-Z_][A-Z0-9_]*=[^=]*$" .env > /dev/null; then
            print_success "Environment file format valid"
        else
            print_warning "Environment file may contain formatting issues"
            if [ "$VERBOSE" = true ]; then
                print_verbose "Checking for problematic lines..."
                grep -v -E "^[A-Z_][A-Z0-9_]*=[^=]*$|^[[:space:]]*#|^[[:space:]]*$" .env | head -3 || true
            fi
        fi
    else
        print_error "Environment file not found"
        exit 1
    fi
}

# Build and start the complete system
build_and_start_system() {
    if [ "$NO_AUTO_START" = true ]; then
        print_skip "System build and start (--no-auto-start)"
        print_success "Installation completed without starting services"
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
    
    # Check if compose file exists
    if [ ! -f "$compose_file" ]; then
        print_warning "Docker Compose file not found: $compose_file"
        print_status "System installed but not started automatically"
        return
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
    }
    
    # Start tunnel service if applicable
    if [ "$TUNNEL_TYPE" != "classical" ] && [ "$TUNNEL_TYPE" != "" ] && systemctl is-enabled trading-bot-tunnel.service > /dev/null 2>&1; then
        print_status "Starting tunnel service..."
        systemctl start trading-bot-tunnel.service || print_warning "Tunnel service may take a moment to start"
    fi
    
    # Wait for services to be healthy
    print_status "Waiting for services to start..."
    local wait_time=30
    if [ "$DEV_MODE" = true ]; then
        wait_time=20
    fi
    sleep $wait_time
    
    # Check service health
    check_service_health
    
    print_success "System build and start completed"
}

# Check service health with comprehensive testing
check_service_health() {
    print_status "Checking service health..."
    
    # Check if containers are running
    local running_containers
    running_containers=$(docker ps --filter "name=trading" --format "{{.Names}}" 2>/dev/null | wc -l)
    
    if [ "$running_containers" -ge 2 ]; then
        print_success "Services are running ($running_containers containers)"
    else
        print_warning "Some services may not be running ($running_containers containers)"
        if [ "$VERBOSE" = true ]; then
            print_status "Container status:"
            docker ps --format "table {{.Names}}\\t{{.Status}}\\t{{.Ports}}" 2>/dev/null || true
        fi
    fi
    
    # Test API endpoint after a moment
    sleep 10
    local api_url="http://localhost:5000/api/health"
    
    if [ "$TUNNEL_TYPE" != "classical" ] && [ -n "$BACKEND_URL" ]; then
        api_url="$BACKEND_URL/health"
        print_status "Using tunnel endpoint for health check"
    elif [ "$INSTALL_SSL" = true ] && [ "$DEV_MODE" = false ] && [ "$TUNNEL_TYPE" = "classical" ]; then
        api_url="https://$TUNNEL_DOMAIN/health"
    fi
    
    if curl -f -s "$api_url" > /dev/null 2>&1; then
        print_success "System is responding"
    else
        print_warning "System may still be starting up (this is normal)"
        print_status "   You can check status later with: trading-bot health"
    fi
}

# Display comprehensive installation summary
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
        echo "   📈 API Docs: http://localhost:5000/docs"
    elif [ -n "$TUNNEL_TYPE" ] && [ "$TUNNEL_TYPE" != "classical" ]; then
        echo "   🏭 Mode: Production (Tunneled)"
        echo "   🌐 Network: ${TUNNEL_TYPE^}"
        
        if [ -n "$FRONTEND_URL" ]; then
            echo "   📱 Frontend: $FRONTEND_URL"
        fi
        if [ -n "$BACKEND_URL" ]; then
            echo "   🔧 Backend: $BACKEND_URL"
        fi
        if [ -n "$WEBSOCKET_URL" ]; then
            echo "   📮 WebSocket: $WEBSOCKET_URL"
        fi
        if [ -n "$DASHBOARD_URL" ]; then
            echo "   📊 Dashboard: $DASHBOARD_URL"
        fi
    else
        echo "   🏭 Mode: Production"
        if [ -n "$TUNNEL_DOMAIN" ]; then
            echo "   🌐 Domain: https://$TUNNEL_DOMAIN"
            echo "   📊 API: https://$TUNNEL_DOMAIN/api"
            echo "   📈 Health: https://$TUNNEL_DOMAIN/health"
            echo "   🔌 WebSocket: wss://$TUNNEL_DOMAIN/socket.io"
        else
            echo "   🌐 Local: http://localhost:3000"
            echo "   📊 API: http://localhost:5000"
        fi
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
    echo "   ├─ Update system: trading-bot update"
    
    if [[ -n "$TUNNEL_TYPE" && "$TUNNEL_TYPE" != "classical" ]]; then
        echo "   ├─ Tunnel status: trading-bot tunnel status"
        echo "   ├─ Restart tunnels: trading-bot tunnel restart"
    fi
    
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
    elif [ -n "$FRONTEND_URL" ]; then
        echo "      $FRONTEND_URL"
    elif [ -n "$TUNNEL_DOMAIN" ]; then
        echo "      https://$TUNNEL_DOMAIN"
    else
        echo "      http://localhost:3000"
    fi
    echo ""
    echo "   4. 📈 Upload ML models and begin trading!"
    echo ""
    
    # Show enabled/disabled features
    echo -e "${BLUE}🔧 Installation Features:${NC}"
    echo "   ├─ Production Mode: $([ "$PRODUCTION_MODE" = true ] && echo "✅ Enabled" || echo "❌ Disabled")"
    echo "   ├─ Network Type: ${TUNNEL_TYPE:-localhost}"
    echo "   ├─ SSL/HTTPS: $([ "$INSTALL_SSL" = true ] && echo "✅ Enabled" || echo "❌ Disabled")"
    echo "   ├─ DDNS Auto-Update: $([ "$SKIP_DDNS_ERROR" = false ] && [ "$TUNNEL_TYPE" = "classical" ] && echo "✅ Enabled" || echo "⏭️ Skipped")"
    echo "   ├─ Firewall: $([ "$SKIP_FIREWALL" = false ] && echo "✅ Configured" || echo "⏭️ Skipped")"
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
    elif [ -n "$FRONTEND_URL" ]; then
        echo "🌐 Tunnel mode enabled - your system is accessible globally!"
        echo "🚀 Access: $FRONTEND_URL"
        echo ""
        echo -e "${YELLOW}⚠️  NOTE: Keep tunnel processes running for continuous access${NC}"
        echo -e "${BLUE}🔄 Tunnels auto-restart on failure${NC}"
    else
        echo "🏭 Production system deployed successfully!"
        if [ -n "$TUNNEL_DOMAIN" ]; then
            echo "🌐 Access: https://$TUNNEL_DOMAIN"
        else
            echo "🌐 Access: http://localhost:3000"
        fi
    fi
}

# Interactive mode prompts
run_interactive_mode() {
    if [ "$INTERACTIVE" = false ]; then
        return
    fi
    
    echo ""
    echo "🔧 Interactive Setup Mode"
    echo ""
    
    # Production mode
    read -p "Enable production mode? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        PRODUCTION_MODE=false
        DEV_MODE=true
    fi
    
    # SSL setup
    if [ "$PRODUCTION_MODE" = true ] && [ "$TUNNEL_TYPE" = "classical" ]; then
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
    
    # DDNS error handling
    read -p "Skip DDNS errors if they occur? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        SKIP_DDNS_ERROR=true
    fi
}

# Main function that orchestrates the entire installation
main() {
    # Parse command line arguments first
    parse_arguments "$@"
    
    # Show header
    print_header
    
    # Determine tunnel selection mode
    if [ "$SHOW_TUNNEL_MENU" = true ]; then
        show_tunnel_menu
    elif [ -z "$TUNNEL_TYPE" ]; then
        # No tunnel specified, show menu
        show_tunnel_menu
    fi
    
    # Run interactive mode if enabled
    run_interactive_mode
    
    # Auto-enable SSL in production mode (if not explicitly disabled and using classical domain)
    if [ "$PRODUCTION_MODE" = true ] && [ "$SKIP_SSL" = false ] && [ "$INSTALL_SSL" = false ] && [ "$TUNNEL_TYPE" = "classical" ]; then
        if [ "$INTERACTIVE" = false ]; then
            INSTALL_SSL=true
        fi
    fi
    
    # Show selected options in verbose mode
    if [ "$VERBOSE" = true ]; then
        echo -e "${PURPLE}📋 Installation Configuration:${NC}"
        echo "   Production Mode: $PRODUCTION_MODE"
        echo "   Development Mode: $DEV_MODE"
        echo "   Network Type: ${TUNNEL_TYPE:-localhost}"
        echo "   Install SSL: $INSTALL_SSL"
        echo "   Skip DDNS Error: $SKIP_DDNS_ERROR"
        echo "   Skip Firewall: $SKIP_FIREWALL"
        echo "   Force Install: $FORCE_INSTALL"
        echo "   Install Directory: $INSTALL_DIR"
        echo ""
    fi
    
    # System checks and installation
    check_system_requirements
    
    # Create log file
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    
    print_status "🔧 Starting QuantConnect Trading Bot installation..."
    print_status "📅 Installation started at: $(date)"
    print_verbose "Installation mode: $([ "$DEV_MODE" = true ] && echo "Development" || echo "Production")"
    print_verbose "Network mode: ${TUNNEL_TYPE:-localhost}"
    
    # Force install handling
    if [ "$FORCE_INSTALL" = true ]; then
        print_status "🔄 Force install - removing existing installation"
    fi
    
    # Installation steps
    update_system_packages
    install_system_dependencies
    install_docker
    install_docker_compose
    
    # Setup networking (DDNS or tunneling)
    if [ -n "$TUNNEL_TYPE" ]; then
        setup_tunnel
    else
        print_status "🌐 Using localhost networking"
    fi
    
    # Continue with system setup
    clone_repository
    setup_environment
    
    # SSL installation (only for classical domain)
    if [ "$INSTALL_SSL" = true ] && [ "$SKIP_SSL" = false ] && [ "$TUNNEL_TYPE" = "classical" ]; then
        install_ssl_certificates
    else
        print_skip "SSL certificates installation"
    fi
    
    # System configuration
    create_production_compose
    setup_firewall
    create_systemd_service
    create_management_script
    
    # Build and start (unless skipped)
    build_and_start_system
    
    # Final summary
    display_installation_summary
}

# Handle script termination gracefully
trap 'echo -e "\n${YELLOW}🛑 Installation interrupted${NC}"; exit 1' INT TERM

# Run main function with all arguments
main "$@"