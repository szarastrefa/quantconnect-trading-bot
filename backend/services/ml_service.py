#!/usr/bin/env python3
"""
ML Service - Machine Learning Model Management and Signal Generation
Supports model import/export, training, and real-time signal generation
"""

import os
import json
import logging
import pickle
import joblib
import numpy as np
import pandas as pd
import warnings
import time
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Tuple, Union
from pathlib import Path
from dataclasses import dataclass, asdict

# Machine Learning libraries
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.linear_model import LogisticRegression, LinearRegression
from sklearn.svm import SVC, SVR
from sklearn.neural_network import MLPClassifier, MLPRegressor
from sklearn.preprocessing import StandardScaler, MinMaxScaler, RobustScaler
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score
from sklearn.pipeline import Pipeline

# Deep Learning
try:
    import tensorflow as tf
    from tensorflow import keras
    from tensorflow.keras import layers, models, callbacks
    TENSORFLOW_AVAILABLE = True
except ImportError:
    TENSORFLOW_AVAILABLE = False
    logger.warning("TensorFlow not available")

# Technical Analysis
try:
    import talib
    TALIB_AVAILABLE = True
except ImportError:
    TALIB_AVAILABLE = False
    logger.warning("TA-Lib not available")

try:
    import pandas_ta as ta
    PANDAS_TA_AVAILABLE = True
except ImportError:
    PANDAS_TA_AVAILABLE = False
    logger.warning("Pandas-TA not available")

# Internal imports
from utils.config import Config
from utils.helpers import validate_file_type, sanitize_filename

warnings.filterwarnings('ignore')
logger = logging.getLogger(__name__)

@dataclass
class ModelInfo:
    name: str
    type: str  # 'sklearn', 'tensorflow', 'xgboost', 'lightgbm'
    algorithm: str  # 'random_forest', 'neural_network', etc.
    version: str
    created_at: datetime
    accuracy: float = 0.0
    features: List[str] = None
    target: str = None
    parameters: Dict[str, Any] = None
    file_size: int = 0
    description: str = ""

@dataclass
class TrainingResult:
    model_name: str
    success: bool
    metrics: Dict[str, float]
    training_time: float
    model_path: str
    error_message: str = None

