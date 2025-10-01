#!/usr/bin/env python3
"""
Broker Service - Multi-Broker Integration
Supports Forex, Crypto, and CFD brokers with unified API
"""

import logging
import asyncio
import json
import time
import threading
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Union
from dataclasses import dataclass, asdict
from decimal import Decimal

# Trading APIs
import MetaTrader5 as mt5
import ccxt
from ib_insync import IB, Stock, Forex, Contract

# Internal imports
from utils.config import Config
from utils.helpers import validate_api_credentials, format_currency_pair
from models.trading_models import BrokerConnection, TradeExecution

logger = logging.getLogger(__name__)

@dataclass
class BrokerInfo:
    name: str
    type: str  # 'forex', 'crypto', 'cfd', 'stocks'
    connector_class: str
    api_class: Any
    supported_assets: List[str]
    features: List[str]
    min_deposit: float = 0
    max_leverage: int = 1

class BrokerService:
    """Multi-broker integration service supporting various trading platforms"""
    
    def __init__(self, config: Config):
        self.config = config
        self.connections: Dict[str, BrokerConnection] = {}
        self.active_sessions: Dict[str, Any] = {}
        self.trade_history: List[TradeExecution] = []
        
        # Define supported brokers with their configurations
        self.supported_brokers = {
            # Forex/MT4/MT5 Brokers
            'XM': BrokerInfo(
                name='XM',
                type='forex',
                connector_class='MT5Connector',
                api_class=mt5,
                supported_assets=['EURUSD', 'GBPUSD', 'USDJPY', 'AUDUSD', 'USDCAD', 'USDCHF', 'NZDUSD', 'EURJPY', 'GBPJPY', 'AUDJPY'],
                features=['forex', 'commodities', 'indices', 'crypto_cfd'],
                min_deposit=5,
                max_leverage=888
            ),
            'IC Markets': BrokerInfo(
                name='IC Markets',
                type='forex',
                connector_class='MT5Connector',
                api_class=mt5,
                supported_assets=['EURUSD', 'GBPUSD', 'USDJPY', 'AUDUSD', 'USDCAD'],
                features=['forex', 'commodities', 'indices', 'stocks'],
                min_deposit=200,
                max_leverage=500
            ),
            'RoboForex': BrokerInfo(
                name='RoboForex',
                type='forex',
                connector_class='MT5Connector',
                api_class=mt5,
                supported_assets=['EURUSD', 'GBPUSD', 'USDJPY', 'AUDUSD'],
                features=['forex', 'stocks', 'commodities', 'crypto_cfd'],
                min_deposit=10,
                max_leverage=2000
            ),
            'InstaForex': BrokerInfo(
                name='InstaForex',
                type='forex',
                connector_class='MT5Connector',
                api_class=mt5,
                supported_assets=['EURUSD', 'GBPUSD', 'USDJPY'],
                features=['forex', 'crypto_cfd'],
                min_deposit=1,
                max_leverage=1000
            ),
            'FBS': BrokerInfo(
                name='FBS',
                type='forex',
                connector_class='MT5Connector',
                api_class=mt5,
                supported_assets=['EURUSD', 'GBPUSD', 'USDJPY', 'AUDUSD'],
                features=['forex', 'commodities', 'indices'],
                min_deposit=5,
                max_leverage=3000
            ),
            'XTB': BrokerInfo(
                name='XTB',
                type='forex',
                connector_class='XTBConnector',
                api_class=None,  # Custom API
                supported_assets=['EURUSD', 'GBPUSD', 'USDJPY', 'SPX500', 'GER40'],
                features=['forex', 'cfd', 'stocks', 'commodities'],
                min_deposit=250,
                max_leverage=30
            ),
            'Admiral Markets': BrokerInfo(
                name='Admiral Markets',
                type='forex',
                connector_class='MT5Connector',
                api_class=mt5,
                supported_assets=['EURUSD', 'GBPUSD', 'USDJPY'],
                features=['forex', 'cfd', 'stocks'],
                min_deposit=100,
                max_leverage=30
            ),
            'IG Group': BrokerInfo(
                name='IG Group',
                type='cfd',
                connector_class='IGConnector',
                api_class=None,  # REST API
                supported_assets=['EURUSD', 'GBPUSD', 'SPX500', 'FTSE100'],
                features=['forex', 'cfd', 'options', 'barriers'],
                min_deposit=250,
                max_leverage=30
            ),
            'Plus500': BrokerInfo(
                name='Plus500',
                type='cfd',
                connector_class='Plus500Connector',
                api_class=None,  # WebTrader API
                supported_assets=['EURUSD', 'GBPUSD', 'SPX500', 'TSLA', 'AAPL'],
                features=['cfd', 'crypto_cfd', 'forex'],
                min_deposit=100,
                max_leverage=30
            ),
            'SabioTrade': BrokerInfo(
                name='SabioTrade',
                type='forex',
                connector_class='SabioConnector',
                api_class=None,  # Custom API
                supported_assets=['EURUSD', 'GBPUSD', 'USDJPY'],
                features=['forex', 'social_trading'],
                min_deposit=250,
                max_leverage=400
            ),
            
            # Cryptocurrency Exchanges
            'Binance': BrokerInfo(
                name='Binance',
                type='crypto',
                connector_class='CCXTConnector',
                api_class=ccxt.binance,
                supported_assets=['BTC/USDT', 'ETH/USDT', 'BNB/USDT', 'ADA/USDT', 'DOT/USDT'],
                features=['spot', 'futures', 'margin', 'savings'],
                min_deposit=10,
                max_leverage=125
            ),
            'Coinbase Pro': BrokerInfo(
                name='Coinbase Pro',
                type='crypto',
                connector_class='CCXTConnector',
                api_class=ccxt.coinbasepro,
                supported_assets=['BTC/USD', 'ETH/USD', 'LTC/USD', 'BCH/USD'],
                features=['spot', 'advanced_trading'],
                min_deposit=25,
                max_leverage=1
            ),
            'Kraken': BrokerInfo(
                name='Kraken',
                type='crypto',
                connector_class='CCXTConnector',
                api_class=ccxt.kraken,
                supported_assets=['BTC/USD', 'ETH/USD', 'XRP/USD', 'ADA/USD'],
                features=['spot', 'futures', 'margin', 'staking'],
                min_deposit=1,
                max_leverage=5
            ),
            'Bitstamp': BrokerInfo(
                name='Bitstamp',
                type='crypto',
                connector_class='CCXTConnector',
                api_class=ccxt.bitstamp,
                supported_assets=['BTC/USD', 'ETH/USD', 'XRP/USD'],
                features=['spot'],
                min_deposit=25,
                max_leverage=1
            ),
            'Bitfinex': BrokerInfo(
                name='Bitfinex',
                type='crypto',
                connector_class='CCXTConnector',
                api_class=ccxt.bitfinex,
                supported_assets=['BTC/USD', 'ETH/USD', 'USDT/USD'],
                features=['spot', 'margin', 'derivatives', 'lending'],
                min_deposit=10,
                max_leverage=10
            ),
            'Gemini': BrokerInfo(
                name='Gemini',
                type='crypto',
                connector_class='CCXTConnector',
                api_class=ccxt.gemini,
                supported_assets=['BTC/USD', 'ETH/USD', 'LTC/USD'],
                features=['spot', 'custody', 'earn'],
                min_deposit=25,
                max_leverage=1
            ),
            'Huobi': BrokerInfo(
                name='Huobi',
                type='crypto',
                connector_class='CCXTConnector',
                api_class=ccxt.huobi,
                supported_assets=['BTC/USDT', 'ETH/USDT', 'HT/USDT'],
                features=['spot', 'futures', 'margin'],
                min_deposit=5,
                max_leverage=125
            ),
            'OKX': BrokerInfo(
                name='OKX',
                type='crypto',
                connector_class='CCXTConnector',
                api_class=ccxt.okx,
                supported_assets=['BTC/USDT', 'ETH/USDT', 'OKB/USDT'],
                features=['spot', 'futures', 'perpetual', 'options'],
                min_deposit=10,
                max_leverage=125
            ),
            'Bybit': BrokerInfo(
                name='Bybit',
                type='crypto',
                connector_class='CCXTConnector',
                api_class=ccxt.bybit,
                supported_assets=['BTC/USDT', 'ETH/USDT', 'BIT/USDT'],
                features=['spot', 'derivatives', 'copy_trading'],
                min_deposit=10,
                max_leverage=100
            ),
            'KuCoin': BrokerInfo(
                name='KuCoin',
                type='crypto',
                connector_class='CCXTConnector',
                api_class=ccxt.kucoin,
                supported_assets=['BTC/USDT', 'ETH/USDT', 'KCS/USDT'],
                features=['spot', 'futures', 'margin', 'pool'],
                min_deposit=10,
                max_leverage=100
            ),
            'Bittrex': BrokerInfo(
                name='Bittrex',
                type='crypto',
                connector_class='CCXTConnector',
                api_class=ccxt.bittrex,
                supported_assets=['BTC/USD', 'ETH/USD', 'XRP/USD'],
                features=['spot'],
                min_deposit=25,
                max_leverage=1
            )
        }
        
        logger.info(f"BrokerService initialized with {len(self.supported_brokers)} supported brokers")

    def initialize(self):
        """Initialize broker service"""
        try:
            # Test connections to available broker APIs
            self._test_api_availability()
            logger.info("BrokerService initialization completed")
            return True
        except Exception as e:
            logger.error(f"BrokerService initialization failed: {e}")
            return False

    def _test_api_availability(self):
        """Test availability of broker APIs"""
        available_apis = {
            'mt5': self._test_mt5_availability(),
            'ccxt': self._test_ccxt_availability(),
            'ib': self._test_ib_availability()
        }
        
        logger.info(f"API availability: {available_apis}")
        return available_apis

    def _test_mt5_availability(self) -> bool:
        """Test MetaTrader 5 availability"""
        try:
            import MetaTrader5 as mt5
            return True
        except ImportError:
            logger.warning("MetaTrader5 not available")
            return False

    def _test_ccxt_availability(self) -> bool:
        """Test CCXT library availability"""
        try:
            import ccxt
            return True
        except ImportError:
            logger.warning("CCXT library not available")
            return False

    def _test_ib_availability(self) -> bool:
        """Test Interactive Brokers availability"""
        try:
            from ib_insync import IB
            return True
        except ImportError:
            logger.warning("IB-Insync not available")
            return False

    def get_supported_brokers(self) -> List[Dict[str, Any]]:
        """Get list of all supported brokers"""
        return [
            {
                'name': broker.name,
                'type': broker.type,
                'supported_assets': broker.supported_assets,
                'features': broker.features,
                'min_deposit': broker.min_deposit,
                'max_leverage': broker.max_leverage
            }
            for broker in self.supported_brokers.values()
        ]

    def connect_broker(self, broker_name: str, credentials: Dict[str, Any]) -> bool:
        """Connect to a specific broker"""
        try:
            if broker_name not in self.supported_brokers:
                logger.error(f"Broker {broker_name} not supported")
                return False

            broker_info = self.supported_brokers[broker_name]
            
            # Validate credentials
            if not self._validate_credentials(broker_name, credentials):
                logger.error(f"Invalid credentials for {broker_name}")
                return False

            # Create connection based on broker type
            connector = self._create_connector(broker_info, credentials)
            
            if connector and connector.connect():
                connection = BrokerConnection(
                    name=broker_name,
                    broker_type=broker_info.type,
                    connector=connector,
                    credentials=credentials,
                    connected_at=datetime.now(),
                    is_active=True
                )
                
                self.connections[broker_name] = connection
                logger.info(f"Successfully connected to {broker_name}")
                return True
            else:
                logger.error(f"Failed to create connector for {broker_name}")
                return False

        except Exception as e:
            logger.error(f"Error connecting to {broker_name}: {e}")
            return False

    def _validate_credentials(self, broker_name: str, credentials: Dict[str, Any]) -> bool:
        """Validate broker credentials"""
        broker_info = self.supported_brokers[broker_name]
        
        if broker_info.type == 'forex' and broker_info.connector_class == 'MT5Connector':
            required_fields = ['login', 'password', 'server']
        elif broker_info.type == 'crypto':
            required_fields = ['api_key', 'secret']
        else:
            required_fields = ['api_key']  # Default
        
        return all(field in credentials for field in required_fields)

    def _create_connector(self, broker_info: BrokerInfo, credentials: Dict[str, Any]):
        """Create broker connector based on type"""
        try:
            if broker_info.connector_class == 'MT5Connector':
                return MT5Connector(broker_info, credentials)
            elif broker_info.connector_class == 'CCXTConnector':
                return CCXTConnector(broker_info, credentials)
            elif broker_info.connector_class == 'XTBConnector':
                return XTBConnector(broker_info, credentials)
            elif broker_info.connector_class == 'IGConnector':
                return IGConnector(broker_info, credentials)
            elif broker_info.connector_class == 'Plus500Connector':
                return Plus500Connector(broker_info, credentials)
            elif broker_info.connector_class == 'SabioConnector':
                return SabioConnector(broker_info, credentials)
            else:
                logger.error(f"Unknown connector class: {broker_info.connector_class}")
                return None
        except Exception as e:
            logger.error(f"Error creating connector: {e}")
            return None

    def disconnect_broker(self, broker_name: str) -> bool:
        """Disconnect from a broker"""
        try:
            if broker_name in self.connections:
                connection = self.connections[broker_name]
                connection.connector.disconnect()
                connection.is_active = False
                connection.disconnected_at = datetime.now()
                
                del self.connections[broker_name]
                logger.info(f"Disconnected from {broker_name}")
                return True
            else:
                logger.warning(f"No active connection to {broker_name}")
                return False
        except Exception as e:
            logger.error(f"Error disconnecting from {broker_name}: {e}")
            return False

    def execute_signals(self, broker_name: str, signals: Dict[str, Any]) -> Dict[str, Any]:
        """Execute trading signals on a specific broker"""
        results = {}
        
        try:
            if broker_name not in self.connections:
                return {'error': f'No connection to {broker_name}'}
            
            connection = self.connections[broker_name]
            if not connection.is_active:
                return {'error': f'Connection to {broker_name} is not active'}
            
            for symbol, signal in signals.items():
                try:
                    result = connection.connector.execute_trade(symbol, signal)
                    results[symbol] = result
                    
                    # Record trade execution
                    if result.get('success', False):
                        trade_execution = TradeExecution(
                            broker_name=broker_name,
                            symbol=symbol,
                            signal_type=signal.get('type'),
                            quantity=result.get('quantity', 0),
                            price=result.get('price', 0),
                            order_id=result.get('order_id'),
                            executed_at=datetime.now(),
                            metadata=json.dumps(result)
                        )
                        self.trade_history.append(trade_execution)
                        
                except Exception as e:
                    logger.error(f"Error executing signal for {symbol} on {broker_name}: {e}")
                    results[symbol] = {'error': str(e)}
            
            return results
            
        except Exception as e:
            logger.error(f"Error executing signals on {broker_name}: {e}")
            return {'error': str(e)}

    def get_account_info(self, broker_name: str) -> Dict[str, Any]:
        """Get account information from broker"""
        try:
            if broker_name not in self.connections:
                return {'error': f'No connection to {broker_name}'}
            
            connection = self.connections[broker_name]
            return connection.connector.get_account_info()
        
        except Exception as e:
            logger.error(f"Error getting account info from {broker_name}: {e}")
            return {'error': str(e)}

    def get_positions(self, broker_name: str) -> List[Dict[str, Any]]:
        """Get open positions from broker"""
        try:
            if broker_name not in self.connections:
                return []
            
            connection = self.connections[broker_name]
            return connection.connector.get_positions()
        
        except Exception as e:
            logger.error(f"Error getting positions from {broker_name}: {e}")
            return []

    def get_market_data(self, broker_name: str, symbols: List[str]) -> Dict[str, Any]:
        """Get market data from broker"""
        try:
            if broker_name not in self.connections:
                return {}
            
            connection = self.connections[broker_name]
            return connection.connector.get_market_data(symbols)
        
        except Exception as e:
            logger.error(f"Error getting market data from {broker_name}: {e}")
            return {}


