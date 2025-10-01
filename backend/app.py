#!/usr/bin/env python3
"""
QuantConnect Trading Bot - Main Flask Application
Advanced trading bot with QuantConnect Lean integration, multi-broker support,
AI/ML models, and real-time WebSocket communication.
"""

import os
import json
import logging
import threading
import traceback
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional

from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from flask_socketio import SocketIO, emit, join_room, leave_room
from flask_jwt_extended import JWTManager

import redis
import numpy as np
import pandas as pd

# Import local modules
from services.lean_service import LeanService
from services.broker_service import BrokerService
from services.ml_service import MLService
from services.market_service import MarketDataService
from services.risk_service import RiskManagementService
from api.routes import api_bp
from api.auth import auth_bp
from models.database import db, init_db
from models.trading_models import TradingSignal, BrokerConfig, MLModel, TradingSession
from utils.config import Config
from utils.logger import setup_logging
from utils.helpers import validate_json, sanitize_input

# Initialize Flask app
app = Flask(__name__)
app.config.from_object(Config)

# Setup logging
setup_logging(app.config.get('LOG_LEVEL', 'INFO'))
logger = logging.getLogger(__name__)

# Initialize extensions
CORS(app, origins=app.config.get('CORS_ORIGINS', ['http://localhost:3000']))
db.init_app(app)
migrate = Migrate(app, db)
jwt = JWTManager(app)
socketio = SocketIO(
    app, 
    cors_allowed_origins=app.config.get('SOCKETIO_CORS_ORIGINS', '*'),
    async_mode='threading',
    ping_timeout=60,
    ping_interval=25
)

# Initialize Redis
try:
    redis_client = redis.from_url(
        app.config.get('REDIS_URL', 'redis://redis:6379/0'),
        decode_responses=True
    )
    redis_client.ping()
    logger.info("Redis connected successfully")
except Exception as e:
    logger.error(f"Redis connection failed: {e}")
    redis_client = None

# Initialize services
lean_service = LeanService(app.config)
broker_service = BrokerService(app.config)
ml_service = MLService(app.config)
market_service = MarketDataService(app.config)
risk_service = RiskManagementService(app.config)

# Global application state
class AppState:
    def __init__(self):
        self.trading_active = False
        self.connected_clients = set()
        self.current_signals = {}
        self.market_data = {}
        self.trading_sessions = {}
        self.performance_metrics = {}
        self.system_status = {
            'lean_engine': False,
            'brokers': {},
            'ml_models': 0,
            'last_update': None
        }

app_state = AppState()

# Register blueprints
app.register_blueprint(api_bp, url_prefix='/api')
app.register_blueprint(auth_bp, url_prefix='/auth')

@app.before_first_request
def initialize_application():
    """Initialize application on first request"""
    try:
        # Create database tables
        with app.app_context():
            init_db()
            logger.info("Database initialized")
        
        # Initialize services
        lean_service.initialize()
        broker_service.initialize()
        ml_service.initialize()
        market_service.initialize()
        
        # Load existing configurations
        load_broker_configs()
        load_ml_models()
        
        logger.info("Application initialized successfully")
        
    except Exception as e:
        logger.error(f"Application initialization failed: {e}")
        logger.error(traceback.format_exc())

def load_broker_configs():
    """Load existing broker configurations from database"""
    try:
        configs = BrokerConfig.query.filter_by(active=True).all()
        for config in configs:
            broker_data = json.loads(config.config)
            success = broker_service.connect_broker(config.name, broker_data)
            if success:
                app_state.system_status['brokers'][config.name] = 'connected'
                logger.info(f"Broker {config.name} connected")
            else:
                app_state.system_status['brokers'][config.name] = 'failed'
                logger.warning(f"Failed to connect broker {config.name}")
    except Exception as e:
        logger.error(f"Error loading broker configs: {e}")

def load_ml_models():
    """Load existing ML models from database"""
    try:
        models = MLModel.query.filter_by(active=True).all()
        for model in models:
            model_info = ml_service.load_model(model.path)
            if 'error' not in model_info:
                app_state.system_status['ml_models'] += 1
                logger.info(f"ML model {model.name} loaded")
            else:
                logger.warning(f"Failed to load ML model {model.name}: {model_info['error']}")
    except Exception as e:
        logger.error(f"Error loading ML models: {e}")

# WebSocket Event Handlers
@socketio.on('connect')
def handle_connect(auth):
    """Handle client connection"""
    client_id = request.sid
    app_state.connected_clients.add(client_id)
    
    logger.info(f'Client connected: {client_id}')
    
    # Send initial status
    emit('status', {
        'status': 'connected',
        'message': 'Connected to QuantConnect Trading Bot',
        'timestamp': datetime.now().isoformat(),
        'system_status': app_state.system_status
    })
    
    # Join trading room for updates
    join_room('trading_updates')
    
    # Send current data if available
    if app_state.current_signals:
        emit('signals_update', {
            'signals': app_state.current_signals,
            'market_data': app_state.market_data,
            'timestamp': datetime.now().isoformat()
        })

