#!/bin/bash

# QuantConnect Trading Bot - Advanced Interactive Setup Script
# Interactive menu-driven installation with customization options
# Domain: eqtrader.ddnskita.my.id

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="eqtrader.ddnskita.my.id"
DDNS_UPDATE_URL="https://tunnel.hostddns.us/ddns/377b9a29c7bba5435e4b5d53e3ead4aa"
PROJECT_NAME="quantconnect-trading-bot"
INSTALL_DIR="/opt/$PROJECT_NAME"
LOG_FILE="/var/log/trading-bot-advanced-setup.log"
SETUP_SCRIPT_URL="https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh"

# Installation options
PRODUCTION_MODE=true
DEV_MODE=false
MINIMAL_MODE=false
SKIP_DDNS_ERROR=true
SKIP_SSL=false
SKIP_FIREWALL=false
FORCE_INSTALL=false
VERBOSE=false
CUSTOM_DOMAIN=""
CUSTOM_PORT=""

print_logo() {
    echo -e "${BLUE}"
    cat << 'EOF'
    ╔══════════════════════════════════════════════════════════════════╗
    ║                                                                  ║
    ║         ██████╗ ██╗   ██╗ █████╗ ███╗   ██╗████████╗            ║
    ║        ██╔═══██╗██║   ██║██╔══██╗████╗  ██║╚══██╔══╝            ║
    ║        ██║   ██║██║   ██║███████║██╔██╗ ██║   ██║               ║
    ║        ██║▄▄ ██║██║   ██║██╔══██║██║╚██╗██║   ██║               ║
    ║        ╚██████╔╝╚██████╔╝██║  ██║██║ ╚████║   ██║               ║
    ║         ╚══▀▀═╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝               ║
    ║                                                                  ║
    ║             ╔═╗ ╔═╗ ╔╗╔ ╔╗╔ ╔═╗ ╔═╗ ╔╦╗                        ║
    ║             ║   ║ ║ ║║║ ║║║ ║╣  ║   ║                         ║
    ║             ╚═╝ ╚═╝ ╝╚╝ ╝╚╝ ╚═╝ ╚═╝ ╩                         ║
    ║                                                                  ║
    ║                   TRADING BOT v2.0                              ║
    ║                Advanced Interactive Setup                       ║
    ║                                                                  ║
    ║    🌐 Domain: eqtrader.ddnskita.my.id                           ║
    ║    🤖 20+ Brokers | AI/ML Integration | Real-time Trading       ║
    ╚══════════════════════════════════════════════════════════════════╝
EOF
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

print_header() {
    local title="$1"
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    printf "║ %-64s ║\n" "$title"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_requirements() {
    print_status "Checking system requirements..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Check Ubuntu
    if ! grep -q "Ubuntu" /etc/os-release; then
        print_warning "This script is designed for Ubuntu"
        echo "Current system: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check available space
    local space_gb=$(df / | awk 'NR==2 {printf "%.0f", $4/1024/1024}')
    if [ "$space_gb" -lt 5 ]; then
        print_error "Less than 5GB free space available. Need at least 5GB for installation."
        exit 1
    fi
    
    # Check memory
    local memory_gb=$(free -g | awk 'NR==2{printf "%.0f", $2}')
    if [ "$memory_gb" -lt 2 ]; then
        print_warning "Less than 2GB RAM detected. Performance may be limited."
    fi
    
    print_status "✅ System requirements check passed"
    echo "   💾 Available space: ${space_gb}GB"
    echo "   🧠 Available memory: ${memory_gb}GB"
}

show_main_menu() {
    clear
    print_logo
    
    print_header "🚀 MAIN INSTALLATION MENU"
    
    echo -e "${WHITE}Select installation mode:${NC}"
    echo ""
    echo "  1. 🏭 Production Setup     - Full production deployment with SSL"
    echo "  2. 🧪 Development Setup    - Local development environment"
    echo "  3. 🎯 Minimal Setup        - Core services only"
    echo "  4. ⚙️  Custom Setup         - Advanced configuration options"
    echo "  5. 🔧 System Recovery      - Fix existing installation"
    echo "  6. ℹ️  System Information   - Show system details"
    echo "  7. ❌ Exit                 - Cancel installation"
    echo ""
    
    read -p "Enter your choice (1-7): " choice
    
    case $choice in
        1)
            setup_production_mode
            ;;
        2)
            setup_development_mode
            ;;
        3)
            setup_minimal_mode
            ;;
        4)
            show_custom_menu
            ;;
        5)
            show_recovery_menu
            ;;
        6)
            show_system_info
            ;;
        7)
            echo "Installation cancelled."
            exit 0
            ;;
        *)
            print_error "Invalid choice. Please select 1-7."
            sleep 2
            show_main_menu
            ;;
    esac
}

