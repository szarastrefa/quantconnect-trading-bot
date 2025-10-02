#!/bin/bash

# QuantConnect Trading Bot - Tunnel Setup Manager
# Version: 3.0  
# Supports: Ngrok, LocalTunnel, Serveo, Cloudflare, PageKite, Telebit

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m' 
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Global variables
TUNNEL_TYPE=""
CUSTOM_SUBDOMAIN=""
NGROK_TOKEN=""
FRONTEND_PORT=3000
BACKEND_PORT=5000

print_header() {
    clear
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    🌐 TUNNEL SETUP MANAGER                      ║${NC}"
    echo -e "${BLUE}║              QuantConnect Trading Bot v3.0                      ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_tunnel_menu() {
    echo -e "${YELLOW}🌐 Choose your tunneling method:${NC}"
    echo ""
    echo -e "1. 🏠 ${GREEN}Classical Domain${NC} (eqtrader.ddnskita.my.id)       ${CYAN}[STABLE]${NC}"
    echo -e "2. 🚀 ${GREEN}Ngrok Tunnel${NC} (professional, custom subdomains)   ${CYAN}[POPULAR]${NC}"
    echo -e "3. 🌐 ${GREEN}LocalTunnel${NC} (completely free, zero-config)       ${CYAN}[SIMPLE]${NC}"
    echo -e "4. 🔒 ${GREEN}Serveo SSH${NC} (no installation required)            ${CYAN}[MINIMAL]${NC}"
    echo -e "5. ☁️  ${GREEN}Cloudflare Tunnel${NC} (enterprise-grade)             ${CYAN}[SECURE]${NC}"
    echo -e "6. 🎪 ${GREEN}PageKite${NC} (commercial tunneling)                  ${CYAN}[PREMIUM]${NC}"
    echo -e "7. 🔧 ${GREEN}Telebit${NC} (modern cloud tunneling)                 ${CYAN}[MODERN]${NC}"
    echo -e "8. ⚙️  ${GREEN}Manual Configuration${NC}                              ${CYAN}[ADVANCED]${NC}"
    echo ""
}

install_dependencies() {
    echo -e "${BLUE}📦 Installing dependencies...${NC}"
    
    # Update package list
    apt update -qq
    
    # Install common dependencies  
    apt install -y curl wget jq netcat-openbsd openssh-client
    
    # Install Node.js if not present (for LocalTunnel)
    if ! command -v node &> /dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt install -y nodejs
    fi
    
    echo -e "${GREEN}✅ Dependencies installed${NC}"
}

setup_ngrok() {
    echo -e "${GREEN}🚀 Setting up Ngrok tunnel...${NC}"
    
    # Install ngrok if not present
    if ! command -v ngrok &> /dev/null; then
        echo "Installing Ngrok..."
        curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | gpg --dearmor -o /etc/apt/keyrings/ngrok.gpg
        echo "deb [signed-by=/etc/apt/keyrings/ngrok.gpg] https://ngrok-agent.s3.amazonaws.com buster main" > /etc/apt/sources.list.d/ngrok.list
        apt update && apt install -y ngrok
    fi
    
    # Get auth token
    if [[ -z "$NGROK_TOKEN" ]]; then
        echo ""
        echo -e "${YELLOW}📝 Ngrok requires authentication token${NC}"
        echo "Get your token from: https://dashboard.ngrok.com/get-started/your-authtoken"
        read -p "Enter your Ngrok auth token: " NGROK_TOKEN
    fi
    
    # Configure ngrok
    ngrok config add-authtoken "$NGROK_TOKEN"
    
    # Create config
    mkdir -p ~/.ngrok2
    cat > ~/.ngrok2/ngrok.yml << EOF
version: "2"
authtoken: $NGROK_TOKEN
tunnels:
  frontend:
    addr: $FRONTEND_PORT
    proto: http
    subdomain: eqtrader-app
  backend:
    addr: $BACKEND_PORT  
    proto: http
    subdomain: eqtrader-api
EOF
    
    # Start tunnels
    echo "Starting Ngrok tunnels..."
    nohup ngrok start --all --config ~/.ngrok2/ngrok.yml > /tmp/ngrok.log 2>&1 &
    
    # Wait for tunnels to establish
    sleep 5
    
    # Get tunnel URLs
    FRONTEND_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | jq -r '.tunnels[] | select(.name=="frontend") | .public_url' 2>/dev/null || echo "https://eqtrader-app.ngrok.io")
    BACKEND_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | jq -r '.tunnels[] | select(.name=="backend") | .public_url' 2>/dev/null || echo "https://eqtrader-api.ngrok.io")
    
    echo ""
    echo -e "${GREEN}✅ Ngrok tunnels established:${NC}"
    echo -e "   🎨 Frontend: ${CYAN}$FRONTEND_URL${NC}"
    echo -e "   🔌 Backend:  ${CYAN}$BACKEND_URL${NC}"
    echo -e "   🎛️  Dashboard: ${CYAN}http://localhost:4040${NC}"
    
    # Save URLs to environment
    export TUNNEL_FRONTEND_URL="$FRONTEND_URL"
    export TUNNEL_BACKEND_URL="$BACKEND_URL"
    export TUNNEL_TYPE="ngrok"
    
    update_env_file
}