class BaseConnector:
    """Base class for broker connectors"""
    
    def __init__(self, broker_info: BrokerInfo, credentials: Dict[str, Any]):
        self.broker_info = broker_info
        self.credentials = credentials
        self.client = None
        self.is_connected = False

    def connect(self) -> bool:
        """Connect to broker - to be implemented by subclasses"""
        raise NotImplementedError

    def disconnect(self) -> bool:
        """Disconnect from broker - to be implemented by subclasses"""
        raise NotImplementedError

    def execute_trade(self, symbol: str, signal: Dict[str, Any]) -> Dict[str, Any]:
        """Execute a trade - to be implemented by subclasses"""
        raise NotImplementedError

    def get_account_info(self) -> Dict[str, Any]:
        """Get account information - to be implemented by subclasses"""
        raise NotImplementedError

    def get_positions(self) -> List[Dict[str, Any]]:
        """Get open positions - to be implemented by subclasses"""
        raise NotImplementedError

    def get_market_data(self, symbols: List[str]) -> Dict[str, Any]:
        """Get market data - to be implemented by subclasses"""
        raise NotImplementedError


class MT5Connector(BaseConnector):
    """MetaTrader 5 connector for forex brokers"""
    
    def connect(self) -> bool:
        try:
            if not mt5.initialize():
                logger.error("Failed to initialize MT5")
                return False
            
            login = self.credentials['login']
            password = self.credentials['password']
            server = self.credentials['server']
            
            if not mt5.login(login, password=password, server=server):
                logger.error(f"Failed to login to MT5: {mt5.last_error()}")
                return False
            
            self.is_connected = True
            logger.info(f"Connected to MT5 server: {server}")
            return True
            
        except Exception as e:
            logger.error(f"MT5 connection error: {e}")
            return False

    def disconnect(self) -> bool:
        try:
            mt5.shutdown()
            self.is_connected = False
            return True
        except Exception as e:
            logger.error(f"MT5 disconnect error: {e}")
            return False

    def execute_trade(self, symbol: str, signal: Dict[str, Any]) -> Dict[str, Any]:
        try:
            signal_type = signal.get('type', '').lower()
            strength = signal.get('strength', 0.5)
            
            # Calculate volume based on signal strength
            base_volume = self.credentials.get('base_volume', 0.1)
            volume = base_volume * strength
            
            # Get current price
            tick = mt5.symbol_info_tick(symbol)
            if not tick:
                return {'success': False, 'error': f'No price data for {symbol}'}
            
            price = tick.ask if signal_type == 'buy' else tick.bid
            
            # Prepare order request
            request = {
                "action": mt5.TRADE_ACTION_DEAL,
                "symbol": symbol,
                "volume": volume,
                "type": mt5.ORDER_TYPE_BUY if signal_type == 'buy' else mt5.ORDER_TYPE_SELL,
                "price": price,
                "deviation": 20,
                "magic": self.credentials.get('magic', 234000),
                "comment": f"Bot signal - {signal.get('source', 'unknown')}",
                "type_time": mt5.ORDER_TIME_GTC,
                "type_filling": mt5.ORDER_FILLING_IOC,
            }
            
            # Execute order
            result = mt5.order_send(request)
            
            if result and result.retcode == mt5.TRADE_RETCODE_DONE:
                return {
                    'success': True,
                    'order_id': result.order,
                    'quantity': volume,
                    'price': result.price,
                    'symbol': symbol,
                    'type': signal_type
                }
            else:
                error_msg = result.comment if result else "Unknown error"
                return {
                    'success': False,
                    'error': f'Order failed: {error_msg}',
                    'retcode': result.retcode if result else None
                }
                
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def get_account_info(self) -> Dict[str, Any]:
        try:
            account_info = mt5.account_info()
            if account_info:
                return {
                    'balance': float(account_info.balance),
                    'equity': float(account_info.equity),
                    'margin': float(account_info.margin),
                    'free_margin': float(account_info.margin_free),
                    'margin_level': float(account_info.margin_level),
                    'currency': account_info.currency,
                    'leverage': account_info.leverage,
                    'profit': float(account_info.profit)
                }
            return {}
        except Exception as e:
            logger.error(f"Error getting MT5 account info: {e}")
            return {}

    def get_positions(self) -> List[Dict[str, Any]]:
        try:
            positions = mt5.positions_get()
            if positions:
                return [
                    {
                        'ticket': pos.ticket,
                        'symbol': pos.symbol,
                        'type': 'buy' if pos.type == 0 else 'sell',
                        'volume': float(pos.volume),
                        'price_open': float(pos.price_open),
                        'price_current': float(pos.price_current),
                        'profit': float(pos.profit),
                        'swap': float(pos.swap),
                        'comment': pos.comment,
                        'time': datetime.fromtimestamp(pos.time)
                    }
                    for pos in positions
                ]
            return []
        except Exception as e:
            logger.error(f"Error getting MT5 positions: {e}")
            return []

    def get_market_data(self, symbols: List[str]) -> Dict[str, Any]:
        try:
            market_data = {}
            for symbol in symbols:
                tick = mt5.symbol_info_tick(symbol)
                if tick:
                    market_data[symbol] = {
                        'bid': float(tick.bid),
                        'ask': float(tick.ask),
                        'last': float(tick.last),
                        'volume': int(tick.volume),
                        'time': datetime.fromtimestamp(tick.time),
                        'spread': float(tick.ask - tick.bid)
                    }
            return market_data
        except Exception as e:
            logger.error(f"Error getting MT5 market data: {e}")
            return {}