setup_production_mode() {
    print_header "🏭 Production Setup Configuration"
    
    echo "Production mode includes:"
    echo "  ✅ SSL/HTTPS certificates"
    echo "  ✅ Firewall configuration"
    echo "  ✅ DDNS integration"
    echo "  ✅ Production-grade security"
    echo "  ✅ Automatic service startup"
    echo ""
    
    PRODUCTION_MODE=true
    DEV_MODE=false
    MINIMAL_MODE=false
    
    # Ask about DDNS
    echo "DDNS (Dynamic DNS) setup:"
    echo "This keeps your domain pointing to your server's changing IP address."
    read -p "Skip DDNS errors if they occur? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        SKIP_DDNS_ERROR=true
    fi
    
    # Ask about custom domain
    read -p "Use custom domain? Current: $DOMAIN (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter your domain: " custom_domain
        if [ -n "$custom_domain" ]; then
            CUSTOM_DOMAIN="$custom_domain"
            DOMAIN="$custom_domain"
        fi
    fi
    
    confirm_and_install
}

setup_development_mode() {
    print_header "🧪 Development Setup Configuration"
    
    echo "Development mode includes:"
    echo "  🔧 HTTP only (no SSL)"
    echo "  🔧 Local ports (3000, 5000)"
    echo "  🔧 Debug logging enabled"
    echo "  🔧 Hot reload for development"
    echo "  🔧 Minimal security (for testing)"
    echo ""
    
    PRODUCTION_MODE=false
    DEV_MODE=true
    MINIMAL_MODE=false
    SKIP_SSL=true
    SKIP_FIREWALL=true
    SKIP_DDNS_ERROR=true
    
    echo "Development setup will:"
    echo "  - Run on HTTP (not HTTPS)"
    echo "  - Use localhost URLs"
    echo "  - Enable debug mode"
    echo "  - Skip SSL and firewall"
    echo ""
    
    confirm_and_install
}

setup_minimal_mode() {
    print_header "🎯 Minimal Setup Configuration"
    
    echo "Minimal mode includes:"
    echo "  📦 Core trading services only"
    echo "  📦 No SSL/HTTPS"
    echo "  📦 No reverse proxy"
    echo "  📦 Basic security"
    echo "  📦 Fastest installation"
    echo ""
    
    PRODUCTION_MODE=false
    DEV_MODE=false
    MINIMAL_MODE=true
    SKIP_SSL=true
    SKIP_FIREWALL=true
    SKIP_DDNS_ERROR=true
    
    confirm_and_install
}

show_custom_menu() {
    print_header "⚙️ Custom Setup Configuration"
    
    echo "Configure each component individually:"
    echo ""
    
    # Environment mode
    echo "📋 Environment Mode:"
    echo "  1. Production (SSL, Security, HTTPS)"
    echo "  2. Development (HTTP, Debug, Local)"
    read -p "Select mode (1-2): " mode_choice
    case $mode_choice in
        1)
            PRODUCTION_MODE=true
            DEV_MODE=false
            ;;
        2)
            PRODUCTION_MODE=false
            DEV_MODE=true
            SKIP_SSL=true
            ;;
        *)
            print_error "Invalid choice, defaulting to production"
            PRODUCTION_MODE=true
            DEV_MODE=false
            ;;
    esac
    
    echo ""
    
    # SSL Configuration
    if [ "$PRODUCTION_MODE" = true ]; then
        read -p "Install SSL certificates? (Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            SKIP_SSL=true
        fi
    fi
    
    # Firewall
    read -p "Configure firewall (UFW)? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        SKIP_FIREWALL=true
    fi
    
    # DDNS
    read -p "Skip DDNS errors if they occur? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        SKIP_DDNS_ERROR=true
    fi
    
    # Force install
    if [ -d "$INSTALL_DIR" ]; then
        echo ""
        echo "⚠️  Existing installation detected at: $INSTALL_DIR"
        read -p "Remove existing installation? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            FORCE_INSTALL=true
        fi
    fi
    
    # Verbose output
    read -p "Enable verbose output for debugging? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        VERBOSE=true
    fi
    
    # Custom domain
    read -p "Use custom domain? Current: $DOMAIN (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter your domain: " custom_domain
        if [ -n "$custom_domain" ]; then
            CUSTOM_DOMAIN="$custom_domain"
            DOMAIN="$custom_domain"
        fi
    fi
    
    confirm_and_install
}

