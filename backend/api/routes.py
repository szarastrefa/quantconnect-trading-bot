#!/usr/bin/env python3
"""
API Routes - REST API endpoints for the trading bot
Provides endpoints for broker management, ML models, trading operations, and system status
"""

import os
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
from werkzeug.utils import secure_filename

from flask import Blueprint, request, jsonify, send_file, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity, create_access_token

# Internal imports
from services.broker_service import BrokerService
from services.ml_service import MLService
from services.lean_service import LeanService
from models.database import db
from models.trading_models import BrokerConfig, MLModel, TradingSignal, TradingSession
from utils.helpers import validate_json, sanitize_input
from utils.decorators import handle_errors, validate_request

logger = logging.getLogger(__name__)

# Create API blueprint
api_bp = Blueprint('api', __name__)

# Get services (will be injected by main app)
broker_service: BrokerService = None
ml_service: MLService = None
lean_service: LeanService = None

def init_services(broker_svc, ml_svc, lean_svc):
    """Initialize services - called from main app"""
    global broker_service, ml_service, lean_service
    broker_service = broker_svc
    ml_service = ml_svc
    lean_service = lean_svc

# ============================================================================
# SYSTEM STATUS ENDPOINTS
# ============================================================================

@api_bp.route('/status', methods=['GET'])
@handle_errors
def get_system_status():
    """Get overall system status"""
    try:
        # Get service statuses
        broker_status = len(broker_service.connections) if broker_service else 0
        ml_models_count = len(ml_service.loaded_models) if ml_service else 0
        lean_status = lean_service.is_connected() if lean_service else False
        
        # Get active trading sessions
        active_sessions = TradingSession.query.filter_by(status='active').count()
        
        status = {
            'timestamp': datetime.now().isoformat(),
            'system_healthy': True,
            'services': {
                'broker_service': {
                    'connected': broker_status > 0,
                    'active_connections': broker_status
                },
                'ml_service': {
                    'loaded_models': ml_models_count,
                    'available': ml_service is not None
                },
                'lean_service': {
                    'connected': lean_status,
                    'available': lean_service is not None
                }
            },
            'trading': {
                'active_sessions': active_sessions,
                'total_signals_today': TradingSignal.query.filter(
                    TradingSignal.timestamp >= datetime.now().date()
                ).count()
            }
        }
        
        return jsonify(status)
        
    except Exception as e:
        logger.error(f"Error getting system status: {e}")
        return jsonify({'error': str(e)}), 500

# ============================================================================
# BROKER MANAGEMENT ENDPOINTS
# ============================================================================

@api_bp.route('/brokers', methods=['GET'])
@handle_errors
def get_supported_brokers():
    """Get list of supported brokers"""
    try:
        if not broker_service:
            return jsonify({'error': 'Broker service not available'}), 503
        
        brokers = broker_service.get_supported_brokers()
        return jsonify({
            'brokers': brokers,
            'total_count': len(brokers)
        })
        
    except Exception as e:
        logger.error(f"Error getting supported brokers: {e}")
        return jsonify({'error': str(e)}), 500

@api_bp.route('/brokers/active', methods=['GET'])
@handle_errors
def get_active_brokers():
    """Get list of currently connected brokers"""
    try:
        if not broker_service:
            return jsonify({'error': 'Broker service not available'}), 503
        
        active_brokers = []
        for name, connection in broker_service.connections.items():
            active_brokers.append({
                'name': name,
                'type': connection.broker_type,
                'connected_at': connection.connected_at.isoformat(),
                'is_active': connection.is_active
            })
        
        return jsonify({
            'active_brokers': active_brokers,
            'total_count': len(active_brokers)
        })
        
    except Exception as e:
        logger.error(f"Error getting active brokers: {e}")
        return jsonify({'error': str(e)}), 500

