#!/bin/bash

# Environment Validation Script for QuantConnect Trading Bot
# Validates .env file format and Docker Compose configuration

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
ENV_FILE="$PROJECT_DIR/.env"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.production.yml"

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║              Environment Validation & Troubleshooting           ║"
    echo "║                  QuantConnect Trading Bot                       ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

validate_env_file() {
    print_status "Validating .env file..."
    
    if [ ! -f "$ENV_FILE" ]; then
        print_error ".env file not found at $ENV_FILE"
        return 1
    fi
    
    # Check for basic syntax issues
    local issues=0
    local line_num=0
    
    while IFS= read -r line || [ -n "$line" ]; do
        line_num=$((line_num + 1))
        
        # Skip comments and empty lines
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
            continue
        fi
        
        # Check for valid variable format
        if ! [[ "$line" =~ ^[A-Z_][A-Z0-9_]*=.*$ ]]; then
            print_error "Invalid format at line $line_num: $line"
            issues=$((issues + 1))
        fi
        
        # Check for problematic characters
        if [[ "$line" =~ [+=] ]] && ! [[ "$line" =~ ^[^=]*=.*$ ]]; then
            print_error "Invalid characters at line $line_num: $line"
            issues=$((issues + 1))
        fi
        
        # Check for unescaped quotes
        if [[ "$line" =~ ='.*['\"].*'$ ]] || [[ "$line" =~ =".*['\"].*"$ ]]; then
            print_warning "Potentially unescaped quotes at line $line_num: $line"
        fi
        
    done < "$ENV_FILE"
    
    if [ $issues -eq 0 ]; then
        print_status "✅ .env file format is valid"
        return 0
    else
        print_error "❌ Found $issues issues in .env file"
        return 1
    fi
}

validate_required_variables() {
    print_status "Checking required environment variables..."
    
    local required_vars=(
        "DOMAIN"
        "POSTGRES_USER"
        "POSTGRES_PASSWORD"
        "JWT_SECRET_KEY"
        "SECRET_KEY"
        "REDIS_PASSWORD"
        "DDNS_UPDATE_URL"
    )
    
    local missing_vars=()
    
    # Source the .env file
    if [ -f "$ENV_FILE" ]; then
        set -a
        source "$ENV_FILE"
        set +a
    fi
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -eq 0 ]; then
        print_status "✅ All required variables are set"
        return 0
    else
        print_error "❌ Missing required variables:"
        for var in "${missing_vars[@]}"; do
            echo "   - $var"
        done
        return 1
    fi
}

validate_docker_compose() {
    print_status "Validating Docker Compose configuration..."
    
    cd "$PROJECT_DIR"
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        print_error "Docker Compose file not found: $COMPOSE_FILE"
        return 1
    fi
    
    # Test configuration
    if docker-compose -f "$COMPOSE_FILE" config > /dev/null 2>&1; then
        print_status "✅ Docker Compose configuration is valid"
        return 0
    else
        print_error "❌ Invalid Docker Compose configuration:"
        docker-compose -f "$COMPOSE_FILE" config 2>&1 | head -20
        return 1
    fi
}

check_docker_status() {
    print_status "Checking Docker status..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        return 1
    fi
    
    if ! systemctl is-active --quiet docker; then
        print_error "Docker service is not running"
        echo "Run: sudo systemctl start docker"
        return 1
    fi
    
    if ! docker ps &> /dev/null; then
        print_error "Cannot connect to Docker daemon"
        echo "Try: sudo usermod -aG docker $USER && newgrp docker"
        return 1
    fi
    
    print_status "✅ Docker is running and accessible"
    return 0
}

check_ports() {
    print_status "Checking port availability..."
    
    local ports=(80 443)
    local port_issues=0
    
    for port in "${ports[@]}"; do
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            local process=$(netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | head -1)
            print_warning "Port $port is already in use by: $process"
            port_issues=$((port_issues + 1))
        else
            print_status "✅ Port $port is available"
        fi
    done
    
    if [ $port_issues -eq 0 ]; then
        return 0
    else
        print_warning "Some ports are in use. This may cause conflicts."
        return 1
    fi
}

check_ssl_certificates() {
    print_status "Checking SSL certificates..."
    
    local domain="eqtrader.ddnskita.my.id"
    local cert_path="/etc/letsencrypt/live/$domain/fullchain.pem"
    local key_path="/etc/letsencrypt/live/$domain/privkey.pem"
    
    if [ -f "$cert_path" ] && [ -f "$key_path" ]; then
        # Check certificate expiry
        local expiry_date=$(openssl x509 -enddate -noout -in "$cert_path" | cut -d= -f 2)
        local expiry_timestamp=$(date -d "$expiry_date" +%s)
        local current_timestamp=$(date +%s)
        local days_left=$(( (expiry_timestamp - current_timestamp) / 86400 ))
        
        if [ $days_left -gt 30 ]; then
            print_status "✅ SSL certificate valid for $days_left days"
        elif [ $days_left -gt 0 ]; then
            print_warning "⚠️ SSL certificate expires in $days_left days"
        else
            print_error "❌ SSL certificate has expired"
            return 1
        fi
    else
        print_warning "⚠️ SSL certificates not found. System will use HTTP only."
        return 1
    fi
    
    return 0
}

check_ddns_status() {
    print_status "Checking DDNS status..."
    
    local domain="eqtrader.ddnskita.my.id"
    local ddns_url="https://tunnel.hostddns.us/ddns/377b9a29c7bba5435e4b5d53e3ead4aa"
    
    # Test DDNS update
    local response=$(curl -s "$ddns_url" 2>/dev/null)
    
    if echo "$response" | grep -q "success"; then
        print_status "✅ DDNS is working"
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        
        # Test domain resolution
        if nslookup "$domain" &> /dev/null; then
            local resolved_ip=$(nslookup "$domain" | grep "Address:" | tail -1 | awk '{print $2}')
            print_status "✅ Domain resolves to: $resolved_ip"
        else
            print_warning "⚠️ Domain resolution failed"
        fi
    else
        print_error "❌ DDNS update failed"
        echo "Response: $response"
        return 1
    fi
    
    return 0
}

generate_fixed_env() {
    print_status "Generating fixed .env file..."
    
    local backup_file="$ENV_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [ -f "$ENV_FILE" ]; then
        cp "$ENV_FILE" "$backup_file"
        print_status "Original .env backed up to: $backup_file"
    fi
    
    # Generate secure passwords
    local postgres_user="trader_$(openssl rand -hex 4)"
    local postgres_password=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-32)
    local jwt_secret=$(openssl rand -hex 32)
    local encryption_key=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-32)
    local session_secret=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-32)
    local redis_password=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-32)
    
    # Create new .env file
    cat > "$ENV_FILE" << EOF