show_recovery_menu() {
    print_header "🔧 System Recovery Options"
    
    echo "Recovery options:"
    echo ""
    echo "  1. 🔄 Restart Services     - Restart all trading bot services"
    echo "  2. 🧹 Clean Installation   - Remove and reinstall completely"
    echo "  3. 🔍 Diagnose Issues      - Run system diagnostics"
    echo "  4. 🛠️  Fix Permissions      - Fix file and Docker permissions"
    echo "  5. 📋 Show Logs           - Display recent error logs"
    echo "  6. ⬅️  Back to Main Menu   - Return to main menu"
    echo ""
    
    read -p "Select recovery option (1-6): " recovery_choice
    
    case $recovery_choice in
        1)
            restart_services
            ;;
        2)
            clean_installation
            ;;
        3)
            diagnose_system
            ;;
        4)
            fix_permissions
            ;;
        5)
            show_logs
            ;;
        6)
            show_main_menu
            ;;
        *)
            print_error "Invalid choice. Please select 1-6."
            sleep 2
            show_recovery_menu
            ;;
    esac
}

restart_services() {
    print_status "Restarting QuantConnect Trading Bot services..."
    
    if [ -d "$INSTALL_DIR" ]; then
        cd "$INSTALL_DIR"
        
        # Stop services
        docker-compose -f docker-compose.production.yml down 2>/dev/null || docker-compose down 2>/dev/null
        
        # Start services
        docker-compose -f docker-compose.production.yml up -d 2>/dev/null || docker-compose up -d 2>/dev/null
        
        print_status "✅ Services restarted"
        
        # Show status
        sleep 5
        docker ps --filter "name=trading" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    else
        print_error "Trading bot not found at $INSTALL_DIR"
    fi
    
    read -p "Press Enter to continue..."
    show_recovery_menu
}

clean_installation() {
    print_header "🧹 Clean Installation"
    
    echo "This will:"
    echo "  - Stop all trading bot services"
    echo "  - Remove all containers and images"
    echo "  - Delete installation directory"
    echo "  - Perform fresh installation"
    echo ""
    echo "⚠️  WARNING: This will delete all data!"
    echo ""
    
    read -p "Are you sure? Type 'yes' to confirm: " confirm
    if [ "$confirm" = "yes" ]; then
        print_status "Performing clean installation..."
        
        # Stop and remove containers
        docker stop $(docker ps -aq --filter "name=trading" 2>/dev/null) 2>/dev/null || true
        docker rm $(docker ps -aq --filter "name=trading" 2>/dev/null) 2>/dev/null || true
        
        # Remove installation directory
        rm -rf "$INSTALL_DIR" 2>/dev/null || true
        
        # Set force install and go to production setup
        FORCE_INSTALL=true
        setup_production_mode
    else
        print_status "Clean installation cancelled"
        read -p "Press Enter to continue..."
        show_recovery_menu
    fi
}