setup_localtunnel() {
    echo -e "${GREEN}🌐 Setting up LocalTunnel...${NC}"
    
    # Install localtunnel
    npm install -g localtunnel
    
    # Generate subdomain
    if [[ -z "$CUSTOM_SUBDOMAIN" ]]; then
        SUBDOMAIN="eqtrader-$(openssl rand -hex 4)"
    else
        SUBDOMAIN="$CUSTOM_SUBDOMAIN"
    fi
    
    echo "Using subdomain: $SUBDOMAIN"
    
    # Start tunnels
    echo "Starting LocalTunnel..."
    nohup lt --port $FRONTEND_PORT --subdomain "$SUBDOMAIN-app" > /tmp/lt-frontend.log 2>&1 &
    nohup lt --port $BACKEND_PORT --subdomain "$SUBDOMAIN-api" > /tmp/lt-backend.log 2>&1 &
    
    # Wait for tunnels
    sleep 3
    
    FRONTEND_URL="https://$SUBDOMAIN-app.loca.lt"
    BACKEND_URL="https://$SUBDOMAIN-api.loca.lt"
    
    echo ""
    echo -e "${GREEN}✅ LocalTunnel established:${NC}"
    echo -e "   🎨 Frontend: ${CYAN}$FRONTEND_URL${NC}"
    echo -e "   🔌 Backend:  ${CYAN}$BACKEND_URL${NC}"
    echo -e "   💰 Cost: ${GREEN}FREE${NC}"
    
    # Save URLs
    export TUNNEL_FRONTEND_URL="$FRONTEND_URL"
    export TUNNEL_BACKEND_URL="$BACKEND_URL"
    export TUNNEL_TYPE="localtunnel"
    
    update_env_file
}

setup_serveo() {
    echo -e "${GREEN}🔒 Setting up Serveo SSH tunnel...${NC}"
    
    # Generate subdomain
    if [[ -z "$CUSTOM_SUBDOMAIN" ]]; then
        SUBDOMAIN="eqtrader-$(openssl rand -hex 4)"
    else
        SUBDOMAIN="$CUSTOM_SUBDOMAIN"
    fi
    
    echo "Using subdomain: $SUBDOMAIN"
    
    # Start SSH tunnels
    echo "Starting Serveo tunnels..."
    nohup ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=60 -R "$SUBDOMAIN-app":80:localhost:$FRONTEND_PORT serveo.net > /tmp/serveo-frontend.log 2>&1 &
    nohup ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=60 -R "$SUBDOMAIN-api":80:localhost:$BACKEND_PORT serveo.net > /tmp/serveo-backend.log 2>&1 &
    
    # Wait for tunnels
    sleep 3
    
    FRONTEND_URL="https://$SUBDOMAIN-app.serveo.net"
    BACKEND_URL="https://$SUBDOMAIN-api.serveo.net"
    
    echo ""
    echo -e "${GREEN}✅ Serveo tunnels established:${NC}"
    echo -e "   🎨 Frontend: ${CYAN}$FRONTEND_URL${NC}"
    echo -e "   🔌 Backend:  ${CYAN}$BACKEND_URL${NC}"
    echo -e "   🔐 Protocol: ${GREEN}SSH forwarding${NC}"
    
    # Save URLs
    export TUNNEL_FRONTEND_URL="$FRONTEND_URL"
    export TUNNEL_BACKEND_URL="$BACKEND_URL"
    export TUNNEL_TYPE="serveo"
    
    update_env_file
}

