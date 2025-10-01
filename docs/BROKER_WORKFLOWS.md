# Broker Integration Workflows

This document describes the complete workflow for integrating with various brokers and exchanges supported by the QuantConnect Trading Bot.

## Overview

The trading bot supports three main categories of brokers:
- **Forex/CFD Brokers**: XM, IC Markets, RoboForex, InstaForex, FBS, XTB, Admiral Markets, IG Group, Plus500, SabioTrade
- **Cryptocurrency Exchanges**: Binance, Coinbase Pro, Kraken, Bitstamp, Bitfinex, Gemini, Huobi, OKX, Bybit, KuCoin, Bittrex
- **Traditional Brokers**: Interactive Brokers, TD Ameritrade, Schwab (via API integrations)

## Common Workflow Structure

All broker integrations follow a standardized workflow:

1. **Authentication & Connection**
2. **Account Information Retrieval**
3. **Market Data Subscription**
4. **Signal Processing**
5. **Order Execution**
6. **Position Management**
7. **Risk Management**
8. **Reporting & Monitoring**

---

## Forex/CFD Brokers

### MetaTrader 5 Based Brokers (XM, IC Markets, RoboForex, InstaForex, FBS, Admiral Markets)

#### 1. Authentication & Connection
```python
# Configuration required:
broker_config = {
    "login": "12345678",           # MT5 account number
    "password": "your_password",   # Account password
    "server": "broker_server",     # MT5 server name
    "path": "/path/to/mt5",        # Optional: MT5 installation path
    "timeout": 60000,             # Connection timeout (ms)
    "portable": False             # Use portable mode
}
```

#### 2. Connection Workflow
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Trading Bot   │───▶│   MT5 Connector  │───▶│  Broker Server  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ Signal Generator│    │ Order Management │    │ Market Data     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

#### 3. Supported Operations

**XM Broker Workflow:**
- **Assets**: 1000+ instruments (Forex, Commodities, Indices, Crypto CFDs)
- **Max Leverage**: 1:888
- **Min Deposit**: $5
- **Order Types**: Market, Limit, Stop, Stop Limit
- **Execution**: Instant, Request, Market

**IC Markets Workflow:**
- **Assets**: 2000+ instruments
- **Max Leverage**: 1:500
- **Min Deposit**: $200
- **Spreads**: From 0.0 pips (Raw Spread account)
- **Execution**: True ECN

**RoboForex Workflow:**
- **Assets**: 12,000+ instruments
- **Max Leverage**: 1:2000
- **Min Deposit**: $10
- **Special Features**: CopyFX, RAMM, Analytics

#### 4. Example Implementation
```python
def connect_mt5_broker(broker_name, config):
    """
    Connect to MT5-based broker
    """
    try:
        # Initialize MT5
        if not mt5.initialize():
            return {"error": "MT5 initialization failed"}
        
        # Login to broker
        authorized = mt5.login(
            login=config['login'],
            password=config['password'],
            server=config['server']
        )
        
        if not authorized:
            return {"error": f"Login failed: {mt5.last_error()}"}
        
        # Get account info
        account_info = mt5.account_info()
        
        return {
            "success": True,
            "broker": broker_name,
            "account": {
                "balance": account_info.balance,
                "equity": account_info.equity,
                "margin": account_info.margin,
                "leverage": account_info.leverage,
                "currency": account_info.currency
            }
        }
        
    except Exception as e:
        return {"error": str(e)}
```

### XTB Broker Workflow

#### 1. Authentication
```python
xtb_config = {
    "user_id": "your_user_id",
    "password": "your_password",
    "demo": True,  # Use demo account
    "app_name": "QuantConnect Bot"
}
```

#### 2. Connection Process
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Trading Bot   │───▶│   XTB xStation   │───▶│   XTB Servers   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │              ┌────────▼────────┐               │
         │              │ Streaming API   │               │
         │              └─────────────────┘               │
         ▼                       │                       ▼
┌─────────────────┐    ┌──────────▼──────┐    ┌─────────────────┐
│ WebSocket Conn. │    │ Command API     │    │ Real-time Data  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