@api_bp.route('/brokers/connect', methods=['POST'])
@handle_errors
@validate_request(['broker_name', 'credentials'])
def connect_broker():
    """Connect to a broker"""
    try:
        if not broker_service:
            return jsonify({'error': 'Broker service not available'}), 503
        
        data = request.json
        broker_name = sanitize_input(data['broker_name'])
        credentials = data['credentials']
        
        # Validate credentials structure
        if not isinstance(credentials, dict):
            return jsonify({'error': 'Credentials must be a dictionary'}), 400
        
        # Connect to broker
        success = broker_service.connect_broker(broker_name, credentials)
        
        if success:
            # Save configuration to database
            broker_config = BrokerConfig(
                name=broker_name,
                config=json.dumps(credentials),
                active=True,
                created_at=datetime.now(),
                updated_at=datetime.now()
            )
            
            # Check if config already exists
            existing_config = BrokerConfig.query.filter_by(name=broker_name).first()
            if existing_config:
                existing_config.config = json.dumps(credentials)
                existing_config.active = True
                existing_config.updated_at = datetime.now()
            else:
                db.session.add(broker_config)
            
            db.session.commit()
            
            return jsonify({
                'success': True,
                'message': f'Successfully connected to {broker_name}',
                'broker_name': broker_name
            })
        else:
            return jsonify({
                'success': False,
                'error': f'Failed to connect to {broker_name}'
            }), 400
        
    except Exception as e:
        logger.error(f"Error connecting broker: {e}")
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@api_bp.route('/brokers/<broker_name>/disconnect', methods=['POST'])
@handle_errors
def disconnect_broker(broker_name: str):
    """Disconnect from a broker"""
    try:
        if not broker_service:
            return jsonify({'error': 'Broker service not available'}), 503
        
        broker_name = sanitize_input(broker_name)
        success = broker_service.disconnect_broker(broker_name)
        
        if success:
            # Update database
            config = BrokerConfig.query.filter_by(name=broker_name).first()
            if config:
                config.active = False
                config.updated_at = datetime.now()
                db.session.commit()
            
            return jsonify({
                'success': True,
                'message': f'Disconnected from {broker_name}'
            })
        else:
            return jsonify({
                'success': False,
                'error': f'Failed to disconnect from {broker_name}'
            }), 400
        
    except Exception as e:
        logger.error(f"Error disconnecting broker: {e}")
        return jsonify({'error': str(e)}), 500

