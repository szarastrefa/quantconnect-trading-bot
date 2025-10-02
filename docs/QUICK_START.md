# 🚀 Quick Start Guide - QuantConnect Trading Bot

**Get your algorithmic trading system running in 5 minutes!**

This guide covers the fastest ways to install and start using the QuantConnect Trading Bot with support for 20+ brokers and AI/ML integration.

---

## ⚡ **One-Command Installation**

### **Standard Production Setup (Recommended)**
```bash
# Full production installation with SSL and DDNS
curl -fsSL https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh | bash
```

### **Skip DDNS Issues (If DDNS Fails)**
```bash
# If you get DDNS errors like "Masih Sama!" or connection issues
curl -fsSL https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh | bash -s -- --skip-ddns-error
```

### **Development Mode (Testing)**
```bash
# Quick development setup - HTTP only, no SSL/firewall
curl -fsSL https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh | bash -s -- --dev-mode
```

### **Minimal Installation**
```bash
# Minimal setup - core services only
curl -fsSL https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh | bash -s -- --minimal
```

---

## 🔧 **Installation Options Reference**

### **🎯 Common Use Cases:**

| Scenario | Command |
|----------|----------|
| **First time install** | `curl -fsSL ... \| bash` |
| **DDNS problems** | `curl -fsSL ... \| bash -s -- --skip-ddns-error` |
| **Development/Testing** | `curl -fsSL ... \| bash -s -- --dev-mode` |
| **Reinstall over existing** | `curl -fsSL ... \| bash -s -- --force-install` |
| **No SSL needed** | `curl -fsSL ... \| bash -s -- --skip-ssl` |
| **Custom domain** | `curl -fsSL ... \| bash -s -- --domain your.domain.com` |

### **🎮 All Available Options:**

#### **Installation Modes:**
- `--production` - Full production setup (default)
- `--dev-mode` - Development setup (HTTP, local ports)
- `--minimal` - Core services only
- `--interactive` - Choose options during install

#### **Skip Options:**
- `--skip-ddns-error` - Continue if DDNS fails ⭐ **Most Used**
- `--skip-ssl` - Skip SSL certificates
- `--skip-firewall` - Skip UFW firewall
- `--skip-system-update` - Skip apt updates
- `--skip-nginx` - Skip reverse proxy
- `--skip-deps` - Skip dependencies

#### **Advanced Options:**
- `--force-install` - Remove existing installation
- `--no-auto-start` - Don't start services
- `--verbose` - Detailed output
- `--quiet` - Minimal output

#### **Customization:**
- `--domain DOMAIN` - Custom domain
- `--port PORT` - Custom port
- `--data-dir DIR` - Custom data directory

---

## 📋 **What Gets Installed**

### **🏗️ Core Components:**
- **Docker & Docker Compose** - Container orchestration
- **PostgreSQL Database** - Trading data storage
- **Redis Cache** - Fast data access
- **Nginx Reverse Proxy** - SSL termination & load balancing
- **Python Flask API** - REST API backend
- **React Frontend** - Web-based trading dashboard

### **🌐 Network Configuration:**
- **Production URL:** https://eqtrader.ddnskita.my.id
- **DDNS Auto-Update** - Keeps domain pointing to your server
- **SSL/TLS Certificates** - Let's Encrypt automatic renewal
- **Firewall Rules** - UFW configured for security

### **📊 Trading Features:**
- **20+ Broker Integration** - Forex, crypto, traditional
- **AI/ML Model Support** - Import .pkl, .h5, .joblib files
- **Real-time Data Feeds** - WebSocket market data
- **QuantConnect Lean** - Professional backtesting engine
- **Risk Management** - Position sizing, stop-loss automation

---

## ⚙️ **Post-Installation Setup**

### **1. 🔐 Generated Credentials**
After installation, you'll see credentials like:
```
🔐 GENERATED CREDENTIALS (SAVE THESE!):
├─ Database User: trader_k7m9
├─ Database Password: X8nM2pQ7rT4vW9xY5zA3bC6e
├─ JWT Secret: f9e8d7c6b5a4321098765432...
├─ Encryption Key: L6kJ4hG8fD9sA2pO7iU5yT1r
├─ Session Secret: P3mK9nJ6vC8xZ4aW2qE7rT5y
└─ Redis Password: M2nK5jH8gF3sD9pL4iY7tR6w
```
**⚠️ Save these in a password manager!**

### **2. 🏢 Configure Broker API Keys**
```bash
# Edit configuration file
nano /opt/quantconnect-trading-bot/.env

# Add your broker credentials:
BINANCE_API_KEY=your_binance_api_key
BINANCE_SECRET_KEY=your_binance_secret_key
XTB_USER_ID=your_xtb_login
XTB_PASSWORD=your_xtb_password
# ... etc for other brokers
```

### **3. 🚀 Start the System**
```bash
# Start all services
trading-bot start

# Check status
trading-bot status

# View logs
trading-bot logs
```

### **4. 🌐 Access Web Interface**
- **Production:** https://eqtrader.ddnskita.my.id
- **Development:** http://localhost:3000
- **API Docs:** https://eqtrader.ddnskita.my.id/api/docs

---

## 🎯 **Supported Brokers**

### **💱 Forex & CFD (10 Brokers):**
- ✅ **XM** - MT4/MT5 integration
- ✅ **XTB** - xAPI protocol  
- ✅ **IC Markets** - cTrader & REST API
- ✅ **IG Group** - Professional API
- ✅ **Admiral Markets** - Multi-platform
- ✅ **RoboForex** - MT4/MT5 + Web API
- ✅ **FBS** - Proprietary API
- ✅ **InstaForex** - MT4 integration
- ✅ **Plus500** - WebTrader API
- ✅ **SabioTrade** - Custom integration

### **₿ Cryptocurrency (11 Exchanges):**
- ✅ **Binance** - Spot + Futures API
- ✅ **Kraken** - Professional trading
- ✅ **Coinbase Pro** - Advanced Trade API
- ✅ **Bybit** - Derivatives trading
- ✅ **KuCoin** - Professional API
- ✅ **OKX** - V5 Unified API
- ✅ **Bitfinex** - Advanced features
- ✅ **Gemini** - ActiveTrader
- ✅ **Huobi** - Global markets
- ✅ **Bittrex** - US compliant
- ✅ **Bitstamp** - European exchange

---

## 🤖 **AI/ML Integration**

### **📥 Model Import Formats:**
- **Scikit-learn:** `.pkl`, `.joblib`
- **TensorFlow/Keras:** `.h5`
- **PyTorch:** `.pt`, `.pth` (planned)
- **ONNX:** `.onnx` (planned)

### **🧠 ML Features:**
- **Signal Generation** - Buy/Sell/Hold predictions
- **Risk Assessment** - Portfolio risk scoring
- **Market Regime** - Bull/Bear/Sideways detection
- **Volatility Forecasting** - Expected price movement
- **Sentiment Analysis** - News & social sentiment

---

## 🛠️ **System Management**

### **🎮 Quick Commands:**
```bash
# System control
trading-bot start     # Start all services
trading-bot stop      # Stop all services
trading-bot restart   # Restart system
trading-bot status    # Show status

# Monitoring
trading-bot logs      # View all logs
trading-bot logs api  # View API logs only
trading-bot health    # Run health check
trading-bot monitor   # Real-time monitoring

# Maintenance
trading-bot update    # Update from GitHub
trading-bot backup    # Create backup
trading-bot cleanup   # Clean unused resources

# DDNS management
trading-bot ddns-update  # Manual DDNS update
```