#### 3. XTB Implementation
```python
import websocket
import json

class XTBConnector:
    def __init__(self, config):
        self.config = config
        self.ws = None
        self.stream_ws = None
        
    def connect(self):
        # Main API connection
        self.ws = websocket.create_connection("wss://ws.xtb.com/demoStream")
        
        # Login
        login_command = {
            "command": "login",
            "arguments": {
                "userId": self.config['user_id'],
                "password": self.config['password'],
                "appName": self.config['app_name']
            }
        }
        
        self.ws.send(json.dumps(login_command))
        response = json.loads(self.ws.recv())
        
        if response.get('status') == True:
            # Setup streaming connection
            self.setup_streaming(response['streamSessionId'])
            return True
        return False
```

### IG Group Workflow

#### 1. REST API Authentication
```python
ig_config = {
    "api_key": "your_api_key",
    "username": "your_username", 
    "password": "your_password",
    "demo": True,
    "version": "3"  # API version
}
```

#### 2. IG Trading Workflow
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Bot Strategy  │───▶│    IG REST API   │───▶│  IG Platforms   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │              ┌────────▼────────┐               │
         │              │ Position Mgmt   │               │
         │              └─────────────────┘               │
         ▼                       │                       ▼
┌─────────────────┐    ┌──────────▼──────┐    ┌─────────────────┐
│ Market Data     │    │ Order Execution │    │ Account Info    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

---

## Cryptocurrency Exchanges

### Binance Workflow

#### 1. API Configuration
```python
binance_config = {
    "api_key": "your_api_key",
    "secret_key": "your_secret_key",
    "testnet": True,  # Use testnet for development
    "futures": True,  # Enable futures trading
    "margin": False   # Enable margin trading
}
```

#### 2. Binance Trading Flow
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   ML Signals    │───▶│  Binance CCXT    │───▶│ Binance Exchange│
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │              ┌────────▼────────┐               │
         │              │ Risk Management │               │
         │              └─────────────────┘               │
         ▼                       │                       ▼
┌─────────────────┐    ┌──────────▼──────┐    ┌─────────────────┐
│ Portfolio Mgmt  │    │ Order Book      │    │ WebSocket Feed  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

#### 3. Supported Trading Types
- **Spot Trading**: BTC/USDT, ETH/USDT, BNB/USDT, etc.
- **Futures Trading**: Perpetual contracts with up to 125x leverage
- **Margin Trading**: Cross and isolated margin
- **Options**: European-style options
- **Savings**: Flexible and locked staking

### Coinbase Pro Workflow

#### 1. Authentication
```python
coinbase_config = {
    "api_key": "your_api_key",
    "secret_key": "your_secret_key", 
    "passphrase": "your_passphrase",
    "sandbox": True  # Use sandbox for testing
}
```

#### 2. Professional Trading Features
- **Advanced Order Types**: Limit, Market, Stop
- **Portfolio Management**: Multi-portfolio support
- **Institutional Features**: Prime brokerage, custody
- **API Rate Limits**: 10 requests/second (private), 3 requests/second (public)

### Kraken Workflow

#### 1. Advanced Features
```python
kraken_config = {
    "api_key": "your_api_key",
    "secret_key": "your_secret_key",
    "otp": "two_factor_code",  # Optional 2FA
    "futures": True,           # Enable futures
    "staking": True            # Enable staking
}
```

#### 2. Kraken Pro Trading
- **Spot Trading**: 200+ cryptocurrencies
- **Futures Trading**: Multi-collateral margin
- **Staking**: Earn rewards on holdings
- **DeFi**: Liquid staking and DeFi integrations
- **NFTs**: NFT marketplace integration

---

## Complete Workflow Implementation

### 1. Unified Broker Configuration