@api_bp.route('/brokers/<broker_name>/account', methods=['GET'])
@handle_errors
def get_broker_account_info(broker_name: str):
    """Get account information from broker"""
    try:
        if not broker_service:
            return jsonify({'error': 'Broker service not available'}), 503
        
        broker_name = sanitize_input(broker_name)
        account_info = broker_service.get_account_info(broker_name)
        
        return jsonify({
            'broker_name': broker_name,
            'account_info': account_info,
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Error getting account info for {broker_name}: {e}")
        return jsonify({'error': str(e)}), 500

@api_bp.route('/brokers/<broker_name>/positions', methods=['GET'])
@handle_errors
def get_broker_positions(broker_name: str):
    """Get open positions from broker"""
    try:
        if not broker_service:
            return jsonify({'error': 'Broker service not available'}), 503
        
        broker_name = sanitize_input(broker_name)
        positions = broker_service.get_positions(broker_name)
        
        return jsonify({
            'broker_name': broker_name,
            'positions': positions,
            'position_count': len(positions),
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Error getting positions for {broker_name}: {e}")
        return jsonify({'error': str(e)}), 500

# ============================================================================
# ML MODEL MANAGEMENT ENDPOINTS
# ============================================================================

@api_bp.route('/models', methods=['GET'])
@handle_errors
def get_ml_models():
    """Get list of available ML models"""
    try:
        if not ml_service:
            return jsonify({'error': 'ML service not available'}), 503
        
        models = ml_service.get_models_list()
        return jsonify({
            'models': models,
            'total_count': len(models)
        })
        
    except Exception as e:
        logger.error(f"Error getting ML models: {e}")
        return jsonify({'error': str(e)}), 500

@api_bp.route('/models/<model_name>', methods=['GET'])
@handle_errors
def get_ml_model_details(model_name: str):
    """Get detailed information about a specific ML model"""
    try:
        if not ml_service:
            return jsonify({'error': 'ML service not available'}), 503
        
        model_name = sanitize_input(model_name)
        model_details = ml_service.get_model_details(model_name)
        
        return jsonify(model_details)
        
    except Exception as e:
        logger.error(f"Error getting model details for {model_name}: {e}")
        return jsonify({'error': str(e)}), 500

@api_bp.route('/models/upload', methods=['POST'])
@handle_errors
def upload_ml_model():
    """Upload and import ML model file"""
    try:
        if not ml_service:
            return jsonify({'error': 'ML service not available'}), 503
        
        # Check if file is present
        if 'model_file' not in request.files:
            return jsonify({'error': 'No model file provided'}), 400
        
        file = request.files['model_file']
        if file.filename == '':
            return jsonify({'error': 'No file selected'}), 400
        
        # Get optional parameters
        model_name = request.form.get('model_name')
        description = request.form.get('description', '')
        
        # Secure the filename
        filename = secure_filename(file.filename)
        if not filename:
            return jsonify({'error': 'Invalid filename'}), 400
        
        # Save uploaded file temporarily
        upload_dir = '/tmp/model_uploads'
        os.makedirs(upload_dir, exist_ok=True)
        file_path = os.path.join(upload_dir, filename)
        file.save(file_path)
        
        try:
            # Import the model
            result = ml_service.import_model_file(file_path, model_name, description)
            
            # Clean up temporary file
            if os.path.exists(file_path):
                os.remove(file_path)
            
            if result.get('success'):
                # Save model info to database
                model_info = result.get('model_info', {})
                ml_model = MLModel(
                    name=result['model_name'],
                    file_path=model_info.get('file_path', ''),
                    model_type=model_info.get('type', 'unknown'),
                    algorithm=model_info.get('algorithm', 'unknown'),
                    accuracy=model_info.get('accuracy', 0.0),
                    description=description,
                    active=True,
                    created_at=datetime.now(),
                    updated_at=datetime.now()
                )
                
                # Check if model already exists
                existing_model = MLModel.query.filter_by(name=result['model_name']).first()
                if existing_model:
                    existing_model.file_path = model_info.get('file_path', existing_model.file_path)
                    existing_model.model_type = model_info.get('type', existing_model.model_type)
                    existing_model.algorithm = model_info.get('algorithm', existing_model.algorithm)
                    existing_model.accuracy = model_info.get('accuracy', existing_model.accuracy)
                    existing_model.description = description or existing_model.description
                    existing_model.active = True
                    existing_model.updated_at = datetime.now()
                else:
                    db.session.add(ml_model)
                
                db.session.commit()
                
                return jsonify(result)
            else:
                return jsonify(result), 400
                
        except Exception as e:
            # Clean up temporary file on error
            if os.path.exists(file_path):
                os.remove(file_path)
            raise e
        
    except Exception as e:
        logger.error(f"Error uploading model: {e}")
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@api_bp.route('/models/<model_name>/export', methods=['GET'])
@handle_errors
def export_ml_model(model_name: str):
    """Export ML model and download as file"""
    try:
        if not ml_service:
            return jsonify({'error': 'ML service not available'}), 503
        
        model_name = sanitize_input(model_name)
        
        # Export model to temporary directory
        export_dir = '/tmp/model_exports'
        result = ml_service.export_model(model_name, export_dir)
        
        if result.get('success'):
            exported_files = result.get('exported_files', [])
            if exported_files:
                # Return the first (main) model file
                model_file = exported_files[0]
                return send_file(
                    model_file,
                    as_attachment=True,
                    download_name=f"{model_name}_model.{model_file.split('.')[-1]}"
                )
            else:
                return jsonify({'error': 'No files to export'}), 404
        else:
            return jsonify(result), 400
        
    except Exception as e:
        logger.error(f"Error exporting model {model_name}: {e}")
        return jsonify({'error': str(e)}), 500

@api_bp.route('/models/<model_name>/delete', methods=['DELETE'])
@handle_errors
def delete_ml_model(model_name: str):
    """Delete ML model"""
    try:
        if not ml_service:
            return jsonify({'error': 'ML service not available'}), 503
        
        model_name = sanitize_input(model_name)
        result = ml_service.delete_model(model_name)
        
        if result.get('success'):
            # Remove from database
            model = MLModel.query.filter_by(name=model_name).first()
            if model:
                db.session.delete(model)
                db.session.commit()
            
            return jsonify(result)
        else:
            return jsonify(result), 400
        
    except Exception as e:
        logger.error(f"Error deleting model {model_name}: {e}")
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@api_bp.route('/models/train', methods=['POST'])
@handle_errors
@validate_request(['training_data', 'model_config'])
def train_ml_model():
    """Train new ML model"""
    try:
        if not ml_service:
            return jsonify({'error': 'ML service not available'}), 503
        
        data = request.json
        training_data_json = data['training_data']
        model_config = data['model_config']
        
        # Convert JSON to DataFrame
        import pandas as pd
        training_df = pd.DataFrame(training_data_json)
        
        # Train model
        result = ml_service.train_model(training_df, model_config)
        
        if result.success:
            # Save model info to database
            model_name = result.model_name
            ml_model = MLModel(
                name=model_name,
                file_path=result.model_path,
                model_type=model_config.get('algorithm', 'unknown'),
                algorithm=model_config.get('algorithm', 'unknown'),
                accuracy=result.metrics.get('accuracy', result.metrics.get('r2_score', 0.0)),
                description=model_config.get('description', f'Trained {model_config.get("algorithm", "unknown")} model'),
                active=True,
                created_at=datetime.now(),
                updated_at=datetime.now()
            )
            
            db.session.add(ml_model)
            db.session.commit()
            
            return jsonify({
                'success': True,
                'model_name': result.model_name,
                'metrics': result.metrics,
                'training_time': result.training_time,
                'model_path': result.model_path
            })
        else:
            return jsonify({
                'success': False,
                'error': result.error_message
            }), 400
        
    except Exception as e:
        logger.error(f"Error training model: {e}")
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

# ============================================================================
# LEAN ALGORITHM ENDPOINTS
# ============================================================================

@api_bp.route('/algorithms', methods=['GET'])
@handle_errors
def get_lean_algorithms():
    """Get list of available Lean algorithms"""
    try:
        if not lean_service:
            return jsonify({'error': 'Lean service not available'}), 503
        
        algorithms = lean_service.get_algorithms_list()
        return jsonify({
            'algorithms': algorithms,
            'total_count': len(algorithms)
        })
        
    except Exception as e:
        logger.error(f"Error getting algorithms: {e}")
        return jsonify({'error': str(e)}), 500

@api_bp.route('/algorithms/create', methods=['POST'])
@handle_errors
@validate_request(['algorithm_name', 'algorithm_code'])
def create_lean_algorithm():
    """Create new Lean algorithm"""
    try:
        if not lean_service:
            return jsonify({'error': 'Lean service not available'}), 503
        
        data = request.json
        algorithm_name = sanitize_input(data['algorithm_name'])
        algorithm_code = data['algorithm_code']
        description = data.get('description', '')
        
        result = lean_service.create_algorithm(algorithm_name, algorithm_code, description)
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"Error creating algorithm: {e}")
        return jsonify({'error': str(e)}), 500

@api_bp.route('/algorithms/<algorithm_name>/backtest', methods=['POST'])
@handle_errors
def run_algorithm_backtest(algorithm_name: str):
    """Run backtest for algorithm"""
    try:
        if not lean_service:
            return jsonify({'error': 'Lean service not available'}), 503
        
        algorithm_name = sanitize_input(algorithm_name)
        data = request.json or {}
        
        # Create backtest config
        from services.lean_service import BacktestConfig
        backtest_config = BacktestConfig(
            start_date=data.get('start_date', '2024-01-01'),
            end_date=data.get('end_date', '2024-12-31'),
            initial_cash=data.get('initial_cash', 100000)
        )
        
        result = lean_service.backtest_algorithm(algorithm_name, backtest_config)
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"Error running backtest for {algorithm_name}: {e}")
        return jsonify({'error': str(e)}), 500

# ============================================================================
# TRADING SIGNALS AND SESSIONS ENDPOINTS
# ============================================================================

@api_bp.route('/signals/current', methods=['GET'])
@handle_errors
def get_current_signals():
    """Get current trading signals"""
    try:
        # Get latest signals from the last 5 minutes
        since_time = datetime.now() - timedelta(minutes=5)
        signals = TradingSignal.query.filter(
            TradingSignal.timestamp >= since_time
        ).order_by(TradingSignal.timestamp.desc()).all()
        
        current_signals = {}
        for signal in signals:
            if signal.symbol not in current_signals:
                current_signals[signal.symbol] = {
                    'type': signal.signal_type,
                    'strength': signal.strength,
                    'confidence': signal.confidence,
                    'price': signal.price,
                    'source': signal.source,
                    'timestamp': signal.timestamp.isoformat()
                }
        
        return jsonify({
            'signals': current_signals,
            'signal_count': len(current_signals),
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Error getting current signals: {e}")
        return jsonify({'error': str(e)}), 500

@api_bp.route('/signals/history', methods=['GET'])
@handle_errors
def get_signals_history():
    """Get historical trading signals"""
    try:
        # Get query parameters
        limit = request.args.get('limit', 100, type=int)
        symbol = request.args.get('symbol')
        since_date = request.args.get('since')
        
        # Build query
        query = TradingSignal.query
        
        if symbol:
            query = query.filter(TradingSignal.symbol == symbol)
        
        if since_date:
            try:
                since_dt = datetime.fromisoformat(since_date)
                query = query.filter(TradingSignal.timestamp >= since_dt)
            except ValueError:
                return jsonify({'error': 'Invalid date format'}), 400
        
        signals = query.order_by(TradingSignal.timestamp.desc()).limit(limit).all()
        
        signals_data = []
        for signal in signals:
            signals_data.append({
                'id': signal.id,
                'symbol': signal.symbol,
                'type': signal.signal_type,
                'strength': signal.strength,
                'confidence': signal.confidence,
                'price': signal.price,
                'source': signal.source,
                'timestamp': signal.timestamp.isoformat(),
                'session_id': signal.session_id
            })
        
        return jsonify({
            'signals': signals_data,
            'total_count': len(signals_data),
            'filters': {
                'symbol': symbol,
                'since': since_date,
                'limit': limit
            }
        })
        
    except Exception as e:
        logger.error(f"Error getting signals history: {e}")
        return jsonify({'error': str(e)}), 500

@api_bp.route('/sessions', methods=['GET'])
@handle_errors
def get_trading_sessions():
    """Get trading sessions"""
    try:
        status_filter = request.args.get('status')
        limit = request.args.get('limit', 50, type=int)
        
        query = TradingSession.query
        
        if status_filter:
            query = query.filter(TradingSession.status == status_filter)
        
        sessions = query.order_by(TradingSession.created_at.desc()).limit(limit).all()
        
        sessions_data = []
        for session in sessions:
            sessions_data.append({
                'id': session.id,
                'name': session.name,
                'status': session.status,
                'start_time': session.start_time.isoformat() if session.start_time else None,
                'end_time': session.end_time.isoformat() if session.end_time else None,
                'created_at': session.created_at.isoformat(),
                'config': json.loads(session.config) if session.config else {}
            })
        
        return jsonify({
            'sessions': sessions_data,
            'total_count': len(sessions_data)
        })
        
    except Exception as e:
        logger.error(f"Error getting trading sessions: {e}")
        return jsonify({'error': str(e)}), 500

@api_bp.route('/sessions/<int:session_id>/signals', methods=['GET'])
@handle_errors
def get_session_signals(session_id: int):
    """Get signals for a specific trading session"""
    try:
        # Check if session exists
        session = TradingSession.query.get_or_404(session_id)
        
        # Get signals for this session
        signals = TradingSignal.query.filter_by(session_id=session_id).order_by(
            TradingSignal.timestamp.desc()
        ).all()
        
        signals_data = []
        for signal in signals:
            signals_data.append({
                'id': signal.id,
                'symbol': signal.symbol,
                'type': signal.signal_type,
                'strength': signal.strength,
                'confidence': signal.confidence,
                'price': signal.price,
                'source': signal.source,
                'timestamp': signal.timestamp.isoformat()
            })
        
        return jsonify({
            'session': {
                'id': session.id,
                'name': session.name,
                'status': session.status
            },
            'signals': signals_data,
            'signal_count': len(signals_data)
        })
        
    except Exception as e:
        logger.error(f"Error getting session signals: {e}")
        return jsonify({'error': str(e)}), 500

# ============================================================================
# MARKET DATA ENDPOINTS
# ============================================================================

@api_bp.route('/market-data', methods=['GET'])
@handle_errors
def get_market_data():
    """Get current market data"""
    try:
        symbols = request.args.getlist('symbols')
        if not symbols:
            symbols = ['SPY', 'QQQ', 'EURUSD', 'BTCUSD']
        
        # Try to get data from Lean service first
        market_data = {}
        if lean_service:
            market_data = lean_service.get_market_data(symbols)
        
        # If no data from Lean, try brokers
        if not market_data and broker_service:
            for broker_name in broker_service.connections.keys():
                broker_data = broker_service.get_market_data(broker_name, symbols)
                market_data.update(broker_data)
                if market_data:  # Stop at first successful broker
                    break
        
        return jsonify({
            'market_data': market_data,
            'symbols': symbols,
            'timestamp': datetime.now().isoformat(),
            'data_source': 'lean' if lean_service and lean_service.is_connected() else 'broker'
        })
        
    except Exception as e:
        logger.error(f"Error getting market data: {e}")
        return jsonify({'error': str(e)}), 500

# ============================================================================
# UTILITY ENDPOINTS
# ============================================================================

@api_bp.route('/generate-signals', methods=['POST'])
@handle_errors
def generate_trading_signals():
    """Manually trigger signal generation"""
    try:
        if not ml_service:
            return jsonify({'error': 'ML service not available'}), 503
        
        # Get market data
        market_data = {}
        if lean_service:
            market_data = lean_service.get_market_data()
        
        if not market_data:
            return jsonify({'error': 'No market data available'}), 400
        
        # Generate signals
        signals = ml_service.generate_signals(market_data)
        
        return jsonify({
            'success': True,
            'signals': signals,
            'signal_count': len(signals),
            'market_data': market_data,
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Error generating signals: {e}")
        return jsonify({'error': str(e)}), 500

@api_bp.route('/test-broker/<broker_name>', methods=['POST'])
@handle_errors
def test_broker_connection(broker_name: str):
    """Test broker connection with provided credentials"""
    try:
        if not broker_service:
            return jsonify({'error': 'Broker service not available'}), 503
        
        data = request.json or {}
        credentials = data.get('credentials', {})
        
        broker_name = sanitize_input(broker_name)
        
        # Test connection (without saving)
        # This is a dry run to validate credentials
        test_result = broker_service.connect_broker(f"test_{broker_name}", credentials)
        
        # Disconnect test connection immediately
        if test_result:
            broker_service.disconnect_broker(f"test_{broker_name}")
        
        return jsonify({
            'success': test_result,
            'broker_name': broker_name,
            'message': 'Connection test successful' if test_result else 'Connection test failed'
        })
        
    except Exception as e:
        logger.error(f"Error testing broker connection: {e}")
        return jsonify({'error': str(e)}), 500

# ============================================================================
# ERROR HANDLERS
# ============================================================================

@api_bp.errorhandler(400)
def bad_request(error):
    return jsonify({'error': 'Bad request'}), 400

@api_bp.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Resource not found'}), 404

@api_bp.errorhandler(405)
def method_not_allowed(error):
    return jsonify({'error': 'Method not allowed'}), 405

@api_bp.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal server error'}), 500