setup_cloudflare() {
    echo -e "${GREEN}☁️ Setting up Cloudflare Tunnel...${NC}"
    
    # Install cloudflared
    if ! command -v cloudflared &> /dev/null; then
        echo "Installing cloudflared..."
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
        dpkg -i cloudflared-linux-amd64.deb
        rm cloudflared-linux-amd64.deb
    fi
    
    echo ""
    echo -e "${YELLOW}📝 Cloudflare Tunnel requires account login${NC}"
    echo "Please login to your Cloudflare account when prompted..."
    
    # Login to Cloudflare
    cloudflared tunnel login
    
    # Create tunnel
    TUNNEL_NAME="eqtrader-$(openssl rand -hex 4)"
    cloudflared tunnel create "$TUNNEL_NAME"
    
    # Get tunnel UUID
    TUNNEL_UUID=$(cloudflared tunnel list | grep "$TUNNEL_NAME" | awk '{print $1}')
    
    # Configure tunnel
    mkdir -p ~/.cloudflared
    cat > ~/.cloudflared/config.yml << EOF
tunnel: $TUNNEL_UUID
credentials-file: ~/.cloudflared/$TUNNEL_UUID.json

ingress:
  - hostname: eqtrader-app.yourdomain.com
    service: http://localhost:$FRONTEND_PORT
  - hostname: eqtrader-api.yourdomain.com  
    service: http://localhost:$BACKEND_PORT
  - service: http_status:404
EOF
    
    # Start tunnel
    echo "Starting Cloudflare Tunnel..."
    nohup cloudflared tunnel run "$TUNNEL_NAME" > /tmp/cloudflare.log 2>&1 &
    
    echo ""
    echo -e "${GREEN}✅ Cloudflare Tunnel created: ${CYAN}$TUNNEL_NAME${NC}"
    echo -e "${YELLOW}⚠️  Configure DNS records in Cloudflare dashboard${NC}"
    echo "   1. Go to your Cloudflare dashboard"
    echo "   2. Add CNAME records for your subdomains"
    echo "   3. Point them to the tunnel"
    
    # Save config
    export TUNNEL_NAME="$TUNNEL_NAME"
    export TUNNEL_UUID="$TUNNEL_UUID"
    export TUNNEL_TYPE="cloudflare"
    
    update_env_file
}

setup_pagekite() {
    echo -e "${GREEN}🎪 Setting up PageKite tunnel...${NC}"
    
    # Install PageKite
    if ! command -v pagekite &> /dev/null; then
        echo "Installing PageKite..."
        pip3 install pagekite || {
            apt install -y python3-pip
            pip3 install pagekite
        }
    fi
    
    echo ""
    echo -e "${YELLOW}📝 PageKite requires account registration${NC}"
    echo "Visit: https://pagekite.net/ to create an account"
    read -p "Enter your PageKite subdomain: " PAGEKITE_SUBDOMAIN
    
    # Start PageKite tunnels
    echo "Starting PageKite tunnels..."
    nohup python3 -m pagekite $FRONTEND_PORT $PAGEKITE_SUBDOMAIN-app.pagekite.me > /tmp/pagekite-frontend.log 2>&1 &
    nohup python3 -m pagekite $BACKEND_PORT $PAGEKITE_SUBDOMAIN-api.pagekite.me > /tmp/pagekite-backend.log 2>&1 &
    
    sleep 3
    
    FRONTEND_URL="https://$PAGEKITE_SUBDOMAIN-app.pagekite.me"
    BACKEND_URL="https://$PAGEKITE_SUBDOMAIN-api.pagekite.me"
    
    echo ""
    echo -e "${GREEN}✅ PageKite tunnels established:${NC}"
    echo -e "   🎨 Frontend: ${CYAN}$FRONTEND_URL${NC}"
    echo -e "   🔌 Backend:  ${CYAN}$BACKEND_URL${NC}"
    
    # Save URLs
    export TUNNEL_FRONTEND_URL="$FRONTEND_URL"
    export TUNNEL_BACKEND_URL="$BACKEND_URL"
    export TUNNEL_TYPE="pagekite"
    
    update_env_file
}

setup_telebit() {
    echo -e "${GREEN}🔧 Setting up Telebit tunnel...${NC}"
    
    # Install Telebit
    if ! command -v telebit &> /dev/null; then
        echo "Installing Telebit..."
        curl https://get.telebit.io/ | bash
        # Add to PATH
        export PATH="$PATH:$HOME/.local/bin"
    fi
    
    echo ""
    echo -e "${YELLOW}📝 Telebit requires email registration${NC}"
    read -p "Enter your email: " TELEBIT_EMAIL
    
    # Configure Telebit
    telebit --agree-tos --email "$TELEBIT_EMAIL" || true
    
    # Start Telebit tunnels  
    echo "Starting Telebit tunnels..."
    nohup telebit http $FRONTEND_PORT --subdomain eqtrader-app > /tmp/telebit-frontend.log 2>&1 &
    nohup telebit http $BACKEND_PORT --subdomain eqtrader-api > /tmp/telebit-backend.log 2>&1 &
    
    sleep 5
    
    # Get URLs from logs
    FRONTEND_URL=$(grep -o 'https://[^[:space:]]*' /tmp/telebit-frontend.log 2>/dev/null | head -1 || echo "https://eqtrader-app.telebit.cloud")
    BACKEND_URL=$(grep -o 'https://[^[:space:]]*' /tmp/telebit-backend.log 2>/dev/null | head -1 || echo "https://eqtrader-api.telebit.cloud")
    
    echo ""
    echo -e "${GREEN}✅ Telebit tunnels established:${NC}"
    echo -e "   🎨 Frontend: ${CYAN}$FRONTEND_URL${NC}"
    echo -e "   🔌 Backend:  ${CYAN}$BACKEND_URL${NC}"
    
    # Save URLs
    export TUNNEL_FRONTEND_URL="$FRONTEND_URL"
    export TUNNEL_BACKEND_URL="$BACKEND_URL"
    export TUNNEL_TYPE="telebit"
    
    update_env_file
}

update_env_file() {
    ENV_FILE="$PROJECT_ROOT/.env"
    
    # Update or create .env file
    if [[ -f "$ENV_FILE" ]]; then
        # Remove old tunnel settings
        sed -i '/^TUNNEL_/d' "$ENV_FILE"
    fi
    
    # Add new tunnel settings
    cat >> "$ENV_FILE" << EOF

# Tunnel Configuration (Auto-generated)
TUNNEL_TYPE=$TUNNEL_TYPE
TUNNEL_FRONTEND_URL=${TUNNEL_FRONTEND_URL:-}
TUNNEL_BACKEND_URL=${TUNNEL_BACKEND_URL:-}
TUNNEL_WS_URL=${TUNNEL_BACKEND_URL:-}/socket.io
REACT_APP_API_URL=${TUNNEL_BACKEND_URL:-}
REACT_APP_WS_URL=${TUNNEL_BACKEND_URL:-}/socket.io
CORS_ORIGINS=${TUNNEL_FRONTEND_URL:-}
EOF
    
    echo ""
    echo -e "${GREEN}✅ Environment file updated${NC}"
}