```python
# backend/config/brokers.json
{
  "forex_brokers": {
    "XM": {
      "type": "mt5",
      "server_template": "XM-{type}",
      "supported_accounts": ["standard", "zero", "ultra_low"],
      "min_deposit": 5,
      "max_leverage": 888,
      "instruments": 1000,
      "spreads": "from_0.6_pips",
      "execution": "market",
      "api_docs": "https://www.xm.com/mt5-api"
    },
    "IC_Markets": {
      "type": "mt5",
      "server_template": "ICMarkets-{type}",
      "supported_accounts": ["raw_spread", "standard", "ctrader"],
      "min_deposit": 200,
      "max_leverage": 500,
      "instruments": 2000,
      "spreads": "from_0.0_pips",
      "execution": "ecn",
      "swap_free": true
    },
    "XTB": {
      "type": "xstation",
      "api_endpoint": "wss://ws.xtb.com",
      "supported_accounts": ["standard", "pro"],
      "min_deposit": 250,
      "max_leverage": 30,
      "instruments": 5400,
      "regulation": ["EU", "CySEC"],
      "negative_balance_protection": true
    }
  },
  "crypto_exchanges": {
    "Binance": {
      "type": "ccxt",
      "class": "binance",
      "api_endpoint": "https://api.binance.com",
      "supported_trading": ["spot", "futures", "margin", "options"],
      "max_leverage": 125,
      "maker_fee": 0.001,
      "taker_fee": 0.001,
      "withdrawal_fees": "variable",
      "staking": true,
      "savings": true
    },
    "Coinbase_Pro": {
      "type": "ccxt",
      "class": "coinbasepro", 
      "api_endpoint": "https://api.exchange.coinbase.com",
      "supported_trading": ["spot", "advanced"],
      "max_leverage": 1,
      "maker_fee": 0.005,
      "taker_fee": 0.005,
      "institutional": true,
      "custody": true
    }
  }
}
```

### 2. Dynamic Broker Loading

```python
# backend/services/broker_factory.py
class BrokerFactory:
    @staticmethod
    def create_broker(broker_name: str, config: dict):
        """Dynamically create broker connector"""
        
        broker_configs = load_broker_configs()
        
        if broker_name not in broker_configs:
            raise ValueError(f"Unsupported broker: {broker_name}")
        
        broker_info = broker_configs[broker_name]
        broker_type = broker_info['type']
        
        # Route to appropriate connector
        if broker_type == 'mt5':
            return MT5Connector(broker_info, config)
        elif broker_type == 'xstation':
            return XTBConnector(broker_info, config)
        elif broker_type == 'ccxt':
            return CCXTConnector(broker_info, config)
        elif broker_type == 'rest_api':
            return RESTAPIConnector(broker_info, config)
        else:
            raise ValueError(f"Unknown broker type: {broker_type}")
```

### 3. Risk Management Workflow

```python
# backend/services/risk_manager.py
class RiskManager:
    def __init__(self, config):
        self.max_daily_loss = config.get('max_daily_loss', 0.05)  # 5%
        self.max_position_size = config.get('max_position_size', 0.1)  # 10%
        self.max_correlation = config.get('max_correlation', 0.7)
        
    def validate_trade(self, broker_name: str, symbol: str, 
                      signal: dict, account_info: dict) -> dict:
        """Validate trade before execution"""
        
        # Check daily loss limit
        daily_pnl = self.calculate_daily_pnl(broker_name)
        if daily_pnl < -self.max_daily_loss * account_info['equity']:
            return {"allowed": False, "reason": "Daily loss limit exceeded"}
        
        # Check position size
        position_value = signal['price'] * signal.get('quantity', 0)
        if position_value > self.max_position_size * account_info['equity']:
            return {"allowed": False, "reason": "Position size too large"}
        
        # Check correlation
        correlation = self.calculate_portfolio_correlation(symbol)
        if correlation > self.max_correlation:
            return {"allowed": False, "reason": "High correlation with existing positions"}
        
        return {"allowed": True, "adjusted_quantity": signal.get('quantity')}
```

### 4. Complete Trading Workflow