# QuantConnect Trading Bot - Environment Configuration
# Generated on $(date)

# Environment
NODE_ENV=production
ENVIRONMENT=production
DEBUG=false
FLASK_ENV=production
FLASK_DEBUG=false

# Domain & DDNS
DOMAIN=eqtrader.ddnskita.my.id
DDNS_UPDATE_URL=https://tunnel.hostddns.us/ddns/377b9a29c7bba5435e4b5d53e3ead4aa
DDNS_CHECK_INTERVAL=300
AUTO_UPDATE_DDNS=true

# Database
POSTGRES_DB=quantconnect_trading
POSTGRES_USER=$postgres_user
POSTGRES_PASSWORD=$postgres_password
DATABASE_URL=postgresql://$postgres_user:$postgres_password@db:5432/quantconnect_trading

# Redis
REDIS_PASSWORD=$redis_password
REDIS_URL=redis://:$redis_password@redis:6379/0

# Security
SECRET_KEY=$session_secret
JWT_SECRET_KEY=$jwt_secret
JWT_ACCESS_TOKEN_EXPIRES=1800
ENCRYPTION_KEY=$encryption_key

# API URLs
API_BASE_URL=https://eqtrader.ddnskita.my.id/api
FRONTEND_URL=https://eqtrader.ddnskita.my.id
WEBSOCKET_URL=wss://eqtrader.ddnskita.my.id/socket.io
CORS_ORIGINS=https://eqtrader.ddnskita.my.id
SOCKETIO_CORS_ORIGINS=https://eqtrader.ddnskita.my.id

# React App
REACT_APP_API_URL=https://eqtrader.ddnskita.my.id/api
REACT_APP_WS_URL=wss://eqtrader.ddnskita.my.id/socket.io
REACT_APP_DOMAIN=eqtrader.ddnskita.my.id