@socketio.on('disconnect')
def handle_disconnect():
    """Handle client disconnection"""
    client_id = request.sid
    app_state.connected_clients.discard(client_id)
    leave_room('trading_updates')
    logger.info(f'Client disconnected: {client_id}')

@socketio.on('start_trading')
def handle_start_trading(data):
    """Start automated trading"""
    try:
        if app_state.trading_active:
            emit('error', {'message': 'Trading is already active'})
            return
        
        strategy_config = data.get('strategy_config', {})
        
        # Validate configuration
        if not validate_trading_config(strategy_config):
            emit('error', {'message': 'Invalid trading configuration'})
            return
        
        # Create new trading session
        session = TradingSession(
            name=strategy_config.get('name', f'Session_{datetime.now().strftime("%Y%m%d_%H%M%S")}'),
            config=json.dumps(strategy_config),
            status='active',
            start_time=datetime.now()
        )
        db.session.add(session)
        db.session.commit()
        
        app_state.trading_sessions[session.id] = session
        app_state.trading_active = True
        
        # Start trading thread
        trading_thread = threading.Thread(
            target=run_trading_loop,
            args=(strategy_config, session.id),
            daemon=True
        )
        trading_thread.start()
        
        # Notify all clients
        socketio.emit('trading_status', {
            'active': True,
            'session_id': session.id,
            'message': 'Trading started successfully',
            'timestamp': datetime.now().isoformat()
        }, room='trading_updates')
        
        logger.info(f"Trading started with session ID: {session.id}")
        
    except Exception as e:
        logger.error(f"Error starting trading: {e}")
        emit('error', {'message': f'Failed to start trading: {str(e)}'})

@socketio.on('stop_trading')
def handle_stop_trading():
    """Stop automated trading"""
    try:
        app_state.trading_active = False
        
        # Update active sessions
        for session_id, session in app_state.trading_sessions.items():
            if session.status == 'active':
                session.status = 'stopped'
                session.end_time = datetime.now()
                db.session.commit()
        
        app_state.trading_sessions.clear()
        
        # Notify all clients
        socketio.emit('trading_status', {
            'active': False,
            'message': 'Trading stopped',
            'timestamp': datetime.now().isoformat()
        }, room='trading_updates')
        
        logger.info("Trading stopped")
        
    except Exception as e:
        logger.error(f"Error stopping trading: {e}")
        emit('error', {'message': f'Failed to stop trading: {str(e)}'})