monitor_tunnels() {
    echo -e "${BLUE}📊 Monitoring tunnel status...${NC}"
    
    case "$TUNNEL_TYPE" in
        "ngrok")
            if pgrep -f "ngrok" > /dev/null; then
                echo -e "${GREEN}✅ Ngrok: Active${NC}"
                curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[] | "   \(.name): \(.public_url)"' 2>/dev/null || echo "   Dashboard: http://localhost:4040"
            else
                echo -e "${RED}❌ Ngrok: Not running${NC}"
            fi
            ;;
        "localtunnel")
            if pgrep -f "lt --port" > /dev/null; then
                echo -e "${GREEN}✅ LocalTunnel: Active${NC}"
                echo "   Frontend: $(grep -o 'https://[^[:space:]]*loca.lt' /tmp/lt-frontend.log 2>/dev/null | tail -1 || echo 'Starting...')"
                echo "   Backend: $(grep -o 'https://[^[:space:]]*loca.lt' /tmp/lt-backend.log 2>/dev/null | tail -1 || echo 'Starting...')"
            else
                echo -e "${RED}❌ LocalTunnel: Not running${NC}"
            fi
            ;;
        "serveo")
            if pgrep -f "ssh.*serveo.net" > /dev/null; then
                echo -e "${GREEN}✅ Serveo: Active${NC}"
                echo "   SSH connections: $(pgrep -f 'ssh.*serveo.net' | wc -l) active"
            else
                echo -e "${RED}❌ Serveo: Not running${NC}"
            fi
            ;;
        "cloudflare")
            if pgrep -f "cloudflared" > /dev/null; then
                echo -e "${GREEN}✅ Cloudflare: Active${NC}"
                if [[ -n "${TUNNEL_NAME:-}" ]]; then
                    echo "   Tunnel: $TUNNEL_NAME"
                fi
            else
                echo -e "${RED}❌ Cloudflare: Not running${NC}"
            fi
            ;;
        "pagekite")
            if pgrep -f "pagekite" > /dev/null; then
                echo -e "${GREEN}✅ PageKite: Active${NC}"
            else
                echo -e "${RED}❌ PageKite: Not running${NC}"
            fi
            ;;
        "telebit")
            if pgrep -f "telebit" > /dev/null; then
                echo -e "${GREEN}✅ Telebit: Active${NC}"
            else
                echo -e "${RED}❌ Telebit: Not running${NC}"
            fi
            ;;
        *)
            echo -e "${YELLOW}⚠️ No tunnel type specified${NC}"
            ;;
    esac
}

stop_tunnels() {
    echo -e "${YELLOW}🛑 Stopping all tunnels...${NC}"
    
    # Stop various tunnel processes
    pkill -f ngrok 2>/dev/null || true
    pkill -f "lt --port" 2>/dev/null || true  
    pkill -f "ssh.*serveo.net" 2>/dev/null || true
    pkill -f cloudflared 2>/dev/null || true
    pkill -f pagekite 2>/dev/null || true
    pkill -f telebit 2>/dev/null || true
    
    echo -e "${GREEN}✅ All tunnels stopped${NC}"
}

restart_tunnels() {
    echo -e "${BLUE}🔄 Restarting tunnels...${NC}"
    
    # Read tunnel type from environment if available
    if [[ -f "$PROJECT_ROOT/.env" ]]; then
        TUNNEL_TYPE=$(grep "^TUNNEL_TYPE=" "$PROJECT_ROOT/.env" 2>/dev/null | cut -d'=' -f2 || echo "")
    fi
    
    if [[ -z "$TUNNEL_TYPE" ]]; then
        echo -e "${RED}❌ No tunnel type found. Please run setup first.${NC}"
        return 1
    fi
    
    stop_tunnels
    sleep 2
    
    case "$TUNNEL_TYPE" in
        "ngrok") setup_ngrok ;;
        "localtunnel") setup_localtunnel ;;
        "serveo") setup_serveo ;;
        "cloudflare") setup_cloudflare ;;
        "pagekite") setup_pagekite ;;
        "telebit") setup_telebit ;;
        *) echo -e "${RED}Unknown tunnel type: $TUNNEL_TYPE${NC}"; exit 1 ;;
    esac
}

show_help() {
    echo "QuantConnect Trading Bot - Tunnel Setup Manager v3.0"
    echo ""
    echo "USAGE:"
    echo "  $0 [OPTIONS]"
    echo ""
    echo "TUNNEL OPTIONS:"
    echo "  --ngrok [token]         Setup Ngrok tunneling"
    echo "  --localtunnel [subdomain]  Setup LocalTunnel (free)"
    echo "  --serveo [subdomain]    Setup Serveo SSH tunneling"
    echo "  --cloudflare           Setup Cloudflare Tunnel"
    echo "  --pagekite             Setup PageKite tunneling"
    echo "  --telebit              Setup Telebit tunneling"
    echo ""
    echo "MANAGEMENT OPTIONS:"
    echo "  --list-options         Show tunnel selection menu"
    echo "  --monitor              Monitor tunnel status"
    echo "  --stop                 Stop all tunnels"
    echo "  --restart              Restart active tunnels"
    echo "  --help                 Show this help"
    echo ""
    echo "EXAMPLES:"
    echo "  $0                      # Interactive menu"
    echo "  $0 --ngrok              # Setup Ngrok (will prompt for token)"
    echo "  $0 --localtunnel        # Setup LocalTunnel with random subdomain"
    echo "  $0 --serveo eqtrader    # Setup Serveo with custom subdomain"
    echo "  $0 --monitor            # Check tunnel status"
    echo "  $0 --restart            # Restart existing tunnels"
}