class CCXTConnector(BaseConnector):
    """CCXT connector for cryptocurrency exchanges"""
    
    def connect(self) -> bool:
        try:
            exchange_class = self.broker_info.api_class
            
            config = {
                'apiKey': self.credentials['api_key'],
                'secret': self.credentials['secret'],
                'enableRateLimit': True,
                'sandbox': self.credentials.get('sandbox', False)
            }
            
            # Add passphrase for exchanges that require it
            if 'passphrase' in self.credentials:
                config['password'] = self.credentials['passphrase']
            
            self.client = exchange_class(config)
            
            # Test connection
            self.client.load_markets()
            
            self.is_connected = True
            logger.info(f"Connected to {self.broker_info.name}")
            return True
            
        except Exception as e:
            logger.error(f"CCXT connection error for {self.broker_info.name}: {e}")
            return False

    def disconnect(self) -> bool:
        try:
            if self.client:
                self.client.close()
            self.is_connected = False
            return True
        except Exception as e:
            logger.error(f"CCXT disconnect error: {e}")
            return False

    def execute_trade(self, symbol: str, signal: Dict[str, Any]) -> Dict[str, Any]:
        try:
            signal_type = signal.get('type', '').lower()
            strength = signal.get('strength', 0.5)
            
            # Get base amount from credentials
            base_amount_usd = self.credentials.get('base_amount', 100)  # USD
            amount_usd = base_amount_usd * strength
            
            if signal_type == 'buy':
                # Buy cryptocurrency
                ticker = self.client.fetch_ticker(symbol)
                amount = amount_usd / ticker['last']
                
                order = self.client.create_market_buy_order(symbol, amount)
                
            elif signal_type == 'sell':
                # Sell cryptocurrency
                balance = self.client.fetch_balance()
                base_currency = symbol.split('/')[0]
                available = balance.get(base_currency, {}).get('free', 0)
                
                if available > 0:
                    sell_amount = min(available, available * strength)
                    order = self.client.create_market_sell_order(symbol, sell_amount)
                else:
                    return {'success': False, 'error': 'Insufficient balance'}
            else:
                return {'success': False, 'error': f'Unknown signal type: {signal_type}'}
            
            return {
                'success': True,
                'order_id': order['id'],
                'quantity': order['amount'],
                'price': order.get('price', 0),
                'symbol': symbol,
                'type': signal_type,
                'order_type': order['type']
            }
            
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def get_account_info(self) -> Dict[str, Any]:
        try:
            balance = self.client.fetch_balance()
            return {
                'balance': balance.get('total', {}),
                'free': balance.get('free', {}),
                'used': balance.get('used', {}),
                'currencies': list(balance.get('total', {}).keys())
            }
        except Exception as e:
            logger.error(f"Error getting CCXT account info: {e}")
            return {}

    def get_positions(self) -> List[Dict[str, Any]]:
        try:
            # For spot trading, return balances with non-zero amounts
            balance = self.client.fetch_balance()
            positions = []
            
            for currency, amounts in balance.get('total', {}).items():
                if float(amounts) > 0:
                    positions.append({
                        'symbol': currency,
                        'amount': float(amounts),
                        'free': float(balance.get('free', {}).get(currency, 0)),
                        'used': float(balance.get('used', {}).get(currency, 0))
                    })
            
            return positions
        except Exception as e:
            logger.error(f"Error getting CCXT positions: {e}")
            return []

    def get_market_data(self, symbols: List[str]) -> Dict[str, Any]:
        try:
            market_data = {}
            
            for symbol in symbols:
                try:
                    ticker = self.client.fetch_ticker(symbol)
                    market_data[symbol] = {
                        'bid': ticker.get('bid', 0),
                        'ask': ticker.get('ask', 0),
                        'last': ticker.get('last', 0),
                        'volume': ticker.get('quoteVolume', 0),
                        'high': ticker.get('high', 0),
                        'low': ticker.get('low', 0),
                        'change': ticker.get('change', 0),
                        'percentage': ticker.get('percentage', 0),
                        'timestamp': datetime.fromtimestamp(ticker.get('timestamp', 0) / 1000) if ticker.get('timestamp') else datetime.now()
                    }
                except Exception as e:
                    logger.warning(f"Failed to get market data for {symbol}: {e}")
            
            return market_data
        except Exception as e:
            logger.error(f"Error getting CCXT market data: {e}")
            return {}