class MLService:
    """Machine Learning service for trading signal generation and model management"""
    
    def __init__(self, config: Config):
        self.config = config
        self.models_dir = Path(config.get('MODELS_DIR', '/app/models/trained_models'))
        self.configs_dir = Path(config.get('CONFIGS_DIR', '/app/models/model_configs'))
        
        # Create directories
        self.models_dir.mkdir(parents=True, exist_ok=True)
        self.configs_dir.mkdir(parents=True, exist_ok=True)
        
        # Loaded models cache
        self.loaded_models: Dict[str, Any] = {}
        self.model_scalers: Dict[str, Any] = {}
        self.model_info: Dict[str, ModelInfo] = {}
        
        # Supported model types
        self.supported_sklearn_models = {
            'random_forest': RandomForestClassifier,
            'gradient_boosting': GradientBoostingClassifier,
            'logistic_regression': LogisticRegression,
            'linear_regression': LinearRegression,
            'svm_classifier': SVC,
            'svm_regressor': SVR,
            'mlp_classifier': MLPClassifier,
            'mlp_regressor': MLPRegressor
        }
        
        # Technical indicators configuration
        self.technical_indicators = {
            'sma': {'periods': [10, 20, 50, 200]},
            'ema': {'periods': [12, 26, 50]},
            'rsi': {'period': 14},
            'macd': {'fast': 12, 'slow': 26, 'signal': 9},
            'bollinger_bands': {'period': 20, 'std': 2},
            'stochastic': {'k_period': 14, 'd_period': 3},
            'atr': {'period': 14},
            'adx': {'period': 14},
            'cci': {'period': 20},
            'williams_r': {'period': 14}
        }
        
        logger.info("MLService initialized")

    def initialize(self) -> bool:
        """Initialize ML service and load existing models"""
        try:
            self._load_existing_models()
            logger.info(f"MLService initialized with {len(self.loaded_models)} models")
            return True
        except Exception as e:
            logger.error(f"MLService initialization failed: {e}")
            return False

    def _load_existing_models(self):
        """Load all existing models from disk"""
        try:
            model_files = list(self.models_dir.glob('*.pkl')) + \
                         list(self.models_dir.glob('*.joblib')) + \
                         list(self.models_dir.glob('*.h5'))
            
            for model_file in model_files:
                try:
                    model_info = self.load_model(str(model_file))
                    if 'error' not in model_info:
                        logger.info(f"Loaded model: {model_file.stem}")
                except Exception as e:
                    logger.warning(f"Failed to load model {model_file}: {e}")
            
            logger.info(f"Loaded {len(self.loaded_models)} models")
            
        except Exception as e:
            logger.error(f"Error loading existing models: {e}")

    def import_model_file(self, file_path: str, model_name: str = None, 
                         description: str = "") -> Dict[str, Any]:
        """Import model from uploaded file"""
        try:
            file_path = Path(file_path)
            
            if not file_path.exists():
                return {'error': 'File does not exist'}
            
            if not validate_file_type(str(file_path), ['.pkl', '.joblib', '.h5']):
                return {'error': 'Unsupported file format. Supported: .pkl, .joblib, .h5'}
            
            if model_name is None:
                model_name = file_path.stem
            
            model_name = sanitize_filename(model_name)
            
            # Copy to models directory
            target_path = self.models_dir / f"{model_name}{file_path.suffix}"
            if file_path != target_path:
                import shutil
                shutil.copy2(file_path, target_path)
            
            # Load and validate model
            result = self.load_model(str(target_path))
            if 'error' in result:
                # Clean up if loading failed
                if target_path.exists():
                    target_path.unlink()
                return result
            
            # Update description if provided
            if description:
                self._update_model_description(model_name, description)
            
            logger.info(f"Model {model_name} imported successfully from {file_path}")
            
            return {
                'success': True,
                'model_name': model_name,
                'imported_from': str(file_path),
                'model_info': result.get('info', {})
            }
            
        except Exception as e:
            logger.error(f"Error importing model: {e}")
            return {'error': str(e)}

    def export_model(self, model_name: str, export_dir: str = None) -> Dict[str, Any]:
        """Export model with all associated files"""
        try:
            if model_name not in self.loaded_models:
                return {'error': f'Model {model_name} not found'}
            
            if export_dir is None:
                export_dir = '/tmp/model_exports'
            
            export_path = Path(export_dir)
            export_path.mkdir(parents=True, exist_ok=True)
            
            exported_files = []
            
            # Find and copy model file
            model_files = list(self.models_dir.glob(f"{model_name}.*"))
            if model_files:
                model_file = model_files[0]
                target_file = export_path / model_file.name
                
                import shutil
                shutil.copy2(model_file, target_file)
                exported_files.append(str(target_file))
            
            # Copy config file if exists
            config_file = self.configs_dir / f"{model_name}_config.json"
            if config_file.exists():
                target_config = export_path / f"{model_name}_config.json"
                shutil.copy2(config_file, target_config)
                exported_files.append(str(target_config))
            
            # Copy scaler file if exists
            scaler_file = self.configs_dir / f"{model_name}_scaler.pkl"
            if scaler_file.exists():
                target_scaler = export_path / f"{model_name}_scaler.pkl"
                shutil.copy2(scaler_file, target_scaler)
                exported_files.append(str(target_scaler))
            
            if not exported_files:
                return {'error': f'No files found for model {model_name}'}
            
            logger.info(f"Model {model_name} exported to {export_path}")
            
            return {
                'success': True,
                'export_path': str(export_path),
                'exported_files': exported_files,
                'file_count': len(exported_files)
            }
            
        except Exception as e:
            logger.error(f"Error exporting model {model_name}: {e}")
            return {'error': str(e)}

    def load_model(self, model_path: str) -> Dict[str, Any]:
        """Load a single model from file"""
        try:
            model_path = Path(model_path)
            model_name = model_path.stem
            
            # Load model based on file extension
            if model_path.suffix == '.pkl':
                with open(model_path, 'rb') as f:
                    model = pickle.load(f)
                model_type = 'sklearn'
            elif model_path.suffix == '.joblib':
                model = joblib.load(model_path)
                model_type = 'sklearn'
            elif model_path.suffix == '.h5':
                if not TENSORFLOW_AVAILABLE:
                    return {'error': 'TensorFlow not available for .h5 models'}
                model = keras.models.load_model(model_path)
                model_type = 'tensorflow'
            else:
                return {'error': f'Unsupported model format: {model_path.suffix}'}
            
            # Load model configuration
            config_path = self.configs_dir / f"{model_name}_config.json"
            config = {}
            if config_path.exists():
                try:
                    with open(config_path, 'r') as f:
                        config = json.load(f)
                except Exception as e:
                    logger.warning(f"Error loading config for {model_name}: {e}")
            
            # Load scaler if exists
            scaler_path = self.configs_dir / f"{model_name}_scaler.pkl"
            if scaler_path.exists():
                try:
                    with open(scaler_path, 'rb') as f:
                        scaler = pickle.load(f)
                    self.model_scalers[model_name] = scaler
                except Exception as e:
                    logger.warning(f"Error loading scaler for {model_name}: {e}")
            
            # Store model
            self.loaded_models[model_name] = model
            
            # Create model info
            model_info = ModelInfo(
                name=model_name,
                type=model_type,
                algorithm=config.get('algorithm', 'unknown'),
                version=config.get('version', '1.0.0'),
                created_at=datetime.fromisoformat(config.get('created_at', datetime.now().isoformat())),
                accuracy=config.get('accuracy', 0.0),
                features=config.get('features', []),
                target=config.get('target', None),
                parameters=config.get('parameters', {}),
                file_size=model_path.stat().st_size,
                description=config.get('description', '')
            )
            
            self.model_info[model_name] = model_info
            
            return {
                'success': True,
                'model_name': model_name,
                'model_type': model_type,
                'info': asdict(model_info)
            }
            
        except Exception as e:
            logger.error(f"Error loading model {model_path}: {e}")
            return {'error': str(e)}

    def save_model(self, model: Any, model_name: str, model_info: Dict[str, Any], 
                   scaler: Any = None) -> Dict[str, Any]:
        """Save model to disk with metadata"""
        try:
            model_name = sanitize_filename(model_name)
            
            # Determine file extension based on model type
            if TENSORFLOW_AVAILABLE and hasattr(model, 'save') and callable(model.save):
                # TensorFlow/Keras model
                model_path = self.models_dir / f"{model_name}.h5"
                model.save(model_path)
                model_type = 'tensorflow'
            else:
                # Scikit-learn or other pickle-able models
                model_path = self.models_dir / f"{model_name}.pkl"
                with open(model_path, 'wb') as f:
                    pickle.dump(model, f)
                model_type = 'sklearn'
            
            # Save model configuration
            config = {
                **model_info,
                'model_type': model_type,
                'created_at': datetime.now().isoformat(),
                'file_path': str(model_path)
            }
            
            config_path = self.configs_dir / f"{model_name}_config.json"
            with open(config_path, 'w') as f:
                json.dump(config, f, indent=2, default=str)
            
            # Save scaler if provided
            if scaler is not None:
                scaler_path = self.configs_dir / f"{model_name}_scaler.pkl"
                with open(scaler_path, 'wb') as f:
                    pickle.dump(scaler, f)
                self.model_scalers[model_name] = scaler
            
            # Update in-memory storage
            self.loaded_models[model_name] = model
            
            info = ModelInfo(
                name=model_name,
                type=model_type,
                algorithm=model_info.get('algorithm', 'unknown'),
                version=model_info.get('version', '1.0.0'),
                created_at=datetime.now(),
                accuracy=model_info.get('accuracy', 0.0),
                features=model_info.get('features', []),
                target=model_info.get('target', None),
                parameters=model_info.get('parameters', {}),
                file_size=model_path.stat().st_size,
                description=model_info.get('description', '')
            )
            
            self.model_info[model_name] = info
            
            logger.info(f"Model {model_name} saved successfully")
            
            return {
                'success': True,
                'model_name': model_name,
                'model_path': str(model_path),
                'file_size': model_path.stat().st_size
            }
            
        except Exception as e:
            logger.error(f"Error saving model {model_name}: {e}")
            return {'error': str(e)}

    def delete_model(self, model_name: str) -> Dict[str, Any]:
        """Delete model and all associated files"""
        try:
            # Remove from memory
            if model_name in self.loaded_models:
                del self.loaded_models[model_name]
            if model_name in self.model_scalers:
                del self.model_scalers[model_name]
            if model_name in self.model_info:
                del self.model_info[model_name]
            
            # Remove files
            deleted_files = []
            
            # Model files
            for suffix in ['.pkl', '.joblib', '.h5']:
                model_file = self.models_dir / f"{model_name}{suffix}"
                if model_file.exists():
                    model_file.unlink()
                    deleted_files.append(str(model_file))
            
            # Config file
            config_file = self.configs_dir / f"{model_name}_config.json"
            if config_file.exists():
                config_file.unlink()
                deleted_files.append(str(config_file))
            
            # Scaler file
            scaler_file = self.configs_dir / f"{model_name}_scaler.pkl"
            if scaler_file.exists():
                scaler_file.unlink()
                deleted_files.append(str(scaler_file))
            
            if deleted_files:
                logger.info(f"Model {model_name} deleted successfully")
                return {'success': True, 'deleted_files': deleted_files}
            else:
                return {'error': f'Model {model_name} not found'}
                
        except Exception as e:
            logger.error(f"Error deleting model {model_name}: {e}")
            return {'error': str(e)}

    def generate_signals(self, market_data: Dict[str, Any]) -> Dict[str, Any]:
        """Generate trading signals using loaded ML models"""
        signals = {}
        
        try:
            if not self.loaded_models:
                logger.warning("No ML models loaded for signal generation")
                return signals
            
            for symbol, data in market_data.items():
                symbol_signals = {}
                
                # Generate signals with each loaded model
                for model_name, model in self.loaded_models.items():
                    try:
                        model_info = self.model_info.get(model_name)
                        if not model_info:
                            continue
                        
                        # Check if model supports this symbol
                        if model_info.features and 'symbols' in model_info.parameters:
                            supported_symbols = model_info.parameters['symbols']
                            if supported_symbols and symbol not in supported_symbols:
                                continue
                        
                        # Prepare features
                        features = self._prepare_features(data, model_info, symbol)
                        if features is None:
                            continue
                        
                        # Make prediction
                        prediction = self._make_prediction(model, model_name, features)
                        if prediction:
                            symbol_signals[model_name] = prediction
                    
                    except Exception as e:
                        logger.error(f"Error generating signal with model {model_name} for {symbol}: {e}")
                
                # Aggregate signals from multiple models
                if symbol_signals:
                    aggregated_signal = self._aggregate_signals(symbol_signals)
                    if aggregated_signal:
                        signals[symbol] = aggregated_signal
            
            return signals
            
        except Exception as e:
            logger.error(f"Error generating signals: {e}")
            return {}

    def _prepare_features(self, market_data: Dict[str, Any], model_info: ModelInfo, 
                         symbol: str) -> Optional[np.ndarray]:
        """Prepare feature vector for model prediction"""
        try:
            features = []
            
            # Basic market data features
            price = float(market_data.get('last', market_data.get('price', 0)))
            volume = float(market_data.get('volume', 0))
            bid = float(market_data.get('bid', price))
            ask = float(market_data.get('ask', price))
            
            # Basic features
            features.extend([
                price,
                volume,
                bid,
                ask,
                ask - bid,  # spread
                (ask + bid) / 2,  # mid price
                float(market_data.get('high', price)),
                float(market_data.get('low', price)),
                float(market_data.get('change', 0)),
                float(market_data.get('percentage', 0))
            ])
            
            # Technical indicators (using simulated historical data for demo)
            # In production, you would fetch real historical data
            historical_prices = self._simulate_historical_data(price, 100)
            
            # Add technical indicators
            tech_features = self._calculate_technical_indicators(historical_prices)
            features.extend(tech_features)
            
            # Time-based features
            now = datetime.now()
            features.extend([
                now.hour / 24.0,  # Hour of day (normalized)
                now.weekday() / 6.0,  # Day of week (normalized)
                now.month / 12.0,  # Month (normalized)
            ])
            
            # Convert to numpy array
            feature_array = np.array(features).reshape(1, -1)
            
            # Handle NaN values
            feature_array = np.nan_to_num(feature_array, nan=0.0, posinf=1.0, neginf=-1.0)
            
            # Apply scaling if scaler exists
            if model_info.name in self.model_scalers:
                scaler = self.model_scalers[model_info.name]
                feature_array = scaler.transform(feature_array)
            
            return feature_array
            
        except Exception as e:
            logger.error(f"Error preparing features: {e}")
            return None

    def _simulate_historical_data(self, current_price: float, length: int = 100) -> np.ndarray:
        """Simulate historical price data for technical indicators calculation"""
        # This is a simplified simulation - in production, use real historical data
        np.random.seed(42)  # For reproducible results
        returns = np.random.normal(0, 0.01, length)
        prices = [current_price]
        
        for ret in reversed(returns[:-1]):
            prices.insert(0, prices[0] * (1 + ret))
        
        return np.array(prices)

    def _calculate_technical_indicators(self, prices: np.ndarray) -> List[float]:
        """Calculate technical indicators from price data"""
        indicators = []
        
        try:
            if TALIB_AVAILABLE:
                # Moving averages
                if len(prices) >= 20:
                    sma_10 = talib.SMA(prices, timeperiod=10)[-1] if len(prices) >= 10 else prices[-1]
                    sma_20 = talib.SMA(prices, timeperiod=20)[-1]
                    ema_12 = talib.EMA(prices, timeperiod=12)[-1] if len(prices) >= 12 else prices[-1]
                    indicators.extend([sma_10, sma_20, ema_12])
                else:
                    indicators.extend([prices[-1], prices[-1], prices[-1]])
                
                # RSI
                if len(prices) >= 14:
                    rsi = talib.RSI(prices, timeperiod=14)[-1]
                    indicators.append(rsi if not np.isnan(rsi) else 50.0)
                else:
                    indicators.append(50.0)
                
                # MACD
                if len(prices) >= 26:
                    macd, macdsignal, macdhist = talib.MACD(prices)
                    indicators.extend([
                        macd[-1] if not np.isnan(macd[-1]) else 0.0,
                        macdsignal[-1] if not np.isnan(macdsignal[-1]) else 0.0,
                        macdhist[-1] if not np.isnan(macdhist[-1]) else 0.0
                    ])
                else:
                    indicators.extend([0.0, 0.0, 0.0])
                
                # Bollinger Bands
                if len(prices) >= 20:
                    bb_upper, bb_middle, bb_lower = talib.BBANDS(prices, timeperiod=20)
                    bb_position = (prices[-1] - bb_lower[-1]) / (bb_upper[-1] - bb_lower[-1]) if bb_upper[-1] != bb_lower[-1] else 0.5
                    indicators.append(bb_position if not np.isnan(bb_position) else 0.5)
                else:
                    indicators.append(0.5)
                
                # Stochastic
                if len(prices) >= 14:
                    high_prices = prices * (1 + np.random.uniform(-0.005, 0.005, len(prices)))
                    low_prices = prices * (1 + np.random.uniform(-0.005, 0.005, len(prices)))
                    slowk, slowd = talib.STOCH(high_prices, low_prices, prices)
                    indicators.extend([
                        slowk[-1] if not np.isnan(slowk[-1]) else 50.0,
                        slowd[-1] if not np.isnan(slowd[-1]) else 50.0
                    ])
                else:
                    indicators.extend([50.0, 50.0])
            else:
                # Fallback simple indicators without TA-Lib
                if len(prices) >= 20:
                    sma_10 = np.mean(prices[-10:]) if len(prices) >= 10 else prices[-1]
                    sma_20 = np.mean(prices[-20:])
                    ema_12 = prices[-1]  # Simplified
                    indicators.extend([sma_10, sma_20, ema_12])
                else:
                    indicators.extend([prices[-1], prices[-1], prices[-1]])
                
                # Simple RSI approximation
                if len(prices) >= 14:
                    price_changes = np.diff(prices[-15:])
                    gains = price_changes[price_changes > 0]
                    losses = -price_changes[price_changes < 0]
                    avg_gain = np.mean(gains) if len(gains) > 0 else 0
                    avg_loss = np.mean(losses) if len(losses) > 0 else 0
                    rs = avg_gain / avg_loss if avg_loss != 0 else 100
                    rsi = 100 - (100 / (1 + rs))
                    indicators.append(rsi)
                else:
                    indicators.append(50.0)
                
                # MACD approximation
                if len(prices) >= 26:
                    ema_12 = np.mean(prices[-12:])
                    ema_26 = np.mean(prices[-26:])
                    macd = ema_12 - ema_26
                    signal = macd * 0.8  # Simplified
                    histogram = macd - signal
                    indicators.extend([macd, signal, histogram])
                else:
                    indicators.extend([0.0, 0.0, 0.0])
                
                # Simple Bollinger Bands
                if len(prices) >= 20:
                    sma = np.mean(prices[-20:])
                    std = np.std(prices[-20:])
                    bb_upper = sma + (2 * std)
                    bb_lower = sma - (2 * std)
                    bb_position = (prices[-1] - bb_lower) / (bb_upper - bb_lower) if bb_upper != bb_lower else 0.5
                    indicators.append(bb_position)
                else:
                    indicators.append(0.5)
                
                # Simple Stochastic
                if len(prices) >= 14:
                    recent_prices = prices[-14:]
                    high_14 = np.max(recent_prices)
                    low_14 = np.min(recent_prices)
                    k_percent = ((prices[-1] - low_14) / (high_14 - low_14)) * 100 if high_14 != low_14 else 50
                    d_percent = k_percent * 0.8  # Simplified
                    indicators.extend([k_percent, d_percent])
                else:
                    indicators.extend([50.0, 50.0])
            
        except Exception as e:
            logger.warning(f"Error calculating technical indicators: {e}")
            # Return default values if calculation fails
            indicators = [prices[-1]] * 10  # Use current price as default
        
        return indicators

    def _make_prediction(self, model: Any, model_name: str, features: np.ndarray) -> Optional[Dict[str, Any]]:
        """Make prediction with model"""
        try:
            model_info = self.model_info.get(model_name)
            
            # Handle different model types
            if hasattr(model, 'predict_proba'):
                # Classification model with probability output
                try:
                    probabilities = model.predict_proba(features)[0]
                    classes = model.classes_
                    
                    max_prob_idx = np.argmax(probabilities)
                    predicted_class = classes[max_prob_idx]
                    confidence = probabilities[max_prob_idx]
                    
                    # Map prediction to trading signal
                    signal_type = self._map_prediction_to_signal(predicted_class)
                    
                    if signal_type and confidence > 0.6:  # Minimum confidence threshold
                        return {
                            'type': signal_type,
                            'strength': float(confidence),
                            'confidence': float(confidence),
                            'model': model_name,
                            'algorithm': model_info.algorithm if model_info else 'unknown',
                            'raw_prediction': str(predicted_class),
                            'all_probabilities': probabilities.tolist()
                        }
                except Exception:
                    # Fallback to regular predict
                    pass
            
            if hasattr(model, 'predict'):
                # Regular prediction (classification or regression)
                prediction = model.predict(features)[0]
                
                if isinstance(prediction, (int, float)):
                    # Numeric prediction
                    if prediction > 0.1:
                        signal_type = 'buy'
                        strength = min(abs(prediction), 1.0)
                    elif prediction < -0.1:
                        signal_type = 'sell'
                        strength = min(abs(prediction), 1.0)
                    else:
                        return None  # No clear signal
                    
                    return {
                        'type': signal_type,
                        'strength': float(strength),
                        'confidence': float(strength * 0.8),  # Slightly lower confidence for regression
                        'model': model_name,
                        'algorithm': model_info.algorithm if model_info else 'unknown',
                        'raw_prediction': float(prediction)
                    }
                
                else:
                    # Categorical prediction
                    signal_type = self._map_prediction_to_signal(prediction)
                    if signal_type:
                        return {
                            'type': signal_type,
                            'strength': 0.7,  # Default strength for categorical predictions
                            'confidence': 0.7,
                            'model': model_name,
                            'algorithm': model_info.algorithm if model_info else 'unknown',
                            'raw_prediction': str(prediction)
                        }
            
            # TensorFlow/Keras models
            if TENSORFLOW_AVAILABLE and hasattr(model, '__class__') and 'tensorflow' in str(type(model)):
                prediction = model.predict(features, verbose=0)[0]
                
                if len(prediction) == 1:
                    # Binary classification or regression
                    value = float(prediction[0])
                    if value > 0.6:
                        signal_type = 'buy'
                        strength = min(value, 1.0)
                    elif value < 0.4:
                        signal_type = 'sell'
                        strength = min(1.0 - value, 1.0)
                    else:
                        return None
                    
                    return {
                        'type': signal_type,
                        'strength': float(strength),
                        'confidence': float(strength),
                        'model': model_name,
                        'algorithm': model_info.algorithm if model_info else 'neural_network',
                        'raw_prediction': value
                    }
                
                elif len(prediction) > 1:
                    # Multi-class classification
                    max_idx = np.argmax(prediction)
                    confidence = float(prediction[max_idx])
                    
                    # Map class index to signal
                    if max_idx == 0:
                        signal_type = 'sell'
                    elif max_idx == 1:
                        return None  # Hold
                    else:
                        signal_type = 'buy'
                    
                    if confidence > 0.6:
                        return {
                            'type': signal_type,
                            'strength': confidence,
                            'confidence': confidence,
                            'model': model_name,
                            'algorithm': model_info.algorithm if model_info else 'neural_network',
                            'raw_prediction': prediction.tolist()
                        }
            
            return None
            
        except Exception as e:
            logger.error(f"Error making prediction with model {model_name}: {e}")
            return None

    def _map_prediction_to_signal(self, prediction: Any) -> Optional[str]:
        """Map model prediction to trading signal"""
        if isinstance(prediction, str):
            prediction_lower = prediction.lower()
            if prediction_lower in ['buy', 'long', '1', 'up', 'bullish']:
                return 'buy'
            elif prediction_lower in ['sell', 'short', '0', '-1', 'down', 'bearish']:
                return 'sell'
        elif isinstance(prediction, (int, float)):
            if prediction > 0.5:
                return 'buy'
            elif prediction < -0.5:
                return 'sell'
        
        return None

    def _aggregate_signals(self, signals: Dict[str, Dict[str, Any]]) -> Optional[Dict[str, Any]]:
        """Aggregate signals from multiple models"""
        try:
            if not signals:
                return None
            
            buy_votes = []
            sell_votes = []
            total_confidence = 0
            model_count = len(signals)
            
            for model_name, signal in signals.items():
                signal_type = signal.get('type')
                strength = signal.get('strength', 0)
                confidence = signal.get('confidence', 0)
                
                # Weight by confidence
                weighted_strength = strength * confidence
                
                if signal_type == 'buy':
                    buy_votes.append(weighted_strength)
                elif signal_type == 'sell':
                    sell_votes.append(weighted_strength)
                
                total_confidence += confidence
            
            # Calculate aggregated strengths
            buy_strength = np.mean(buy_votes) if buy_votes else 0
            sell_strength = np.mean(sell_votes) if sell_votes else 0
            avg_confidence = total_confidence / model_count
            
            # Determine final signal
            if buy_strength > sell_strength and buy_strength > 0.4:
                final_type = 'buy'
                final_strength = buy_strength
            elif sell_strength > buy_strength and sell_strength > 0.4:
                final_type = 'sell'
                final_strength = sell_strength
            else:
                return None  # No clear consensus
            
            return {
                'type': final_type,
                'strength': float(final_strength),
                'confidence': float(avg_confidence),
                'models_count': model_count,
                'buy_votes': len(buy_votes),
                'sell_votes': len(sell_votes),
                'individual_signals': signals,
                'timestamp': datetime.now().isoformat(),
                'source': 'ml_aggregated'
            }
            
        except Exception as e:
            logger.error(f"Error aggregating signals: {e}")
            return None

    def train_model(self, training_data: pd.DataFrame, model_config: Dict[str, Any]) -> TrainingResult:
        """Train a new ML model"""
        start_time = time.time()
        
        try:
            model_name = model_config.get('name', f'model_{int(time.time())}')
            algorithm = model_config.get('algorithm', 'random_forest')
            target_column = model_config.get('target_column', 'signal')
            
            # Validate data
            if target_column not in training_data.columns:
                return TrainingResult(
                    model_name=model_name,
                    success=False,
                    metrics={},
                    training_time=0,
                    model_path="",
                    error_message=f"Target column '{target_column}' not found in data"
                )
            
            # Prepare features and target
            feature_columns = [col for col in training_data.columns if col != target_column]
            X = training_data[feature_columns]
            y = training_data[target_column]
            
            # Handle missing values
            X = X.fillna(0)
            y = y.fillna(0)
            
            # Split data
            test_size = model_config.get('test_size', 0.2)
            random_state = model_config.get('random_state', 42)
            
            X_train, X_test, y_train, y_test = train_test_split(
                X, y, test_size=test_size, random_state=random_state, 
                stratify=y if y.nunique() > 1 else None
            )
            
            # Scale features
            scaler_type = model_config.get('scaler', 'standard')
            if scaler_type == 'standard':
                scaler = StandardScaler()
            elif scaler_type == 'minmax':
                scaler = MinMaxScaler()
            elif scaler_type == 'robust':
                scaler = RobustScaler()
            else:
                scaler = StandardScaler()
            
            X_train_scaled = scaler.fit_transform(X_train)
            X_test_scaled = scaler.transform(X_test)
            
            # Create model
            if algorithm in self.supported_sklearn_models:
                model_class = self.supported_sklearn_models[algorithm]
                model_params = model_config.get('parameters', {})
                model = model_class(**model_params)
            else:
                return TrainingResult(
                    model_name=model_name,
                    success=False,
                    metrics={},
                    training_time=0,
                    model_path="",
                    error_message=f"Unsupported algorithm: {algorithm}"
                )
            
            # Train model
            model.fit(X_train_scaled, y_train)
            
            # Make predictions
            y_pred = model.predict(X_test_scaled)
            
            # Calculate metrics
            metrics = {}
            if y.nunique() > 2:  # Multi-class classification
                metrics['accuracy'] = float(accuracy_score(y_test, y_pred))
                metrics['precision'] = float(precision_score(y_test, y_pred, average='weighted'))
                metrics['recall'] = float(recall_score(y_test, y_pred, average='weighted'))
                metrics['f1_score'] = float(f1_score(y_test, y_pred, average='weighted'))
            elif y.nunique() == 2:  # Binary classification
                metrics['accuracy'] = float(accuracy_score(y_test, y_pred))
                metrics['precision'] = float(precision_score(y_test, y_pred, average='binary'))
                metrics['recall'] = float(recall_score(y_test, y_pred, average='binary'))
                metrics['f1_score'] = float(f1_score(y_test, y_pred, average='binary'))
            else:  # Regression
                from sklearn.metrics import mean_squared_error, r2_score
                metrics['mse'] = float(mean_squared_error(y_test, y_pred))
                metrics['r2_score'] = float(r2_score(y_test, y_pred))
            
            # Save model
            model_info = {
                'algorithm': algorithm,
                'version': '1.0.0',
                'accuracy': metrics.get('accuracy', metrics.get('r2_score', 0)),
                'features': feature_columns,
                'target': target_column,
                'parameters': model_config.get('parameters', {}),
                'description': model_config.get('description', f'Trained {algorithm} model'),
                'training_samples': len(X_train),
                'test_samples': len(X_test),
                'scaler_type': scaler_type
            }
            
            save_result = self.save_model(model, model_name, model_info, scaler)
            
            training_time = time.time() - start_time
            
            if save_result.get('success'):
                return TrainingResult(
                    model_name=model_name,
                    success=True,
                    metrics=metrics,
                    training_time=training_time,
                    model_path=save_result['model_path']
                )
            else:
                return TrainingResult(
                    model_name=model_name,
                    success=False,
                    metrics={},
                    training_time=training_time,
                    model_path="",
                    error_message=save_result.get('error', 'Unknown error saving model')
                )
            
        except Exception as e:
            training_time = time.time() - start_time
            logger.error(f"Error training model: {e}")
            return TrainingResult(
                model_name=model_name,
                success=False,
                metrics={},
                training_time=training_time,
                model_path="",
                error_message=str(e)
            )

    def get_models_list(self) -> List[Dict[str, Any]]:
        """Get list of all loaded models with their information"""
        models_list = []
        
        for model_name, model_info in self.model_info.items():
            models_list.append({
                'name': model_info.name,
                'type': model_info.type,
                'algorithm': model_info.algorithm,
                'version': model_info.version,
                'created_at': model_info.created_at.isoformat(),
                'accuracy': model_info.accuracy,
                'features_count': len(model_info.features) if model_info.features else 0,
                'target': model_info.target,
                'file_size': model_info.file_size,
                'description': model_info.description,
                'has_scaler': model_name in self.model_scalers,
                'is_loaded': model_name in self.loaded_models
            })
        
        return models_list

    def get_model_details(self, model_name: str) -> Dict[str, Any]:
        """Get detailed information about a specific model"""
        if model_name not in self.model_info:
            return {'error': f'Model {model_name} not found'}
        
        model_info = self.model_info[model_name]
        
        return {
            'name': model_info.name,
            'type': model_info.type,
            'algorithm': model_info.algorithm,
            'version': model_info.version,
            'created_at': model_info.created_at.isoformat(),
            'accuracy': model_info.accuracy,
            'features': model_info.features,
            'target': model_info.target,
            'parameters': model_info.parameters,
            'file_size': model_info.file_size,
            'description': model_info.description,
            'has_scaler': model_name in self.model_scalers,
            'is_loaded': model_name in self.loaded_models
        }

    def _update_model_description(self, model_name: str, description: str):
        """Update model description"""
        try:
            if model_name in self.model_info:
                self.model_info[model_name].description = description
                
                # Update config file
                config_path = self.configs_dir / f"{model_name}_config.json"
                if config_path.exists():
                    with open(config_path, 'r') as f:
                        config = json.load(f)
                    config['description'] = description
                    with open(config_path, 'w') as f:
                        json.dump(config, f, indent=2, default=str)
        except Exception as e:
            logger.error(f"Error updating model description: {e}")