diagnose_system() {
    print_header "🔍 System Diagnostics"
    
    echo "Running comprehensive system diagnostics..."
    echo ""
    
    # System info
    echo "📋 System Information:"
    echo "  OS: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
    echo "  Kernel: $(uname -r)"
    echo "  Memory: $(free -h | awk 'NR==2{printf "%s/%s", $3,$2}')"
    echo "  Disk Space: $(df -h / | awk 'NR==2{printf "%s/%s (%s)", $3,$2,$5}')"
    echo ""
    
    # Docker status
    echo "🐳 Docker Status:"
    if command -v docker &> /dev/null; then
        echo "  Docker Version: $(docker --version)"
        echo "  Docker Status: $(systemctl is-active docker)"
        
        if docker ps &> /dev/null; then
            echo "  Running Containers: $(docker ps | wc -l)"
            docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        else
            echo "  ❌ Cannot connect to Docker daemon"
        fi
    else
        echo "  ❌ Docker not installed"
    fi
    echo ""
    
    # Trading bot status
    echo "🤖 Trading Bot Status:"
    if [ -d "$INSTALL_DIR" ]; then
        echo "  Installation: ✅ Found at $INSTALL_DIR"
        
        if [ -f "$INSTALL_DIR/.env" ]; then
            echo "  Configuration: ✅ Found"
        else
            echo "  Configuration: ❌ Missing .env file"
        fi
        
        # Check services
        cd "$INSTALL_DIR"
        if [ -f "docker-compose.production.yml" ] || [ -f "docker-compose.yml" ]; then
            echo "  Docker Compose: ✅ Found"
        else
            echo "  Docker Compose: ❌ Missing compose file"
        fi
    else
        echo "  Installation: ❌ Not found"
    fi
    echo ""
    
    # Network connectivity
    echo "🌐 Network Connectivity:"
    if ping -c 1 8.8.8.8 &> /dev/null; then
        echo "  Internet: ✅ Connected"
    else
        echo "  Internet: ❌ No connection"
    fi
    
    if curl -s "$DDNS_UPDATE_URL" &> /dev/null; then
        echo "  DDNS Service: ✅ Reachable"
    else
        echo "  DDNS Service: ❌ Unreachable"
    fi
    
    if nslookup "$DOMAIN" &> /dev/null; then
        echo "  Domain Resolution: ✅ $DOMAIN resolves"
    else
        echo "  Domain Resolution: ❌ $DOMAIN not resolving"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
    show_recovery_menu
}

fix_permissions() {
    print_status "Fixing system permissions..."
    
    # Fix Docker permissions
    if [ "$SUDO_USER" ]; then
        usermod -aG docker "$SUDO_USER"
        print_status "✅ Added $SUDO_USER to docker group"
    fi
    
    # Fix installation directory permissions
    if [ -d "$INSTALL_DIR" ] && [ "$SUDO_USER" ]; then
        chown -R "$SUDO_USER:$SUDO_USER" "$INSTALL_DIR"
        print_status "✅ Fixed $INSTALL_DIR ownership"
    fi
    
    # Fix log file permissions
    if [ -f "$LOG_FILE" ]; then
        chmod 644 "$LOG_FILE"
        print_status "✅ Fixed log file permissions"
    fi
    
    print_status "Permissions fixed. Please log out and back in for Docker group changes to take effect."
    
    read -p "Press Enter to continue..."
    show_recovery_menu
}

show_logs() {
    print_header "📋 Recent System Logs"
    
    # Installation logs
    echo "📄 Installation Logs:"
    if [ -f "$LOG_FILE" ]; then
        tail -20 "$LOG_FILE"
    else
        echo "No installation log found"
    fi
    echo ""
    
    # Docker logs
    echo "🐳 Docker Container Logs:"
    if docker ps --filter "name=trading" -q | head -1 | xargs -I {} docker logs --tail=10 {} 2>/dev/null; then
        echo "(Last 10 lines from first trading container)"
    else
        echo "No trading bot containers running"
    fi
    echo ""
    
    # System logs
    echo "🖥️  System Logs (Docker related):"
    journalctl -u docker --no-pager -n 10 2>/dev/null || echo "Cannot access system logs"
    
    read -p "Press Enter to continue..."
    show_recovery_menu
}