# Placeholder connectors for brokers with custom APIs
class XTBConnector(BaseConnector):
    """XTB connector - placeholder for custom implementation"""
    
    def connect(self) -> bool:
        logger.info("XTB connector - implementation pending")
        return False

    def disconnect(self) -> bool:
        return True

    def execute_trade(self, symbol: str, signal: Dict[str, Any]) -> Dict[str, Any]:
        return {'success': False, 'error': 'XTB connector not implemented'}

    def get_account_info(self) -> Dict[str, Any]:
        return {}

    def get_positions(self) -> List[Dict[str, Any]]:
        return []

    def get_market_data(self, symbols: List[str]) -> Dict[str, Any]:
        return {}


class IGConnector(BaseConnector):
    """IG Group connector - placeholder for custom implementation"""
    
    def connect(self) -> bool:
        logger.info("IG Group connector - implementation pending")
        return False

    def disconnect(self) -> bool:
        return True

    def execute_trade(self, symbol: str, signal: Dict[str, Any]) -> Dict[str, Any]:
        return {'success': False, 'error': 'IG connector not implemented'}

    def get_account_info(self) -> Dict[str, Any]:
        return {}

    def get_positions(self) -> List[Dict[str, Any]]:
        return []

    def get_market_data(self, symbols: List[str]) -> Dict[str, Any]:
        return {}


