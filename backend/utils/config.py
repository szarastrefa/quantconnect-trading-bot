#!/usr/bin/env python3
"""
Configuration Management Module for QuantConnect Trading Bot
Centralized configuration handling with environment variable support
"""

import os
import json
import logging
from typing import Any, Dict, Optional, Union
from pathlib import Path
from dataclasses import dataclass, field

logger = logging.getLogger(__name__)

@dataclass
class DatabaseConfig:
    """Database configuration"""
    url: str = field(default_factory=lambda: os.getenv('DATABASE_URL', 'postgresql://postgres:trading123@localhost:5432/trading_bot'))
    pool_size: int = field(default_factory=lambda: int(os.getenv('DB_POOL_SIZE', '10')))
    max_overflow: int = field(default_factory=lambda: int(os.getenv('DB_MAX_OVERFLOW', '20')))
    echo: bool = field(default_factory=lambda: os.getenv('DB_ECHO', 'false').lower() == 'true')

@dataclass
class RedisConfig:
    """Redis configuration"""
    url: str = field(default_factory=lambda: os.getenv('REDIS_URL', 'redis://localhost:6379/0'))
    decode_responses: bool = True
    socket_keepalive: bool = True
    socket_keepalive_options: Dict[str, int] = field(default_factory=lambda: {})
    health_check_interval: int = 30

@dataclass
class FlaskConfig:
    """Flask application configuration"""
    secret_key: str = field(default_factory=lambda: os.getenv('SECRET_KEY', 'dev-secret-key-change-in-production'))
    debug: bool = field(default_factory=lambda: os.getenv('FLASK_DEBUG', 'false').lower() == 'true')
    testing: bool = False
    sqlalchemy_track_modifications: bool = False
    sqlalchemy_echo: bool = field(default_factory=lambda: os.getenv('DB_ECHO', 'false').lower() == 'true')
    cors_origins: str = field(default_factory=lambda: os.getenv('CORS_ORIGINS', '*'))
    max_content_length: int = field(default_factory=lambda: int(os.getenv('MAX_CONTENT_LENGTH', str(16 * 1024 * 1024))))  # 16MB

@dataclass
class QuantConnectConfig:
    """QuantConnect Lean configuration"""
    user_id: str = field(default_factory=lambda: os.getenv('QC_USER_ID', ''))
    api_token: str = field(default_factory=lambda: os.getenv('QC_API_TOKEN', ''))
    environment: str = field(default_factory=lambda: os.getenv('QC_ENVIRONMENT', 'backtesting'))
    data_folder: str = field(default_factory=lambda: os.getenv('QC_DATA_FOLDER', '/app/lean/data'))
    algorithm_folder: str = field(default_factory=lambda: os.getenv('QC_ALGORITHM_FOLDER', '/app/lean/algorithms'))
    results_folder: str = field(default_factory=lambda: os.getenv('QC_RESULTS_FOLDER', '/app/lean/results'))

@dataclass
class MLConfig:
    """Machine Learning configuration"""
    models_dir: str = field(default_factory=lambda: os.getenv('MODELS_DIR', '/app/models/trained_models'))
    configs_dir: str = field(default_factory=lambda: os.getenv('CONFIGS_DIR', '/app/models/model_configs'))
    max_model_size: int = field(default_factory=lambda: int(os.getenv('MAX_MODEL_SIZE', str(100 * 1024 * 1024))))  # 100MB
    supported_formats: list = field(default_factory=lambda: ['.pkl', '.joblib', '.h5'])
    default_test_size: float = 0.2
    default_random_state: int = 42
    feature_importance_threshold: float = 0.01

@dataclass
class TradingConfig:
    """Trading configuration"""
    max_daily_loss: float = field(default_factory=lambda: float(os.getenv('MAX_DAILY_LOSS', '0.05')))  # 5%
    max_position_size: float = field(default_factory=lambda: float(os.getenv('MAX_POSITION_SIZE', '0.1')))  # 10%
    max_correlation: float = field(default_factory=lambda: float(os.getenv('MAX_CORRELATION', '0.7')))
    default_leverage: int = field(default_factory=lambda: int(os.getenv('DEFAULT_LEVERAGE', '1')))
    signal_confidence_threshold: float = field(default_factory=lambda: float(os.getenv('SIGNAL_CONFIDENCE_THRESHOLD', '0.6')))
    max_concurrent_trades: int = field(default_factory=lambda: int(os.getenv('MAX_CONCURRENT_TRADES', '10')))
    trade_timeout_seconds: int = field(default_factory=lambda: int(os.getenv('TRADE_TIMEOUT_SECONDS', '300')))