show_system_info() {
    print_header "ℹ️ System Information"
    
    echo "🖥️  Hardware Information:"
    echo "  CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
    echo "  CPU Cores: $(nproc)"
    echo "  Memory: $(free -h | awk 'NR==2{printf "%s total, %s used, %s free", $2,$3,$4}')"
    echo "  Storage: $(df -h / | awk 'NR==2{printf "%s total, %s used, %s available (%s used)", $2,$3,$4,$5}')"
    echo ""
    
    echo "🐧 Operating System:"
    echo "  Distribution: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
    echo "  Kernel: $(uname -r)"
    echo "  Architecture: $(uname -m)"
    echo "  Uptime: $(uptime -p)"
    echo ""
    
    echo "🌐 Network Information:"
    echo "  Public IP: $(curl -s ifconfig.me 2>/dev/null || echo "Unable to detect")"
    echo "  Internal IP: $(hostname -I | awk '{print $1}')"
    echo "  Hostname: $(hostname)"
    echo ""
    
    echo "🐳 Docker Information:"
    if command -v docker &> /dev/null; then
        echo "  Docker Version: $(docker --version)"
        echo "  Docker Compose: $(docker-compose --version 2>/dev/null || echo "Not installed")"
        echo "  Docker Status: $(systemctl is-active docker 2>/dev/null || echo "Unknown")"
        echo "  Storage Driver: $(docker system info --format '{{.Driver}}' 2>/dev/null || echo "Unknown")"
    else
        echo "  Docker: Not installed"
    fi
    echo ""
    
    echo "🤖 Trading Bot Information:"
    if [ -d "$INSTALL_DIR" ]; then
        echo "  Installation Directory: $INSTALL_DIR"
        echo "  Installation Size: $(du -sh $INSTALL_DIR 2>/dev/null | cut -f1)"
        echo "  Configuration File: $([ -f "$INSTALL_DIR/.env" ] && echo "Present" || echo "Missing")"
        
        # Count running containers
        local containers=$(docker ps --filter "name=trading" -q 2>/dev/null | wc -l)
        echo "  Running Containers: $containers"
    else
        echo "  Status: Not installed"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
    show_main_menu
}

confirm_and_install() {
    print_header "📋 Installation Summary"
    
    echo "Installation configuration:"
    echo "  🎯 Mode: $([ "$PRODUCTION_MODE" = true ] && echo "Production" || ([ "$DEV_MODE" = true ] && echo "Development" || echo "Minimal"))"
    echo "  🌐 Domain: $DOMAIN"
    echo "  📁 Install Path: $INSTALL_DIR"
    echo "  🔐 SSL/HTTPS: $([ "$SKIP_SSL" = false ] && echo "Enabled" || echo "Disabled")"
    echo "  🛡️  Firewall: $([ "$SKIP_FIREWALL" = false ] && echo "Enabled" || echo "Disabled")"
    echo "  🌐 DDNS Error Handling: $([ "$SKIP_DDNS_ERROR" = true ] && echo "Skip errors" || echo "Stop on error")"
    echo "  🔧 Force Install: $([ "$FORCE_INSTALL" = true ] && echo "Yes" || echo "No")"
    echo "  📝 Verbose Output: $([ "$VERBOSE" = true ] && echo "Yes" || echo "No")"
    echo ""
    
    echo "This installation will:"
    echo "  ✅ Install Docker and Docker Compose"
    echo "  ✅ Download QuantConnect Trading Bot"
    echo "  ✅ Configure $([ "$PRODUCTION_MODE" = true ] && echo "production" || echo "development") environment"
    echo "  ✅ Set up 20+ broker integrations"
    echo "  ✅ Enable AI/ML model support"
    echo "  ✅ Configure real-time trading dashboard"
    
    if [ "$PRODUCTION_MODE" = true ]; then
        echo "  ✅ Install SSL certificates"
        echo "  ✅ Configure reverse proxy (Nginx)"
        echo "  ✅ Set up firewall rules"
        echo "  ✅ Enable DDNS auto-updates"
    fi
    
    echo ""
    echo "⏱️  Estimated installation time: $([ "$MINIMAL_MODE" = true ] && echo "5-10" || echo "10-15") minutes"
    echo ""
    
    read -p "Proceed with installation? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        run_installation
    else
        print_status "Installation cancelled"
        show_main_menu
    fi
}

run_installation() {
    print_header "🚀 Starting Installation"
    
    # Build installation command
    local install_cmd="curl -fsSL $SETUP_SCRIPT_URL | bash -s --"
    
    # Add flags based on configuration
    if [ "$DEV_MODE" = true ]; then
        install_cmd="$install_cmd --dev-mode"
    elif [ "$MINIMAL_MODE" = true ]; then
        install_cmd="$install_cmd --minimal"
    else
        install_cmd="$install_cmd --production"
    fi
    
    if [ "$SKIP_DDNS_ERROR" = true ]; then
        install_cmd="$install_cmd --skip-ddns-error"
    fi
    
    if [ "$SKIP_SSL" = true ]; then
        install_cmd="$install_cmd --skip-ssl"
    fi
    
    if [ "$SKIP_FIREWALL" = true ]; then
        install_cmd="$install_cmd --skip-firewall"
    fi
    
    if [ "$FORCE_INSTALL" = true ]; then
        install_cmd="$install_cmd --force-install"
    fi
    
    if [ "$VERBOSE" = true ]; then
        install_cmd="$install_cmd --verbose"
    fi
    
    if [ -n "$CUSTOM_DOMAIN" ]; then
        install_cmd="$install_cmd --domain $CUSTOM_DOMAIN"
    fi
    
    if [ -n "$CUSTOM_PORT" ]; then
        install_cmd="$install_cmd --port $CUSTOM_PORT"
    fi
    
    print_status "Executing installation command:"
    print_status "$install_cmd"
    echo ""
    
    # Show progress indicator
    echo "🏗️  Installation in progress..."
    echo "📄 Full installation log: $LOG_FILE"
    echo ""
    
    # Execute installation
    eval "$install_cmd" 2>&1 | tee -a "$LOG_FILE"
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        installation_success
    else
        installation_failed
    fi
}