class Plus500Connector(BaseConnector):
    """Plus500 connector - placeholder for custom implementation"""
    
    def connect(self) -> bool:
        logger.info("Plus500 connector - implementation pending")
        return False

    def disconnect(self) -> bool:
        return True

    def execute_trade(self, symbol: str, signal: Dict[str, Any]) -> Dict[str, Any]:
        return {'success': False, 'error': 'Plus500 connector not implemented'}

    def get_account_info(self) -> Dict[str, Any]:
        return {}

    def get_positions(self) -> List[Dict[str, Any]]:
        return []

    def get_market_data(self, symbols: List[str]) -> Dict[str, Any]:
        return {}


class SabioConnector(BaseConnector):
    """SabioTrade connector - placeholder for custom implementation"""
    
    def connect(self) -> bool:
        logger.info("SabioTrade connector - implementation pending")
        return False

    def disconnect(self) -> bool:
        return True

    def execute_trade(self, symbol: str, signal: Dict[str, Any]) -> Dict[str, Any]:
        return {'success': False, 'error': 'SabioTrade connector not implemented'}

    def get_account_info(self) -> Dict[str, Any]:
        return {}

    def get_positions(self) -> List[Dict[str, Any]]:
        return []

    def get_market_data(self, symbols: List[str]) -> Dict[str, Any]:
        return {}