main() {
    # Parse command line arguments
    case "${1:-}" in
        --list-options)
            print_header
            show_tunnel_menu
            exit 0
            ;;
        --monitor)
            monitor_tunnels
            exit 0
            ;;
        --stop)
            stop_tunnels
            exit 0
            ;;
        --restart)
            restart_tunnels
            exit 0
            ;;
        --help)
            show_help
            exit 0
            ;;
        --ngrok)
            TUNNEL_TYPE="ngrok"
            NGROK_TOKEN="${2:-}"
            ;;
        --localtunnel)
            TUNNEL_TYPE="localtunnel"
            CUSTOM_SUBDOMAIN="${2:-}"
            ;;
        --serveo)
            TUNNEL_TYPE="serveo"
            CUSTOM_SUBDOMAIN="${2:-}"
            ;;
        --cloudflare)
            TUNNEL_TYPE="cloudflare"
            ;;
        --pagekite)
            TUNNEL_TYPE="pagekite"
            ;;
        --telebit)
            TUNNEL_TYPE="telebit"
            ;;
        "")
            # No arguments - show interactive menu
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for available options"
            exit 1
            ;;
    esac
    
    print_header
    
    # Install dependencies first
    install_dependencies
    
    # If tunnel type not specified, show menu
    if [[ -z "$TUNNEL_TYPE" ]]; then
        show_tunnel_menu
        read -p "Enter your choice [1-8]: " choice
        
        case $choice in
            1) echo -e "${BLUE}Classical domain setup - use main installer${NC}"; exit 0 ;;
            2) TUNNEL_TYPE="ngrok" ;;
            3) TUNNEL_TYPE="localtunnel" ;;
            4) TUNNEL_TYPE="serveo" ;;
            5) TUNNEL_TYPE="cloudflare" ;;
            6) TUNNEL_TYPE="pagekite" ;;
            7) TUNNEL_TYPE="telebit" ;;
            8) echo -e "${YELLOW}Manual configuration - edit configs manually${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid choice${NC}"; exit 1 ;;
        esac
    fi
    
    # Setup selected tunnel
    case "$TUNNEL_TYPE" in
        "ngrok") setup_ngrok ;;
        "localtunnel") setup_localtunnel ;;
        "serveo") setup_serveo ;;
        "cloudflare") setup_cloudflare ;;
        "pagekite") setup_pagekite ;;
        "telebit") setup_telebit ;;
        *) echo -e "${RED}Unknown tunnel type: $TUNNEL_TYPE${NC}"; exit 1 ;;
    esac
    
    echo ""
    echo -e "${GREEN}🎉 Tunnel setup completed!${NC}"
    echo ""
    echo -e "${BLUE}📋 Management commands:${NC}"
    echo "   Monitor: $0 --monitor"
    echo "   Stop:    $0 --stop"
    echo "   Restart: $0 --restart"
    echo ""
    echo -e "${YELLOW}⚠️  Note: Keep tunnels running for continuous access${NC}"
    echo -e "${BLUE}💡 Pro tip: Use 'screen' or 'tmux' to run tunnels in background${NC}"
    
    # Show final URLs
    if [[ -n "${TUNNEL_FRONTEND_URL:-}" ]]; then
        echo ""
        echo -e "${CYAN}🌐 Your application is now accessible at:${NC}"
        echo -e "   Frontend: ${TUNNEL_FRONTEND_URL}"
        echo -e "   Backend:  ${TUNNEL_BACKEND_URL}"
    fi
}

# Handle script termination
trap 'echo -e "\n${YELLOW}🛑 Tunnel setup interrupted${NC}"; exit 1' INT TERM

main "$@"