@socketio.on('get_market_data')
def handle_get_market_data(data):
    """Get real-time market data for specified symbols"""
    try:
        symbols = data.get('symbols', [])
        if not symbols:
            symbols = ['EURUSD', 'GBPUSD', 'USDJPY', 'BTCUSD', 'SPY']
        
        market_data = market_service.get_market_data(symbols)
        app_state.market_data.update(market_data)
        
        emit('market_data_update', {
            'data': market_data,
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Error getting market data: {e}")
        emit('error', {'message': f'Failed to get market data: {str(e)}'})

def validate_trading_config(config: Dict) -> bool:
    """Validate trading configuration"""
    required_fields = ['name', 'symbols', 'strategy_type']
    return all(field in config for field in required_fields)

def run_trading_loop(strategy_config: Dict, session_id: int):
    """Main trading loop running in background thread"""
    logger.info(f"Starting trading loop for session {session_id}")
    
    try:
        interval = strategy_config.get('interval', 60)  # seconds
        max_iterations = strategy_config.get('max_iterations', 0)  # 0 = unlimited
        iteration_count = 0
        
        while app_state.trading_active:
            try:
                iteration_count += 1
                
                # Check max iterations
                if max_iterations > 0 and iteration_count > max_iterations:
                    logger.info(f"Reached max iterations ({max_iterations}) for session {session_id}")
                    break
                
                # Get market data
                symbols = strategy_config.get('symbols', ['EURUSD', 'GBPUSD'])
                market_data = market_service.get_market_data(symbols)
                app_state.market_data.update(market_data)
                
                # Generate signals
                all_signals = {}
                
                # ML signals
                if strategy_config.get('use_ml', False):
                    ml_signals = ml_service.generate_signals(market_data)
                    all_signals.update(ml_signals)
                
                # Lean algorithm signals
                if strategy_config.get('use_lean', True):
                    lean_signals = lean_service.run_algorithm(strategy_config)
                    all_signals.update(lean_signals)
                
                # Risk management filtering
                filtered_signals = risk_service.filter_signals(
                    all_signals, 
                    market_data, 
                    strategy_config
                )
                
                app_state.current_signals = filtered_signals
                
                # Execute trades through brokers
                if filtered_signals:
                    execution_results = {}
                    
                    # Get active brokers from config
                    active_brokers = strategy_config.get('brokers', [])
                    
                    for broker_name in active_brokers:
                        if broker_name in app_state.system_status['brokers']:
                            try:
                                result = broker_service.execute_signals(
                                    broker_name, 
                                    filtered_signals
                                )
                                execution_results[broker_name] = result
                            except Exception as e:
                                logger.error(f"Error executing on {broker_name}: {e}")
                                execution_results[broker_name] = {'error': str(e)}
                    
                    # Save signals to database
                    save_signals_to_db(filtered_signals, session_id)
                    
                    # Broadcast update to all connected clients
                    socketio.emit('signals_update', {
                        'signals': filtered_signals,
                        'market_data': market_data,
                        'execution_results': execution_results,
                        'timestamp': datetime.now().isoformat(),
                        'session_id': session_id,
                        'iteration': iteration_count
                    }, room='trading_updates')
                
                # Update system status
                app_state.system_status['last_update'] = datetime.now().isoformat()
                
                # Wait for next iteration
                threading.Event().wait(interval)
                
            except Exception as e:
                logger.error(f"Error in trading loop iteration {iteration_count}: {e}")
                logger.error(traceback.format_exc())
                
                # Emit error to clients
                socketio.emit('trading_error', {
                    'message': str(e),
                    'iteration': iteration_count,
                    'session_id': session_id,
                    'timestamp': datetime.now().isoformat()
                }, room='trading_updates')
                
                # Brief pause before retrying
                threading.Event().wait(5)
    
    except Exception as e:
        logger.error(f"Critical error in trading loop: {e}")
        logger.error(traceback.format_exc())
    
    finally:
        # Cleanup
        if session_id in app_state.trading_sessions:
            session = app_state.trading_sessions[session_id]
            session.status = 'completed'
            session.end_time = datetime.now()
            db.session.commit()
        
        logger.info(f"Trading loop ended for session {session_id}")

def save_signals_to_db(signals: Dict, session_id: int):
    """Save trading signals to database"""
    try:
        for symbol, signal_data in signals.items():
            signal = TradingSignal(
                session_id=session_id,
                symbol=symbol,
                signal_type=signal_data.get('type'),
                strength=signal_data.get('strength', 0),
                confidence=signal_data.get('confidence', 0),
                price=signal_data.get('price', 0),
                source=signal_data.get('source', 'unknown'),
                timestamp=datetime.now(),
                metadata=json.dumps(signal_data)
            )
            db.session.add(signal)
        
        db.session.commit()
        
    except Exception as e:
        logger.error(f"Error saving signals to database: {e}")
        db.session.rollback()

# Health check endpoint
@app.route('/api/health')
def health_check():
    """Application health check"""
    try:
        # Check database connection
        db.session.execute('SELECT 1')
        db_status = True
    except:
        db_status = False
    
    # Check Redis connection
    redis_status = False
    if redis_client:
        try:
            redis_client.ping()
            redis_status = True
        except:
            pass
    
    health_status = {
        'status': 'healthy' if db_status and redis_status else 'degraded',
        'timestamp': datetime.now().isoformat(),
        'version': app.config.get('VERSION', '1.0.0'),
        'services': {
            'database': db_status,
            'redis': redis_status,
            'lean_engine': lean_service.is_connected(),
            'ml_models': len(ml_service.loaded_models),
            'connected_brokers': len([b for b, s in app_state.system_status['brokers'].items() if s == 'connected']),
            'active_sessions': len([s for s in app_state.trading_sessions.values() if s.status == 'active'])
        },
        'trading': {
            'active': app_state.trading_active,
            'connected_clients': len(app_state.connected_clients),
            'current_signals': len(app_state.current_signals)
        }
    }
    
    status_code = 200 if health_status['status'] == 'healthy' else 503
    return jsonify(health_status), status_code

# Error handlers
@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Endpoint not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    logger.error(f"Internal server error: {error}")
    return jsonify({'error': 'Internal server error'}), 500

@app.errorhandler(Exception)
def handle_exception(e):
    logger.error(f"Unhandled exception: {e}")
    logger.error(traceback.format_exc())
    return jsonify({'error': 'An unexpected error occurred'}), 500

if __name__ == '__main__':
    # Development server
    logger.info("Starting QuantConnect Trading Bot in development mode")
    socketio.run(
        app,
        host='0.0.0.0',
        port=5000,
        debug=app.config.get('DEBUG', False),
        use_reloader=False  # Disable reloader in production
    )
else:
    # Production server (gunicorn)
    logger.info("QuantConnect Trading Bot ready for production")