```python
# backend/workflows/trading_workflow.py
class TradingWorkflow:
    def __init__(self, broker_service, ml_service, risk_manager):
        self.broker_service = broker_service
        self.ml_service = ml_service
        self.risk_manager = risk_manager
        
    async def execute_trading_cycle(self):
        """Complete trading workflow cycle"""
        
        # 1. Get market data from all connected brokers
        market_data = await self.gather_market_data()
        
        # 2. Generate ML signals
        ml_signals = self.ml_service.generate_signals(market_data)
        
        # 3. Process each signal
        for symbol, signal in ml_signals.items():
            # Find best broker for this symbol
            best_broker = self.find_best_broker(symbol, signal)
            
            if not best_broker:
                continue
            
            # Get account info
            account_info = self.broker_service.get_account_info(best_broker)
            
            # Risk management check
            risk_check = self.risk_manager.validate_trade(
                best_broker, symbol, signal, account_info
            )
            
            if not risk_check['allowed']:
                self.log_rejected_trade(symbol, signal, risk_check['reason'])
                continue
            
            # Execute trade
            try:
                result = await self.broker_service.execute_signals(
                    best_broker, {symbol: signal}
                )
                
                # Log successful execution
                self.log_successful_trade(best_broker, symbol, signal, result)
                
            except Exception as e:
                self.log_failed_trade(best_broker, symbol, signal, str(e))
        
        # 4. Update portfolio metrics
        await self.update_portfolio_metrics()
        
    def find_best_broker(self, symbol: str, signal: dict) -> str:
        """Find best broker for executing trade"""
        available_brokers = []
        
        for broker_name, connection in self.broker_service.connections.items():
            if not connection.is_active:
                continue
                
            # Check if broker supports symbol
            if self.broker_supports_symbol(broker_name, symbol):
                # Get trading costs
                costs = self.calculate_trading_costs(broker_name, symbol, signal)
                available_brokers.append((broker_name, costs))
        
        # Return broker with lowest costs
        if available_brokers:
            return min(available_brokers, key=lambda x: x[1])[0]
        
        return None
```

### 5. WebSocket Integration for Real-time Data

```python
# backend/services/websocket_manager.py
class WebSocketManager:
    def __init__(self):
        self.connections = {}
        
    async def start_broker_streams(self, broker_configs: dict):
        """Start WebSocket streams for all brokers"""
        
        for broker_name, config in broker_configs.items():
            if config.get('websocket_support'):
                await self.start_broker_stream(broker_name, config)
    
    async def start_broker_stream(self, broker_name: str, config: dict):
        """Start WebSocket stream for specific broker"""
        
        if broker_name == 'Binance':
            await self.start_binance_stream(config)
        elif broker_name == 'Kraken':
            await self.start_kraken_stream(config)
        elif broker_name == 'XTB':
            await self.start_xtb_stream(config)
        # Add more brokers as needed
    
    async def start_binance_stream(self, config: dict):
        """Start Binance WebSocket stream"""
        import websockets
        
        uri = "wss://stream.binance.com:9443/ws/btcusdt@ticker"
        
        async with websockets.connect(uri) as websocket:
            while True:
                try:
                    message = await websocket.recv()
                    data = json.loads(message)
                    
                    # Process market data
                    await self.process_market_data('Binance', data)
                    
                except Exception as e:
                    logger.error(f"Binance WebSocket error: {e}")
                    break
```

---

## Frontend Integration Workflow

### 1. Broker Configuration Panel

```javascript
// frontend/src/components/BrokerConfig.jsx
import React, { useState, useEffect } from 'react';
import { Card, Form, Button, Alert } from 'react-bootstrap';

const BrokerConfig = () => {
    const [brokers, setBrokers] = useState([]);
    const [selectedBroker, setSelectedBroker] = useState('');
    const [credentials, setCredentials] = useState({});
    const [connectionStatus, setConnectionStatus] = useState({});
    
    useEffect(() => {
        fetchSupportedBrokers();
        fetchConnectionStatus();
    }, []);
    
    const fetchSupportedBrokers = async () => {
        const response = await fetch('/api/brokers');
        const data = await response.json();
        setBrokers(data.brokers);
    };
    
    const connectBroker = async (brokerName, creds) => {
        const response = await fetch('/api/brokers/connect', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                broker_name: brokerName,
                credentials: creds
            })
        });
        
        const result = await response.json();
        if (result.success) {
            setConnectionStatus(prev => ({...prev, [brokerName]: 'connected'}));
        }
    };
    
    return (
        <div className="broker-config">
            <h3>Broker Configuration</h3>
            
            {brokers.map(broker => (
                <Card key={broker.name} className="mb-3">
                    <Card.Header>
                        <h5>{broker.name}</h5>
                        <span className={`status ${connectionStatus[broker.name]}`}>
                            {connectionStatus[broker.name] || 'disconnected'}
                        </span>
                    </Card.Header>
                    
                    <Card.Body>
                        <BrokerCredentialForm 
                            broker={broker}
                            onConnect={connectBroker}
                        />
                    </Card.Body>
                </Card>
            ))}
        </div>
    );
};
```