# SSL
SSL_ENABLED=true
SSL_CERT_PATH=/etc/letsencrypt/live/eqtrader.ddnskita.my.id/fullchain.pem
SSL_KEY_PATH=/etc/letsencrypt/live/eqtrader.ddnskita.my.id/privkey.pem

# QuantConnect
QC_USER_ID=
QC_API_TOKEN=
QC_ENVIRONMENT=live-trading

# Trading
MAX_DAILY_LOSS=0.05
MAX_POSITION_SIZE=0.10
SIGNAL_CONFIDENCE_THRESHOLD=0.60
MAX_CONCURRENT_TRADES=10

# Logging
LOG_LEVEL=INFO
LOG_FILE_PATH=/app/logs/trading_bot.log

# Monitoring
ENABLE_HEALTH_CHECK=true
HEALTH_CHECK_INTERVAL=30

# Directories
DATA_DIR=/opt/quantconnect-trading-bot/data
LOGS_DIR=/opt/quantconnect-trading-bot/logs
MODELS_DIR=/app/models/trained_models

# Broker API Keys - Configure these
BINANCE_API_KEY=your_binance_api_key
BINANCE_SECRET_KEY=your_binance_secret_key
BINANCE_TESTNET=true

KRAKEN_API_KEY=your_kraken_api_key
KRAKEN_SECRET_KEY=your_kraken_secret_key

XTB_USER_ID=your_xtb_user_id
XTB_PASSWORD=your_xtb_password
XTB_DEMO=true
EOF
    
    chmod 600 "$ENV_FILE"
    
    print_status "✅ New .env file created with secure credentials"
    
    echo ""
    echo -e "${YELLOW}🔐 GENERATED CREDENTIALS:${NC}"
    echo "   Database User: $postgres_user"
    echo "   Database Password: $postgres_password"
    echo "   JWT Secret: $jwt_secret"
    echo "   Redis Password: $redis_password"
    echo ""
    echo -e "${GREEN}💾 Save these credentials securely!${NC}"
    echo ""
}

run_full_validation() {
    local exit_code=0
    
    print_header
    
    echo "Running comprehensive environment validation..."
    echo ""
    
    # Run all checks
    validate_env_file || exit_code=1
    echo ""
    
    validate_required_variables || exit_code=1
    echo ""
    
    check_docker_status || exit_code=1
    echo ""
    
    validate_docker_compose || exit_code=1
    echo ""
    
    check_ports || exit_code=1
    echo ""
    
    check_ssl_certificates || true  # Don't fail on SSL issues
    echo ""
    
    check_ddns_status || true  # Don't fail on DDNS issues
    echo ""
    
    # Summary
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✅ VALIDATION PASSED${NC}"
        echo "System appears to be configured correctly."
        echo ""
        echo "Next steps:"
        echo "1. Configure broker API keys in .env"
        echo "2. Start system: trading-bot start"
        echo "3. Check status: trading-bot status"
    else
        echo -e "${RED}❌ VALIDATION FAILED${NC}"
        echo "Please fix the issues above before starting the system."
        echo ""
        echo "Quick fixes:"
        echo "1. Fix .env file: $0 --fix-env"
        echo "2. Start Docker: sudo systemctl start docker"
        echo "3. Add user to docker group: sudo usermod -aG docker \$USER"
    fi
    
    return $exit_code
}

# Command line options
case "$1" in
    --fix-env)
        generate_fixed_env
        ;;
    --check-env)
        validate_env_file && validate_required_variables
        ;;
    --check-docker)
        check_docker_status && validate_docker_compose
        ;;
    --check-ssl)
        check_ssl_certificates
        ;;
    --check-ddns)
        check_ddns_status
        ;;
    --full|"")
        run_full_validation
        ;;
    --help)
        echo "Usage: $0 [OPTION]"
        echo ""
        echo "Options:"
        echo "  --full          Run full validation (default)"
        echo "  --fix-env       Generate a new fixed .env file"
        echo "  --check-env     Validate .env file only"
        echo "  --check-docker  Check Docker configuration"
        echo "  --check-ssl     Check SSL certificates"
        echo "  --check-ddns    Check DDNS status"
        echo "  --help          Show this help"
        echo ""
        echo "Examples:"
        echo "  $0                # Run full validation"
        echo "  $0 --fix-env     # Fix .env file issues"
        echo "  $0 --check-env   # Check .env file only"
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac