# 🚀 QuantConnect Trading Bot

**Enterprise-Grade Automated Trading Platform with AI/ML Integration**

[![Production Status](https://img.shields.io/badge/Production-Live-brightgreen)](https://eqtrader.ddnskita.my.id)
[![Docker](https://img.shields.io/badge/Docker-Supported-blue)](https://docker.com)
[![Python](https://img.shields.io/badge/Python-3.9+-blue)](https://python.org)
[![React](https://img.shields.io/badge/React-18+-blue)](https://reactjs.org)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

A comprehensive automated trading platform that integrates with 20+ brokers and exchanges, featuring advanced AI/ML capabilities, real-time market data processing, and professional-grade risk management.

## 🌐 **Live Demo**

**Production URL:** [https://eqtrader.ddnskita.my.id](https://eqtrader.ddnskita.my.id)

- **Frontend Dashboard:** Real-time trading interface
- **API Documentation:** `/api/docs`
- **System Health:** `/health`
- **WebSocket:** Real-time data feeds

---

## ✨ **Key Features**

### 🏦 **Multi-Broker Support**
- **Forex/CFD:** XM, IC Markets, XTB, IG Group, Admiral Markets, RoboForex, FBS, InstaForex, Plus500, SabioTrade
- **Cryptocurrency:** Binance, Kraken, Coinbase Pro, Bybit, KuCoin, OKX, Bitfinex, Gemini, Huobi, Bittrex
- **Traditional:** Interactive Brokers integration ready

### 🤖 **AI/ML Integration**
- **Model Import/Export:** Support for `.pkl`, `.h5`, `.joblib` formats
- **Real-time Predictions:** Automated signal generation
- **Model Management:** Version control and A/B testing
- **Performance Analytics:** Comprehensive model evaluation

### 📊 **Advanced Features**
- **Real-time Trading:** WebSocket-based market data
- **Risk Management:** Position sizing, correlation limits, stop-loss
- **Backtesting:** Historical strategy validation
- **Portfolio Analytics:** Performance metrics, drawdown analysis
- **Multi-timeframe:** Support for various trading timeframes

### 🔧 **Technical Stack**
- **Backend:** Python 3.9+ (Flask, SQLAlchemy, SocketIO)
- **Frontend:** React 18+ (Material-UI, WebSocket integration)
- **Database:** PostgreSQL with Redis caching
- **Container:** Docker with production orchestration
- **Trading Engine:** QuantConnect Lean integration
- **Monitoring:** Health checks, alerts, logging

---

## 🚀 **Quick Start**

### **One-Command Installation (Ubuntu/Debian)**

```bash
# Download and run the installer
curl -fsSL https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh | sudo bash
```

### **Manual Installation**

```bash
# 1. Clone the repository
git clone https://github.com/szarastrefa/quantconnect-trading-bot.git
cd quantconnect-trading-bot

# 2. Copy environment configuration
cp .env.production .env
nano .env  # Configure your broker API keys

# 3. Start the system
sudo ./scripts/setup_ubuntu.sh --production --ssl

# 4. Manage the system
./scripts/manage.sh start
```

### **Development Setup**

```bash
# Clone and start development environment
git clone https://github.com/szarastrefa/quantconnect-trading-bot.git
cd quantconnect-trading-bot

# Start development containers
docker-compose up --build

# Access:
# Frontend: http://localhost:3000
# Backend: http://localhost:5000
# API Docs: http://localhost:5000/docs
```

---

## 📁 **Project Structure**

```
quantconnect-trading-bot/
├── 🔧 backend/
│   ├── api/                    # REST API endpoints
│   ├── services/               # Core trading services
│   │   ├── broker_service.py   # Multi-broker integration
│   │   ├── ml_service.py       # AI/ML model management
│   │   ├── lean_service.py     # QuantConnect integration
│   │   └── ddns_service.py     # Domain management
│   ├── utils/                  # Helper utilities
│   └── app.py                  # Main Flask application
├── ⚛️ frontend/
│   ├── src/components/         # React components
│   │   ├── Dashboard.js        # Main trading dashboard
│   │   ├── BrokerConfig.js     # Broker configuration
│   │   ├── ModelManager.js     # ML model management
│   │   └── TradingInterface.js # Trading controls
│   └── package.json            # Dependencies
├── 🐳 Docker/
│   ├── docker-compose.yml      # Development setup
│   ├── docker-compose.production.yml  # Production setup
│   └── nginx/                  # Reverse proxy config
├── 📜 scripts/
│   ├── setup_ubuntu.sh         # One-command installer
│   ├── manage.sh               # System management
│   ├── check_system_integrity.py  # Health checker
│   └── backup_system.sh        # Backup utilities
├── 📚 docs/
│   └── BROKER_WORKFLOWS.md     # Broker integration guide
└── 📊 config/
    ├── .env.production         # Production config template
    └── broker_templates.json   # Broker configurations
```

---

## 🏦 **Supported Brokers & Exchanges**

### **Forex & CFD Brokers**

| Broker | Status | API Type | Leverage | Min Deposit |
|--------|--------|----------|----------|-------------|
| **XM** | ✅ Ready | MT5 | 1:888 | $5 |
| **IC Markets** | ✅ Ready | MT5/cTrader | 1:500 | $200 |
| **XTB** | ✅ Ready | xAPI | 1:30 | €250 |
| **IG Group** | ✅ Ready | REST API | 1:30 | £250 |
| **Admiral Markets** | ✅ Ready | MT5 | 1:30 | €100 |
| **RoboForex** | 🔄 Integration | cTrader | 1:2000 | $10 |
| **FBS** | 🔄 Integration | MT5 | 1:3000 | $5 |
| **InstaForex** | 🔄 Integration | MT5 | 1:1000 | $1 |
| **Plus500** | 🔄 Integration | WebTrader | 1:30 | $100 |
| **SabioTrade** | 🔄 Integration | Custom API | 1:400 | $250 |

### **Cryptocurrency Exchanges**

| Exchange | Status | Trading Types | Leverage | Fees |
|----------|--------|---------------|----------|------|
| **Binance** | ✅ Ready | Spot, Futures, Margin | 125x | 0.1% |
| **Kraken** | ✅ Ready | Spot, Futures | 5x | 0.16% |
| **Coinbase Pro** | ✅ Ready | Spot, Advanced | 1x | 0.5% |
| **Bybit** | ✅ Ready | Derivatives | 100x | 0.1% |
| **KuCoin** | ✅ Ready | Spot, Futures | 100x | 0.1% |
| **OKX** | ✅ Ready | Multi-asset | 125x | 0.08% |
| **Bitfinex** | ✅ Ready | Spot, Margin | 10x | 0.1% |
| **Gemini** | ✅ Ready | Spot | 1x | 0.25% |
| **Huobi** | 🔄 Integration | Spot, Futures | 125x | 0.2% |
| **Bittrex** | 🔄 Integration | Spot | 1x | 0.25% |
| **Bitstamp** | 🔄 Integration | Spot | 1x | 0.5% |

**Legend:** ✅ Production Ready | 🔄 In Development | ⚠️ Limited Support

---

## 🤖 **AI/ML Integration**

### **Supported Model Formats**
- **Scikit-learn:** `.pkl`, `.joblib` files
- **TensorFlow/Keras:** `.h5` files
- **PyTorch:** `.pt`, `.pth` files (planned)
- **ONNX:** `.onnx` files (planned)

### **Model Management Features**
```python
# Example: Import and use ML model
from backend.services.ml_service import MLService

ml_service = MLService()

# Import model
model_id = ml_service.import_model(
    file_path="my_trading_model.pkl",
    name="EURUSD Predictor",
    description="Random Forest model for EUR/USD prediction"
)

# Generate predictions
prediction = ml_service.predict(
    model_id=model_id,
    features=market_data
)

# Use in trading strategy
if prediction['confidence'] > 0.7:
    place_trade(symbol="EURUSD", action=prediction['signal'])
```

### **Available ML Features**
- **Signal Generation:** Buy/Sell/Hold predictions
- **Risk Scoring:** Portfolio risk assessment
- **Market Regime Detection:** Bull/Bear/Sideways classification
- **Volatility Forecasting:** Expected price movement
- **Sentiment Analysis:** News and social media sentiment

---

## 🔧 **Configuration**

### **Environment Variables**

Copy `.env.production` to `.env` and configure:

```bash
# Domain & DDNS
DOMAIN=eqtrader.ddnskita.my.id
DDNS_UPDATE_URL=https://tunnel.hostddns.us/ddns/377b9a29c7bba5435e4b5d53e3ead4aa

# Database
POSTGRES_PASSWORD=your_secure_password
REDIS_PASSWORD=your_redis_password

# Security
SECRET_KEY=your_secret_key
JWT_SECRET_KEY=your_jwt_secret

# Broker API Keys
BINANCE_API_KEY=your_binance_api_key
BINANCE_SECRET_KEY=your_binance_secret
KRAKEN_API_KEY=your_kraken_api_key
# ... additional broker configurations
```

### **Broker Configuration**

Each broker requires specific credentials:

```python
# Example: Binance configuration
broker_config = {
    "name": "Binance",
    "type": "ccxt",
    "api_key": "your_api_key",
    "secret_key": "your_secret_key",
    "testnet": False,  # Set to True for testing
    "features": ["spot", "futures", "margin"]
}
```

---

## 🛠️ **System Management**

### **Management Commands**

```bash
# System control
./scripts/manage.sh start          # Start all services
./scripts/manage.sh stop           # Stop all services
./scripts/manage.sh restart        # Restart system
./scripts/manage.sh status         # Show system status

# Monitoring
./scripts/manage.sh logs           # View all logs
./scripts/manage.sh logs api       # View API logs
./scripts/manage.sh health         # Run health check

# Maintenance
./scripts/manage.sh update         # Update from repository
./scripts/manage.sh backup         # Create system backup
./scripts/manage.sh cleanup        # Clean unused resources

# Utilities
./scripts/manage.sh ddns-update    # Update DDNS record
./scripts/manage.sh web            # Open web interface
```

### **Health Monitoring**

```bash
# Comprehensive system check
python scripts/check_system_integrity.py --verbose

# Generate health report
python scripts/check_system_integrity.py --output health_report.json

# Monitor in real-time
watch -n 30 './scripts/manage.sh status'
```

---

## 📊 **API Documentation**

### **Core Endpoints**

#### **Trading Operations**
```http
GET    /api/brokers                # List available brokers
POST   /api/brokers/{id}/connect   # Connect to broker
GET    /api/brokers/{id}/account   # Get account info
POST   /api/trading/signals        # Generate trading signals
POST   /api/trading/orders         # Place orders
GET    /api/trading/positions      # Get positions
```

#### **ML Model Management**
```http
GET    /api/models                 # List models
POST   /api/models/import          # Import model
GET    /api/models/{id}/export     # Export model
POST   /api/models/{id}/predict    # Generate prediction
POST   /api/models/{id}/train      # Train model
```

#### **System Monitoring**
```http
GET    /api/health                 # System health
GET    /api/status                 # Detailed status
GET    /api/metrics               # Performance metrics
GET    /api/ddns/status           # DDNS status
```

### **WebSocket Events**

```javascript
// Connect to WebSocket
const socket = io('wss://eqtrader.ddnskita.my.id/socket.io');

// Listen for market data
socket.on('market_data', (data) => {
    console.log('Price update:', data);
});

// Listen for trading signals
socket.on('trading_signals', (signals) => {
    console.log('New signals:', signals);
});

// Listen for system alerts
socket.on('system_alert', (alert) => {
    console.log('Alert:', alert);
});
```

---

## 🔒 **Security Features**

### **Production Security**
- **SSL/TLS:** Automatic certificate management with Let's Encrypt
- **HTTPS Redirect:** All HTTP traffic redirected to HTTPS
- **Security Headers:** HSTS, CSP, X-Frame-Options
- **Rate Limiting:** API endpoint protection
- **Firewall:** UFW with restrictive rules
- **Secrets Management:** Environment variable isolation

### **API Security**
- **JWT Authentication:** Secure token-based auth
- **API Key Management:** Per-broker secure key storage
- **Input Validation:** Comprehensive data sanitization
- **CORS Protection:** Origin-based access control
- **Request Logging:** Comprehensive audit trail

---

## 📈 **Performance & Monitoring**

### **System Metrics**
- **Response Time:** API endpoint latency monitoring
- **Throughput:** Requests per second tracking
- **Error Rates:** Failed request monitoring
- **Resource Usage:** CPU, memory, disk utilization
- **Trading Metrics:** P&L, win rate, drawdown

### **Alerting Channels**
- **Email:** SMTP-based notifications
- **Slack:** Webhook integration
- **Telegram:** Bot-based alerts
- **Log Files:** Structured logging with rotation

### **Performance Optimizations**
- **Redis Caching:** Fast data retrieval
- **Connection Pooling:** Efficient database usage
- **WebSocket:** Real-time data streaming
- **Docker:** Resource isolation and scaling
- **Nginx:** Load balancing and compression

---

## 🌐 **Production Deployment**

### **DDNS Integration**
The system includes automatic DDNS management for **eqtrader.ddnskita.my.id**:

- **Automatic IP Updates:** Monitors and updates DNS records
- **Tunnel Integration:** Uses hostddns.us for reliable connectivity
- **Health Monitoring:** Ensures domain availability
- **SSL Management:** Automatic certificate renewal

### **Docker Production Stack**
```yaml
# Production services
services:
  nginx:          # Reverse proxy with SSL
  api:            # Backend API server
  frontend:       # React web interface
  db:             # PostgreSQL database
  redis:          # Cache and message broker
  lean_engine:    # QuantConnect trading engine
  ddns_updater:   # Domain management
  monitor:        # System health monitoring
```

### **Scaling Considerations**
- **Horizontal Scaling:** Multiple API instances
- **Database Optimization:** Connection pooling, indexing
- **Caching Strategy:** Redis for frequently accessed data
- **Load Balancing:** Nginx upstream configuration
- **Monitoring:** Real-time health checks

---

## 🧪 **Testing**

### **Test Accounts**
Most brokers provide demo/testnet accounts:

```bash
# Enable demo mode in .env
BINANCE_TESTNET=true
XTB_DEMO=true
COINBASE_SANDBOX=true
IG_DEMO=true
```

### **Running Tests**
```bash
# Backend tests
cd backend
python -m pytest tests/

# Frontend tests
cd frontend
npm test

# Integration tests
python scripts/test_broker_connections.py

# System integrity check
python scripts/check_system_integrity.py
```

---

## 🤝 **Contributing**

### **Development Workflow**
1. Fork the repository
2. Create a feature branch: `git checkout -b feature/new-broker`
3. Commit changes: `git commit -am 'Add new broker integration'`
4. Push to branch: `git push origin feature/new-broker`
5. Submit a Pull Request

### **Adding New Brokers**
1. Create broker class in `backend/brokers/`
2. Add configuration to `config/broker_templates.json`
3. Update documentation in `docs/BROKER_WORKFLOWS.md`
4. Add tests in `tests/brokers/`
5. Submit PR with integration examples

---

## 📞 **Support**

### **Documentation**
- **API Docs:** [https://eqtrader.ddnskita.my.id/api/docs](https://eqtrader.ddnskita.my.id/api/docs)
- **Broker Workflows:** [docs/BROKER_WORKFLOWS.md](docs/BROKER_WORKFLOWS.md)
- **System Architecture:** [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

### **Community**
- **Issues:** [GitHub Issues](https://github.com/szarastrefa/quantconnect-trading-bot/issues)
- **Discussions:** [GitHub Discussions](https://github.com/szarastrefa/quantconnect-trading-bot/discussions)
- **Wiki:** [Project Wiki](https://github.com/szarastrefa/quantconnect-trading-bot/wiki)

### **Commercial Support**
For enterprise deployments, custom integrations, or commercial support:
- **Email:** support@eqtrader.ddnskita.my.id
- **Consultation:** Available for custom broker integrations
- **Training:** System administration and trading strategy development

---

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ **Risk Disclaimer**

**Trading involves substantial risk of loss and is not suitable for all investors.** Past performance does not guarantee future results. The use of this software is at your own risk. The authors and contributors are not responsible for any financial losses incurred through the use of this trading bot.

**Key Risks:**
- **Market Risk:** Cryptocurrency and forex markets are highly volatile
- **Technical Risk:** Software bugs or connectivity issues may cause losses
- **Broker Risk:** Third-party broker failures or API changes
- **Model Risk:** AI/ML predictions may be inaccurate
- **Regulatory Risk:** Trading regulations may change

**Recommendations:**
- Start with demo accounts and small amounts
- Implement proper risk management
- Monitor positions actively
- Keep software updated
- Maintain adequate capital reserves

---

## 🌟 **Acknowledgments**

- **QuantConnect:** For the powerful Lean trading engine
- **CCXT:** For unified cryptocurrency exchange APIs
- **MetaTrader:** For forex broker integrations
- **Docker:** For containerization platform
- **React & Flask:** For modern web technologies
- **Community Contributors:** For broker integrations and improvements

---

**Made with ❤️ for algorithmic traders worldwide**

[![Live System](https://img.shields.io/badge/Live%20System-eqtrader.ddnskita.my.id-brightgreen)](https://eqtrader.ddnskita.my.id)
[![GitHub Stars](https://img.shields.io/github/stars/szarastrefa/quantconnect-trading-bot?style=social)](https://github.com/szarastrefa/quantconnect-trading-bot)
[![Docker Pulls](https://img.shields.io/docker/pulls/quantconnect/lean)](https://hub.docker.com/r/quantconnect/lean)

---

**🚀 Ready to start algorithmic trading? [Get started now!](https://eqtrader.ddnskita.my.id)**