@dataclass
class LoggingConfig:
    """Logging configuration"""
    level: str = field(default_factory=lambda: os.getenv('LOG_LEVEL', 'INFO'))
    format: str = field(default_factory=lambda: os.getenv('LOG_FORMAT', '%(asctime)s - %(name)s - %(levelname)s - %(message)s'))
    file_path: Optional[str] = field(default_factory=lambda: os.getenv('LOG_FILE_PATH'))
    max_bytes: int = field(default_factory=lambda: int(os.getenv('LOG_MAX_BYTES', str(10 * 1024 * 1024))))  # 10MB
    backup_count: int = field(default_factory=lambda: int(os.getenv('LOG_BACKUP_COUNT', '5')))
    enable_json_logging: bool = field(default_factory=lambda: os.getenv('ENABLE_JSON_LOGGING', 'false').lower() == 'true')

@dataclass
class SecurityConfig:
    """Security configuration"""
    jwt_secret_key: str = field(default_factory=lambda: os.getenv('JWT_SECRET_KEY', 'jwt-secret-change-in-production'))
    jwt_access_token_expires: int = field(default_factory=lambda: int(os.getenv('JWT_ACCESS_TOKEN_EXPIRES', '3600')))  # 1 hour
    jwt_refresh_token_expires: int = field(default_factory=lambda: int(os.getenv('JWT_REFRESH_TOKEN_EXPIRES', '2592000')))  # 30 days
    bcrypt_log_rounds: int = field(default_factory=lambda: int(os.getenv('BCRYPT_LOG_ROUNDS', '12')))
    rate_limit_per_minute: int = field(default_factory=lambda: int(os.getenv('RATE_LIMIT_PER_MINUTE', '60')))
    enable_cors: bool = field(default_factory=lambda: os.getenv('ENABLE_CORS', 'true').lower() == 'true')
    trusted_hosts: list = field(default_factory=lambda: os.getenv('TRUSTED_HOSTS', 'localhost,127.0.0.1').split(','))

@dataclass
class MonitoringConfig:
    """Monitoring and alerting configuration"""
    enable_health_check: bool = field(default_factory=lambda: os.getenv('ENABLE_HEALTH_CHECK', 'true').lower() == 'true')
    health_check_interval: int = field(default_factory=lambda: int(os.getenv('HEALTH_CHECK_INTERVAL', '30')))
    alert_email: Optional[str] = field(default_factory=lambda: os.getenv('ALERT_EMAIL'))
    slack_webhook: Optional[str] = field(default_factory=lambda: os.getenv('SLACK_WEBHOOK'))
    telegram_bot_token: Optional[str] = field(default_factory=lambda: os.getenv('TELEGRAM_BOT_TOKEN'))
    telegram_chat_id: Optional[str] = field(default_factory=lambda: os.getenv('TELEGRAM_CHAT_ID'))
    metrics_retention_days: int = field(default_factory=lambda: int(os.getenv('METRICS_RETENTION_DAYS', '30')))