installation_success() {
    clear
    print_logo
    
    print_header "🎉 INSTALLATION COMPLETED SUCCESSFULLY!"
    
    echo "✅ QuantConnect Trading Bot has been installed and configured!"
    echo ""
    
    if [ "$DEV_MODE" = true ]; then
        echo "🧪 Development Environment Ready:"
        echo "   🌐 Frontend: http://localhost:3000"
        echo "   🔧 Backend API: http://localhost:5000"
        echo "   📚 API Docs: http://localhost:5000/docs"
    else
        echo "🏭 Production Environment Ready:"
        echo "   🌐 Main App: https://$DOMAIN"
        echo "   🔧 API: https://$DOMAIN/api"
        echo "   📚 API Docs: https://$DOMAIN/api/docs"
        echo "   💹 Trading Dashboard: https://$DOMAIN/dashboard"
    fi
    
    echo ""
    echo "📋 Next Steps:"
    echo "   1. Configure broker API keys: nano $INSTALL_DIR/.env"
    echo "   2. Start trading: trading-bot start"
    echo "   3. Monitor system: trading-bot status"
    echo "   4. View logs: trading-bot logs"
    echo ""
    
    echo "🛠️  Management Commands:"
    echo "   trading-bot start    - Start the system"
    echo "   trading-bot stop     - Stop the system"
    echo "   trading-bot status   - Show status"
    echo "   trading-bot logs     - View logs"
    echo "   trading-bot update   - Update system"
    echo ""
    
    echo "📚 Documentation:"
    echo "   📖 Full Guide: $INSTALL_DIR/README.md"
    echo "   🔧 Troubleshooting: $INSTALL_DIR/docs/TROUBLESHOOTING.md"
    echo "   🏦 Broker Setup: $INSTALL_DIR/docs/BROKER_WORKFLOWS.md"
    echo ""
    
    echo "⚠️  Important Reminders:"
    echo "   💾 Save generated credentials securely"
    echo "   🔑 Configure broker API keys before live trading"
    echo "   🧪 Test with demo accounts first"
    echo "   📊 Monitor system performance regularly"
    echo ""
    
    echo -e "${GREEN}🚀 Your algorithmic trading system is ready!${NC}"
    echo ""
    
    read -p "Press Enter to exit..."
}

installation_failed() {
    clear
    print_header "❌ Installation Failed"
    
    echo "The installation encountered errors."
    echo ""
    echo "📋 Troubleshooting steps:"
    echo "   1. Check the installation log: $LOG_FILE"
    echo "   2. Ensure you have sufficient disk space and memory"
    echo "   3. Check internet connectivity"
    echo "   4. Try running with --verbose flag for more details"
    echo ""
    
    echo "🔧 Quick fixes to try:"
    echo "   • Restart the system: sudo reboot"
    echo "   • Free up disk space: docker system prune -a"
    echo "   • Update packages: sudo apt update && sudo apt upgrade"
    echo "   • Check Docker: sudo systemctl status docker"
    echo ""
    
    echo "💬 Get help:"
    echo "   🐛 Report issues: https://github.com/szarastrefa/quantconnect-trading-bot/issues"
    echo "   💭 Discussions: https://github.com/szarastrefa/quantconnect-trading-bot/discussions"
    echo ""
    
    read -p "Return to main menu? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        show_main_menu
    fi
}

# Initialize logging
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# Check requirements and start
check_requirements
show_main_menu