### 2. Real-time Trading Dashboard

```javascript
// frontend/src/components/TradingDashboard.jsx
import React, { useState, useEffect } from 'react';
import { io } from 'socket.io-client';
import { LineChart, Line, XAxis, YAxis, Tooltip } from 'recharts';

const TradingDashboard = () => {
    const [socket, setSocket] = useState(null);
    const [signals, setSignals] = useState({});
    const [portfolioData, setPortfolioData] = useState([]);
    const [tradingActive, setTradingActive] = useState(false);
    
    useEffect(() => {
        const newSocket = io('http://localhost:5000');
        setSocket(newSocket);
        
        // Listen for trading signals
        newSocket.on('signals_update', (data) => {
            setSignals(data.signals);
        });
        
        // Listen for portfolio updates
        newSocket.on('portfolio_update', (data) => {
            setPortfolioData(prev => [...prev, data].slice(-100));
        });
        
        return () => newSocket.close();
    }, []);
    
    const startTrading = () => {
        if (socket) {
            socket.emit('start_trading', {
                strategy_config: {
                    name: 'ML Strategy',
                    symbols: ['EURUSD', 'BTCUSD'],
                    use_ml: true,
                    brokers: ['XM', 'Binance']
                }
            });
        }
    };
    
    return (
        <div className="trading-dashboard">
            <div className="control-panel">
                <Button 
                    variant={tradingActive ? 'danger' : 'success'}
                    onClick={tradingActive ? stopTrading : startTrading}
                >
                    {tradingActive ? 'Stop Trading' : 'Start Trading'}
                </Button>
            </div>
            
            <div className="signals-panel">
                <h4>Current Signals</h4>
                {Object.entries(signals).map(([symbol, signal]) => (
                    <div key={symbol} className="signal-card">
                        <h6>{symbol}</h6>
                        <span className={`signal-type ${signal.type}`}>
                            {signal.type.toUpperCase()}
                        </span>
                        <span className="confidence">
                            Confidence: {(signal.confidence * 100).toFixed(1)}%
                        </span>
                    </div>
                ))}
            </div>
            
            <div className="portfolio-chart">
                <h4>Portfolio Performance</h4>
                <LineChart width={800} height={300} data={portfolioData}>
                    <XAxis dataKey="timestamp" />
                    <YAxis />
                    <Tooltip />
                    <Line type="monotone" dataKey="value" stroke="#8884d8" />
                </LineChart>
            </div>
        </div>
    );
};
```

---

## Deployment & Monitoring

### 1. Docker Orchestration

```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  trading-bot:
    build: .
    environment:
      - ENVIRONMENT=production
      - LOG_LEVEL=INFO
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
    depends_on:
      - redis
      - postgres
      
  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
      
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: trading_bot
    volumes:
      - postgres_data:/var/lib/postgresql/data
      
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
```

### 2. Monitoring & Alerting

```python
# backend/monitoring/alerts.py
class AlertManager:
    def __init__(self):
        self.alert_channels = ['email', 'slack', 'telegram']
    
    def check_trading_health(self):
        """Monitor trading system health"""
        
        # Check broker connections
        for broker_name, connection in broker_service.connections.items():
            if not connection.is_active:
                self.send_alert(
                    f"Broker {broker_name} disconnected",
                    severity='high'
                )
        
        # Check daily P&L
        daily_pnl = self.calculate_daily_pnl()
        if daily_pnl < -0.05:  # -5%
            self.send_alert(
                f"Daily loss exceeds 5%: {daily_pnl:.2%}",
                severity='critical'
            )
        
        # Check ML model performance
        model_accuracy = self.check_ml_accuracy()
        if model_accuracy < 0.6:  # 60%
            self.send_alert(
                f"ML model accuracy dropped: {model_accuracy:.2%}",
                severity='medium'
            )
```

This comprehensive workflow documentation provides a complete integration strategy for all major brokers and exchanges, with practical implementation examples and monitoring solutions.