class Config:
    """Main configuration class that aggregates all configuration sections"""
    
    def __init__(self, config_file: Optional[str] = None):
        self.environment = os.getenv('ENVIRONMENT', 'development')
        self.config_file = config_file
        
        # Initialize configuration sections
        self.database = DatabaseConfig()
        self.redis = RedisConfig()
        self.flask = FlaskConfig()
        self.quantconnect = QuantConnectConfig()
        self.ml = MLConfig()
        self.trading = TradingConfig()
        self.logging = LoggingConfig()
        self.security = SecurityConfig()
        self.monitoring = MonitoringConfig()
        
        # Load additional configuration from file if provided
        if config_file:
            self.load_from_file(config_file)
        
        # Apply environment-specific overrides
        self._apply_environment_overrides()
        
        logger.info(f"Configuration initialized for environment: {self.environment}")
    
    def load_from_file(self, config_file: str) -> None:
        """Load configuration from JSON file"""
        try:
            config_path = Path(config_file)
            if not config_path.exists():
                logger.warning(f"Configuration file {config_file} not found")
                return
            
            with open(config_path, 'r') as f:
                file_config = json.load(f)
            
            # Update configuration sections with file data
            for section_name, section_data in file_config.items():
                if hasattr(self, section_name):
                    section_obj = getattr(self, section_name)
                    for key, value in section_data.items():
                        if hasattr(section_obj, key):
                            setattr(section_obj, key, value)
            
            logger.info(f"Configuration loaded from {config_file}")
            
        except Exception as e:
            logger.error(f"Error loading configuration from {config_file}: {e}")
    
    def _apply_environment_overrides(self) -> None:
        """Apply environment-specific configuration overrides"""
        if self.environment == 'production':
            self._apply_production_config()
        elif self.environment == 'testing':
            self._apply_testing_config()
        elif self.environment == 'development':
            self._apply_development_config()
    
    def _apply_production_config(self) -> None:
        """Apply production-specific configuration"""
        self.flask.debug = False
        self.flask.testing = False
        self.database.echo = False
        self.logging.level = 'WARNING'
        self.security.jwt_access_token_expires = 1800  # 30 minutes
        logger.info("Applied production configuration overrides")
    
    def _apply_testing_config(self) -> None:
        """Apply testing-specific configuration"""
        self.flask.testing = True
        self.database.url = os.getenv('TEST_DATABASE_URL', 'sqlite:///test_trading_bot.db')
        self.redis.url = os.getenv('TEST_REDIS_URL', 'redis://localhost:6379/15')
        self.logging.level = 'DEBUG'
        self.ml.models_dir = '/tmp/test_models'
        logger.info("Applied testing configuration overrides")
    
    def _apply_development_config(self) -> None:
        """Apply development-specific configuration"""
        self.flask.debug = True
        self.database.echo = True
        self.logging.level = 'DEBUG'
        self.security.rate_limit_per_minute = 1000  # Higher limit for development
        logger.info("Applied development configuration overrides")
    
    def get(self, key: str, default: Any = None) -> Any:
        """Get configuration value using dot notation"""
        try:
            keys = key.split('.')
            value = self
            
            for k in keys:
                if hasattr(value, k):
                    value = getattr(value, k)
                else:
                    return default
            
            return value
        except Exception:
            return default
    
    def set(self, key: str, value: Any) -> None:
        """Set configuration value using dot notation"""
        try:
            keys = key.split('.')
            obj = self
            
            for k in keys[:-1]:
                if hasattr(obj, k):
                    obj = getattr(obj, k)
                else:
                    return
            
            if hasattr(obj, keys[-1]):
                setattr(obj, keys[-1], value)
        except Exception as e:
            logger.error(f"Error setting configuration key {key}: {e}")
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert configuration to dictionary"""
        result = {}
        
        for attr_name in dir(self):
            if not attr_name.startswith('_') and attr_name not in ['load_from_file', 'get', 'set', 'to_dict']:
                attr_value = getattr(self, attr_name)
                if hasattr(attr_value, '__dict__'):
                    result[attr_name] = attr_value.__dict__
                else:
                    result[attr_name] = attr_value
        
        return result
    
    def validate(self) -> list:
        """Validate configuration and return list of issues"""
        issues = []
        
        # Validate database configuration
        if not self.database.url:
            issues.append("Database URL is not configured")
        
        # Validate Redis configuration
        if not self.redis.url:
            issues.append("Redis URL is not configured")
        
        # Validate Flask secret key
        if self.flask.secret_key == 'dev-secret-key-change-in-production' and self.environment == 'production':
            issues.append("Flask secret key should be changed in production")
        
        # Validate JWT secret key
        if self.security.jwt_secret_key == 'jwt-secret-change-in-production' and self.environment == 'production':
            issues.append("JWT secret key should be changed in production")
        
        # Validate directories exist
        directories_to_check = [
            self.ml.models_dir,
            self.ml.configs_dir,
            self.quantconnect.data_folder,
            self.quantconnect.algorithm_folder,
            self.quantconnect.results_folder
        ]
        
        for directory in directories_to_check:
            if not Path(directory).exists():
                try:
                    Path(directory).mkdir(parents=True, exist_ok=True)
                    logger.info(f"Created directory: {directory}")
                except Exception as e:
                    issues.append(f"Cannot create directory {directory}: {e}")
        
        # Validate trading parameters
        if not (0 < self.trading.max_daily_loss <= 1):
            issues.append("Max daily loss should be between 0 and 1 (0-100%)")
        
        if not (0 < self.trading.max_position_size <= 1):
            issues.append("Max position size should be between 0 and 1 (0-100%)")
        
        if not (0 < self.trading.signal_confidence_threshold <= 1):
            issues.append("Signal confidence threshold should be between 0 and 1")
        
        return issues
    
    def print_summary(self) -> None:
        """Print configuration summary"""
        print("\n" + "="*60)
        print("QUANTCONNECT TRADING BOT - CONFIGURATION SUMMARY")
        print("="*60)
        print(f"Environment: {self.environment}")
        print(f"Debug Mode: {self.flask.debug}")
        print(f"Database: {self.database.url.split('@')[-1] if '@' in self.database.url else 'Not configured'}")
        print(f"Redis: {self.redis.url}")
        print(f"Models Directory: {self.ml.models_dir}")
        print(f"Max Daily Loss: {self.trading.max_daily_loss:.1%}")
        print(f"Max Position Size: {self.trading.max_position_size:.1%}")
        print(f"Logging Level: {self.logging.level}")
        
        if self.quantconnect.user_id:
            print(f"QuantConnect User ID: {self.quantconnect.user_id[:8]}...")
        else:
            print("QuantConnect: Not configured")
        
        print("="*60)
        
        # Validate and show issues
        issues = self.validate()
        if issues:
            print("\n⚠️  CONFIGURATION ISSUES:")
            for i, issue in enumerate(issues, 1):
                print(f"   {i}. {issue}")
        else:
            print("\n✅ Configuration validation passed")
        
        print()

# Global configuration instance
config = Config()

def get_config() -> Config:
    """Get global configuration instance"""
    return config

def init_config(config_file: Optional[str] = None) -> Config:
    """Initialize configuration with optional config file"""
    global config
    config = Config(config_file)
    return config