### **📊 Web Management:**
- **Trading Dashboard** - Live trading interface
- **Model Manager** - Upload/manage ML models
- **Broker Configuration** - Multi-broker setup
- **Performance Analytics** - P&L tracking
- **Risk Controls** - Position limits & rules
- **System Health** - Monitoring & alerts

---

## 🚨 **Common Issues & Solutions**

### **❌ DDNS Errors**
**Error:** `"result":"failed","message":"Public Address Masih Sama!"`

**Solution:**
```bash
# Use the skip flag - this is normal when IP hasn't changed
curl -fsSL https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh | bash -s -- --skip-ddns-error
```

### **❌ SSL Certificate Issues**
**Error:** SSL certificate obtainment fails

**Solutions:**
```bash
# Skip SSL for now (use HTTP)
curl -fsSL ... | bash -s -- --skip-ssl

# Or development mode
curl -fsSL ... | bash -s -- --dev-mode
```

### **❌ Permission Denied (Docker)**
**Error:** Cannot connect to Docker daemon

**Solution:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Or reboot and try again
sudo reboot
```

### **❌ Port Already in Use**
**Error:** Port 80/443 already in use

**Solution:**
```bash
# Stop conflicting services
sudo systemctl stop apache2
sudo systemctl stop nginx

# Then retry installation
curl -fsSL ... | bash -s -- --force-install
```

### **❌ Out of Space**
**Error:** No space left on device

**Solution:**
```bash
# Clean up Docker
docker system prune -a

# Clean package cache
sudo apt clean
sudo apt autoremove

# Or use minimal installation
curl -fsSL ... | bash -s -- --minimal
```

---

## 📞 **Getting Help**

### **🆘 Support Channels:**
- **GitHub Issues:** [Create Issue](https://github.com/szarastrefa/quantconnect-trading-bot/issues)
- **Documentation:** [Full Docs](https://github.com/szarastrefa/quantconnect-trading-bot)
- **Troubleshooting:** [Troubleshooting Guide](https://github.com/szarastrefa/quantconnect-trading-bot/blob/main/docs/TROUBLESHOOTING.md)
- **Discussions:** [GitHub Discussions](https://github.com/szarastrefa/quantconnect-trading-bot/discussions)

### **📋 When Asking for Help:**
1. **Include your installation command**
2. **Share error messages** (redact API keys!)
3. **System info:** Ubuntu version, RAM, disk space
4. **Run diagnostics:**
```bash
# Generate diagnostic report
./scripts/validate_environment.sh > diagnostic_report.txt

# Check system info
uname -a
free -h
df -h
docker --version
```

---

## 🏆 **Next Steps**

### **🎯 Immediate Actions:**
1. ✅ **Install the system** (5 minutes)
2. ✅ **Configure broker API keys** (10 minutes)
3. ✅ **Start trading** (test with demo accounts first)
4. ✅ **Upload ML models** (optional)
5. ✅ **Monitor performance** (ongoing)

### **📚 Advanced Learning:**
- **Strategy Development** - Create custom trading algorithms
- **Model Training** - Build your own ML models
- **Multi-Broker Arbitrage** - Trade across multiple exchanges
- **Risk Management** - Advanced portfolio protection
- **Performance Optimization** - Scale to handle more data

### **🔗 Useful Links:**
- **Live Demo:** https://eqtrader.ddnskita.my.id
- **API Documentation:** https://eqtrader.ddnskita.my.id/api/docs  
- **Model Templates:** [ML Examples](https://github.com/szarastrefa/quantconnect-trading-bot/tree/main/examples/ml_models)
- **Strategy Examples:** [Trading Strategies](https://github.com/szarastrefa/quantconnect-trading-bot/tree/main/examples/strategies)

---

**🚀 Ready to start algorithmic trading? Run the installation command now!**

```bash
curl -fsSL https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh | bash -s -- --skip-ddns-error
```

**⚠️ Remember: Always test with demo accounts before live trading!**

---

*Made with ❤️ for algorithmic traders worldwide*