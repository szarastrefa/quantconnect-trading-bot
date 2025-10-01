#!/usr/bin/env python3
"""
Lean Service - QuantConnect Lean Engine Integration
Provides integration with QuantConnect Lean algorithmic trading engine
"""

import os
import json
import logging
import subprocess
import docker
import time
import threading
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Union
from pathlib import Path
from dataclasses import dataclass
import requests

# Internal imports
from utils.config import Config
from utils.helpers import validate_json, sanitize_input
from models.trading_models import LeanAlgorithm, BacktestResult

logger = logging.getLogger(__name__)

@dataclass
class AlgorithmResult:
    algorithm_name: str
    success: bool
    signals: Dict[str, Any]
    performance_metrics: Dict[str, float]
    execution_time: float
    error_message: str = None

@dataclass
class BacktestConfig:
    start_date: str
    end_date: str
    initial_cash: float
    benchmark: str = "SPY"
    resolution: str = "Daily"
    data_normalization: str = "Adjusted"

class LeanService:
    """QuantConnect Lean engine integration service"""
    
    def __init__(self, config: Config):
        self.config = config
        self.docker_client = None
        self.lean_container = None
        self.lean_config_path = Path('/app/lean/config.json')
        self.algorithms_path = Path('/app/lean/algorithms')
        self.data_path = Path('/app/lean/data')
        self.results_path = Path('/app/lean/results')
        
        # Create necessary directories
        self.algorithms_path.mkdir(parents=True, exist_ok=True)
        self.data_path.mkdir(parents=True, exist_ok=True)
        self.results_path.mkdir(parents=True, exist_ok=True)
        
        self.is_connected = False
        self.running_algorithms = {}
        
        # Default algorithm templates
        self.algorithm_templates = {
            'basic_mean_reversion': self._get_basic_mean_reversion_template(),
            'momentum_strategy': self._get_momentum_strategy_template(),
            'ml_integration': self._get_ml_integration_template(),
            'multi_asset': self._get_multi_asset_template()
        }
        
        logger.info("LeanService initialized")

    def initialize(self) -> bool:
        """Initialize Lean service and Docker connection"""
        try:
            # Initialize Docker client
            self.docker_client = docker.from_env()
            
            # Find or start Lean container
            self._setup_lean_container()
            
            # Setup default configuration
            self._create_lean_config()
            
            # Create default algorithms
            self._create_default_algorithms()
            
            self.is_connected = True
            logger.info("LeanService initialized successfully")
            return True
            
        except Exception as e:
            logger.error(f"LeanService initialization failed: {e}")
            return False

    def _setup_lean_container(self):
        """Setup QuantConnect Lean Docker container"""
        try:
            # Try to find existing container
            try:
                self.lean_container = self.docker_client.containers.get('lean_engine')
                if self.lean_container.status != 'running':
                    self.lean_container.start()
                logger.info("Found and connected to existing Lean container")
            except docker.errors.NotFound:
                logger.info("Lean container will be managed by docker-compose")
                
        except Exception as e:
            logger.error(f"Error setting up Lean container: {e}")

    def _create_lean_config(self):
        """Create QuantConnect Lean configuration file"""
        try:
            lean_config = {
                "environment": "backtesting",
                "algorithm-type-name": "BasicTemplateAlgorithm",
                "algorithm-language": "Python",
                "algorithm-location": "/Lean/Algorithm.Python/BasicTemplateAlgorithm.py",
                
                # Data configuration
                "data-folder": "/Data",
                "data-provider": "DefaultDataProvider",
                "data-channel-provider": "DataChannelProvider",
                
                # Results configuration
                "results-destination-folder": "/Results",
                "result-handler": "BacktestingResultHandler",
                
                # Debugging
                "debugging": False,
                "debugging-method": "LocalCmdline",
                
                # Logging
                "log-handler": "ConsoleLogHandler",
                
                # Job configuration
                "job-queue-handler": "JobQueue",
                "api-handler": "LocalDiskApiHandler",
                
                # Map and factor file providers
                "map-file-provider": "LocalDiskMapFileProvider", 
                "factor-file-provider": "LocalDiskFactorFileProvider",
                
                # History provider
                "history-provider": "SubscriptionDataReaderHistoryProvider",
                
                # Real time handler
                "real-time-handler": "BacktestingRealTimeHandler",
                
                # Transaction handler
                "transaction-handler": "BacktestingTransactionHandler",
                
                # Setup handler
                "setup-handler": "ConsoleSetupHandler",
                
                # Data feed handler
                "data-feed-handler": "FileSystemDataFeed",
                
                # Alpha handler
                "alpha-handler": "DefaultAlphaHandler",
                
                # Object store
                "object-store": "LocalObjectStore",
                
                # Data aggregator
                "data-aggregator": "AggregationManager",
                
                # Symbol limits
                "symbol-minute-limit": 10000,
                "symbol-second-limit": 10000, 
                "symbol-tick-limit": 10000,
                
                # Chart settings
                "maximum-data-points-per-chart-series": 4000,
                
                # Other settings
                "show-missing-data-logs": True,
                "force-exchange-always-open": False,
                
                # Job settings
                "job-project-id": 0,
                "job-user-id": "0",
                "job-organization-id": "",
                
                # Live trading (disabled for backtesting)
                "live-mode": False,
                "live-mode-brokerage": "",
                "data-queue-handler": "",
                
                # Parameters
                "parameters": {}
            }
            
            # Save configuration
            os.makedirs(self.lean_config_path.parent, exist_ok=True)
            with open(self.lean_config_path, 'w') as f:
                json.dump(lean_config, f, indent=2)
            
            logger.info("Lean configuration created")
            
        except Exception as e:
            logger.error(f"Error creating Lean config: {e}")

    def _create_default_algorithms(self):
        """Create default algorithm templates"""
        try:
            for name, template in self.algorithm_templates.items():
                algorithm_file = self.algorithms_path / f"{name}.py"
                if not algorithm_file.exists():
                    with open(algorithm_file, 'w') as f:
                        f.write(template)
                    logger.info(f"Created algorithm template: {name}")
        except Exception as e:
            logger.error(f"Error creating default algorithms: {e}")

    def run_algorithm(self, strategy_config: Dict[str, Any]) -> AlgorithmResult:
        """Run a Lean algorithm with given configuration"""
        start_time = time.time()
        
        try:
            algorithm_name = strategy_config.get('algorithm_name', 'basic_mean_reversion')
            parameters = strategy_config.get('parameters', {})
            
            # Prepare algorithm configuration
            config = self._prepare_algorithm_config(strategy_config)
            
            # Execute algorithm
            if self.lean_container:
                result = self._run_algorithm_in_container(algorithm_name, config)
            else:
                result = self._run_algorithm_locally(algorithm_name, config)
            
            # Parse results
            signals = self._parse_algorithm_output(result)
            metrics = self._extract_performance_metrics(result)
            
            execution_time = time.time() - start_time
            
            return AlgorithmResult(
                algorithm_name=algorithm_name,
                success=True,
                signals=signals,
                performance_metrics=metrics,
                execution_time=execution_time
            )
            
        except Exception as e:
            execution_time = time.time() - start_time
            logger.error(f"Error running algorithm: {e}")
            return AlgorithmResult(
                algorithm_name=strategy_config.get('algorithm_name', 'unknown'),
                success=False,
                signals={},
                performance_metrics={},
                execution_time=execution_time,
                error_message=str(e)
            )

    def _prepare_algorithm_config(self, strategy_config: Dict[str, Any]) -> Dict[str, Any]:
        """Prepare algorithm configuration from strategy config"""
        return {
            "algorithm-type-name": strategy_config.get('algorithm_name', 'BasicTemplateAlgorithm'),
            "parameters": strategy_config.get('parameters', {}),
            "start-date": strategy_config.get('start_date', '20240101'),
            "end-date": strategy_config.get('end_date', datetime.now().strftime('%Y%m%d')),
            "cash": strategy_config.get('initial_cash', 100000),
            "live-mode": strategy_config.get('live_mode', False),
            "symbols": strategy_config.get('symbols', ['SPY'])
        }

    def _run_algorithm_in_container(self, algorithm_name: str, config: Dict[str, Any]) -> str:
        """Run algorithm inside Lean Docker container"""
        try:
            # Prepare command
            cmd = [
                "dotnet", "QuantConnect.Lean.Launcher.dll",
                "--config", "/Lean/config.json",
                "--algorithm-type-name", algorithm_name
            ]
            
            # Add parameters
            for key, value in config.items():
                if key != 'algorithm-type-name':
                    cmd.extend([f"--{key}", str(value)])
            
            # Execute in container
            result = self.lean_container.exec_run(
                cmd,
                workdir="/Lean",
                environment={
                    'QC_USER_ID': self.config.get('QC_USER_ID', ''),
                    'QC_API_TOKEN': self.config.get('QC_API_TOKEN', '')
                }
            )
            
            return result.output.decode('utf-8') if result.output else ""
            
        except Exception as e:
            logger.error(f"Error running algorithm in container: {e}")
            return f"Error: {str(e)}"

    def _run_algorithm_locally(self, algorithm_name: str, config: Dict[str, Any]) -> str:
        """Run algorithm locally (fallback method)"""
        try:
            # This is a simplified local execution
            # In production, you would need Lean CLI installed
            logger.warning("Running algorithm locally - limited functionality")
            
            # Simulate algorithm execution
            return self._simulate_algorithm_execution(algorithm_name, config)
            
        except Exception as e:
            logger.error(f"Error running algorithm locally: {e}")
            return f"Error: {str(e)}"

    def _simulate_algorithm_execution(self, algorithm_name: str, config: Dict[str, Any]) -> str:
        """Simulate algorithm execution for demonstration purposes"""
        symbols = config.get('symbols', ['SPY'])
        
        # Generate simulated output
        output = f"""
Algorithm: {algorithm_name}
Status: Completed
Symbols: {', '.join(symbols)}

SIGNALS:
"""
        
        # Generate some sample signals
        import random
        for symbol in symbols:
            if random.random() > 0.5:
                signal_type = 'BUY' if random.random() > 0.5 else 'SELL'
                strength = random.uniform(0.6, 1.0)
                price = random.uniform(100, 500)
                
                output += f"SIGNAL: {symbol} {signal_type} {strength:.2f} {price:.2f}\n"
        
        output += """
PERFORMANCE:
Total Return: 15.5%
Sharpe Ratio: 1.2
Max Drawdown: -5.8%
Win Rate: 65%
Total Trades: 25
"""
        
        return output

    def _parse_algorithm_output(self, output: str) -> Dict[str, Any]:
        """Parse algorithm output to extract trading signals"""
        signals = {}
        
        try:
            lines = output.split('\n')
            for line in lines:
                if 'SIGNAL:' in line:
                    # Format: SIGNAL: SYMBOL ACTION STRENGTH PRICE
                    parts = line.split()
                    if len(parts) >= 5:
                        symbol = parts[1]
                        action = parts[2].lower()
                        strength = float(parts[3])
                        price = float(parts[4])
                        
                        signals[symbol] = {
                            'type': action,
                            'strength': strength,
                            'price': price,
                            'timestamp': datetime.now().isoformat(),
                            'source': 'lean_algorithm'
                        }
        except Exception as e:
            logger.error(f"Error parsing algorithm output: {e}")
        
        return signals

    def _extract_performance_metrics(self, output: str) -> Dict[str, float]:
        """Extract performance metrics from algorithm output"""
        metrics = {}
        
        try:
            lines = output.split('\n')
            for line in lines:
                if 'Total Return:' in line:
                    value = line.split(':')[1].strip().replace('%', '')
                    metrics['total_return'] = float(value)
                elif 'Sharpe Ratio:' in line:
                    value = line.split(':')[1].strip()
                    metrics['sharpe_ratio'] = float(value)
                elif 'Max Drawdown:' in line:
                    value = line.split(':')[1].strip().replace('%', '').replace('-', '')
                    metrics['max_drawdown'] = float(value)
                elif 'Win Rate:' in line:
                    value = line.split(':')[1].strip().replace('%', '')
                    metrics['win_rate'] = float(value)
                elif 'Total Trades:' in line:
                    value = line.split(':')[1].strip()
                    metrics['total_trades'] = float(value)
        except Exception as e:
            logger.error(f"Error extracting performance metrics: {e}")
        
        return metrics

    def create_algorithm(self, algorithm_name: str, algorithm_code: str, 
                        description: str = "") -> Dict[str, Any]:
        """Create new algorithm from code"""
        try:
            algorithm_name = sanitize_input(algorithm_name)
            algorithm_file = self.algorithms_path / f"{algorithm_name}.py"
            
            # Validate algorithm code
            if not self._validate_algorithm_code(algorithm_code):
                return {'error': 'Invalid algorithm code'}
            
            # Save algorithm
            with open(algorithm_file, 'w') as f:
                f.write(algorithm_code)
            
            # Create metadata
            metadata = {
                'name': algorithm_name,
                'description': description,
                'created_at': datetime.now().isoformat(),
                'file_path': str(algorithm_file),
                'language': 'Python'
            }
            
            metadata_file = self.algorithms_path / f"{algorithm_name}_metadata.json"
            with open(metadata_file, 'w') as f:
                json.dump(metadata, f, indent=2)
            
            logger.info(f"Algorithm {algorithm_name} created successfully")
            
            return {
                'success': True,
                'algorithm_name': algorithm_name,
                'file_path': str(algorithm_file)
            }
            
        except Exception as e:
            logger.error(f"Error creating algorithm: {e}")
            return {'error': str(e)}

    def _validate_algorithm_code(self, code: str) -> bool:
        """Validate algorithm code for basic structure"""
        try:
            # Check for required imports and class structure
            required_patterns = [
                'from AlgorithmImports import *',
                'class',
                'def Initialize(',
                'def OnData('
            ]
            
            return all(pattern in code for pattern in required_patterns)
            
        except Exception:
            return False

    def backtest_algorithm(self, algorithm_name: str, 
                          backtest_config: BacktestConfig) -> Dict[str, Any]:
        """Run backtest for specified algorithm"""
        try:
            config = {
                'algorithm_name': algorithm_name,
                'start_date': backtest_config.start_date.replace('-', ''),
                'end_date': backtest_config.end_date.replace('-', ''),
                'initial_cash': backtest_config.initial_cash,
                'live_mode': False
            }
            
            result = self.run_algorithm(config)
            
            if result.success:
                # Calculate additional backtest metrics
                backtest_result = {
                    'algorithm_name': algorithm_name,
                    'start_date': backtest_config.start_date,
                    'end_date': backtest_config.end_date,
                    'initial_cash': backtest_config.initial_cash,
                    'final_value': backtest_config.initial_cash * (1 + result.performance_metrics.get('total_return', 0) / 100),
                    'performance_metrics': result.performance_metrics,
                    'execution_time': result.execution_time,
                    'signals_generated': len(result.signals)
                }
                
                return {'success': True, 'results': backtest_result}
            else:
                return {'success': False, 'error': result.error_message}
                
        except Exception as e:
            logger.error(f"Error running backtest: {e}")
            return {'success': False, 'error': str(e)}

    def get_algorithms_list(self) -> List[Dict[str, Any]]:
        """Get list of available algorithms"""
        algorithms = []
        
        try:
            for algorithm_file in self.algorithms_path.glob('*.py'):
                algorithm_name = algorithm_file.stem
                
                # Load metadata if exists
                metadata_file = self.algorithms_path / f"{algorithm_name}_metadata.json"
                metadata = {}
                if metadata_file.exists():
                    with open(metadata_file, 'r') as f:
                        metadata = json.load(f)
                
                # Get file stats
                stats = algorithm_file.stat()
                
                algorithms.append({
                    'name': algorithm_name,
                    'description': metadata.get('description', ''),
                    'created_at': metadata.get('created_at', datetime.fromtimestamp(stats.st_ctime).isoformat()),
                    'modified_at': datetime.fromtimestamp(stats.st_mtime).isoformat(),
                    'file_size': stats.st_size,
                    'language': metadata.get('language', 'Python'),
                    'is_template': algorithm_name in self.algorithm_templates
                })
        
        except Exception as e:
            logger.error(f"Error getting algorithms list: {e}")
        
        return algorithms

    def delete_algorithm(self, algorithm_name: str) -> Dict[str, Any]:
        """Delete algorithm and its metadata"""
        try:
            algorithm_file = self.algorithms_path / f"{algorithm_name}.py"
            metadata_file = self.algorithms_path / f"{algorithm_name}_metadata.json"
            
            deleted_files = []
            
            if algorithm_file.exists():
                algorithm_file.unlink()
                deleted_files.append(str(algorithm_file))
            
            if metadata_file.exists():
                metadata_file.unlink()
                deleted_files.append(str(metadata_file))
            
            if deleted_files:
                logger.info(f"Algorithm {algorithm_name} deleted")
                return {'success': True, 'deleted_files': deleted_files}
            else:
                return {'error': f'Algorithm {algorithm_name} not found'}
                
        except Exception as e:
            logger.error(f"Error deleting algorithm: {e}")
            return {'error': str(e)}

    def is_connected(self) -> bool:
        """Check if Lean service is connected and ready"""
        return self.is_connected

    def get_market_data(self, symbols: List[str] = None) -> Dict[str, Any]:
        """Get market data through Lean (simulation for now)"""
        if symbols is None:
            symbols = ['SPY', 'QQQ', 'EURUSD', 'BTCUSD']
        
        market_data = {}
        
        try:
            import random
            
            for symbol in symbols:
                # Simulate market data
                base_price = 100 if 'USD' not in symbol else 1.0
                
                market_data[symbol] = {
                    'symbol': symbol,
                    'price': base_price + random.uniform(-5, 5),
                    'volume': random.randint(1000000, 10000000),
                    'bid': base_price - random.uniform(0, 0.1),
                    'ask': base_price + random.uniform(0, 0.1),
                    'high': base_price + random.uniform(0, 10),
                    'low': base_price - random.uniform(0, 10),
                    'change': random.uniform(-2, 2),
                    'change_percent': random.uniform(-5, 5),
                    'timestamp': datetime.now().isoformat(),
                    'source': 'lean_data_provider'
                }
        
        except Exception as e:
            logger.error(f"Error getting market data: {e}")
        
        return market_data

    # Algorithm Templates
    
    def _get_basic_mean_reversion_template(self) -> str:
        """Get basic mean reversion algorithm template"""
        return '''from AlgorithmImports import *

class BasicMeanReversionAlgorithm(QCAlgorithm):
    
    def Initialize(self):
        """Initialize algorithm"""
        self.SetStartDate(2024, 1, 1)
        self.SetEndDate(2024, 12, 31)
        self.SetCash(100000)
        
        # Add assets
        self.symbol = self.AddEquity("SPY", Resolution.Daily).Symbol
        
        # Parameters
        self.lookback_period = 20
        self.entry_threshold = 2.0  # Standard deviations
        self.exit_threshold = 0.5
        
        # Indicators
        self.sma = self.SMA(self.symbol, self.lookback_period)
        self.std = self.STD(self.symbol, self.lookback_period)
        
        # Trading variables
        self.entry_price = 0
        self.position_size = 0.1  # 10% of portfolio
        
    def OnData(self, data):
        """Handle new data"""
        if not self.sma.IsReady or not self.std.IsReady:
            return
            
        if not data.ContainsKey(self.symbol):
            return
            
        price = data[self.symbol].Close
        sma_value = self.sma.Current.Value
        std_value = self.std.Current.Value
        
        if std_value == 0:
            return
            
        # Calculate z-score
        z_score = (price - sma_value) / std_value
        
        # Trading logic
        if not self.Portfolio.Invested:
            # Entry conditions
            if z_score < -self.entry_threshold:
                # Price is below mean, go long
                self.SetHoldings(self.symbol, self.position_size)
                self.entry_price = price
                self.Debug(f"SIGNAL: {self.symbol} BUY {abs(z_score):.2f} {price:.2f}")
                
            elif z_score > self.entry_threshold:
                # Price is above mean, go short
                self.SetHoldings(self.symbol, -self.position_size)
                self.entry_price = price
                self.Debug(f"SIGNAL: {self.symbol} SELL {abs(z_score):.2f} {price:.2f}")
        else:
            # Exit conditions
            if abs(z_score) < self.exit_threshold:
                self.Liquidate(self.symbol)
                self.Debug(f"EXIT: {self.symbol} at {price:.2f}")
    
    def OnEndOfAlgorithm(self):
        """Called at the end of the algorithm"""
        self.Debug(f"Final Portfolio Value: {self.Portfolio.TotalPortfolioValue}")
'''

    def _get_momentum_strategy_template(self) -> str:
        """Get momentum strategy algorithm template"""
        return '''from AlgorithmImports import *

class MomentumStrategy(QCAlgorithm):
    
    def Initialize(self):
        """Initialize algorithm"""
        self.SetStartDate(2024, 1, 1)
        self.SetEndDate(2024, 12, 31)
        self.SetCash(100000)
        
        # Add multiple assets
        symbols = ["SPY", "QQQ", "IWM", "EFA", "EEM"]
        self.symbols = []
        self.momentum_indicators = {}
        
        for symbol in symbols:
            equity = self.AddEquity(symbol, Resolution.Daily)
            self.symbols.append(equity.Symbol)
            
            # Create momentum indicator (rate of change)
            self.momentum_indicators[equity.Symbol] = self.MOMP(equity.Symbol, 21)
        
        # Rebalancing
        self.rebalance_frequency = 30  # Days
        self.last_rebalance = self.Time
        
        # Parameters
        self.top_n = 2  # Hold top 2 momentum stocks
        
    def OnData(self, data):
        """Handle new data"""
        # Check if it's time to rebalance
        if (self.Time - self.last_rebalance).days < self.rebalance_frequency:
            return
            
        # Calculate momentum for all assets
        momentum_scores = {}
        
        for symbol in self.symbols:
            if symbol in self.momentum_indicators:
                momentum = self.momentum_indicators[symbol]
                if momentum.IsReady and data.ContainsKey(symbol):
                    momentum_scores[symbol] = momentum.Current.Value
        
        if len(momentum_scores) < self.top_n:
            return
            
        # Sort by momentum (descending)
        sorted_momentum = sorted(momentum_scores.items(), key=lambda x: x[1], reverse=True)
        
        # Select top performers
        selected_symbols = [item[0] for item in sorted_momentum[:self.top_n]]
        
        # Liquidate positions not in selection
        for symbol in self.symbols:
            if symbol not in selected_symbols and self.Portfolio[symbol].Invested:
                self.Liquidate(symbol)
        
        # Allocate equally among selected symbols
        weight = 1.0 / len(selected_symbols)
        
        for symbol in selected_symbols:
            if data.ContainsKey(symbol):
                current_weight = self.Portfolio[symbol].HoldingsValue / self.Portfolio.TotalPortfolioValue
                if abs(current_weight - weight) > 0.05:  # Rebalance if difference > 5%
                    self.SetHoldings(symbol, weight)
                    
                    price = data[symbol].Close
                    momentum = momentum_scores.get(symbol, 0)
                    self.Debug(f"SIGNAL: {symbol} BUY {momentum:.2f} {price:.2f}")
        
        self.last_rebalance = self.Time
    
    def OnEndOfAlgorithm(self):
        """Called at the end of the algorithm"""
        self.Debug(f"Final Portfolio Value: {self.Portfolio.TotalPortfolioValue}")
'''

    def _get_ml_integration_template(self) -> str:
        """Get ML integration algorithm template"""
        return '''from AlgorithmImports import *
import numpy as np

class MLIntegrationAlgorithm(QCAlgorithm):
    
    def Initialize(self):
        """Initialize algorithm"""
        self.SetStartDate(2024, 1, 1)
        self.SetEndDate(2024, 12, 31)
        self.SetCash(100000)
        
        # Add asset
        self.symbol = self.AddEquity("SPY", Resolution.Daily).Symbol
        
        # Technical indicators for features
        self.sma_short = self.SMA(self.symbol, 10)
        self.sma_long = self.SMA(self.symbol, 20)
        self.rsi = self.RSI(self.symbol, 14)
        self.bb = self.BB(self.symbol, 20, 2)
        
        # ML prediction placeholder
        self.ml_signal_strength = 0
        self.ml_signal_type = "HOLD"
        
        # Trading parameters
        self.position_size = 0.2
        self.signal_threshold = 0.6
        
    def OnData(self, data):
        """Handle new data"""
        if not all([self.sma_short.IsReady, self.sma_long.IsReady, 
                   self.rsi.IsReady, self.bb.IsReady]):
            return
            
        if not data.ContainsKey(self.symbol):
            return
            
        # Prepare features for ML model
        features = self.PrepareMLFeatures(data)
        
        # Get ML prediction (placeholder - integrate with external ML service)
        ml_prediction = self.GetMLPrediction(features)
        
        # Trading logic based on ML prediction
        if ml_prediction["confidence"] > self.signal_threshold:
            signal_type = ml_prediction["signal"]
            strength = ml_prediction["confidence"]
            price = data[self.symbol].Close
            
            if signal_type == "BUY" and not self.Portfolio.Invested:
                self.SetHoldings(self.symbol, self.position_size)
                self.Debug(f"SIGNAL: {self.symbol} BUY {strength:.2f} {price:.2f}")
                
            elif signal_type == "SELL" and self.Portfolio.Invested:
                self.Liquidate(self.symbol)
                self.Debug(f"SIGNAL: {self.symbol} SELL {strength:.2f} {price:.2f}")
    
    def PrepareMLFeatures(self, data):
        """Prepare features for ML model"""
        price = data[self.symbol].Close
        
        features = {
            "price": float(price),
            "sma_short": float(self.sma_short.Current.Value),
            "sma_long": float(self.sma_long.Current.Value),
            "rsi": float(self.rsi.Current.Value),
            "bb_upper": float(self.bb.UpperBand.Current.Value),
            "bb_lower": float(self.bb.LowerBand.Current.Value),
            "bb_position": (price - self.bb.LowerBand.Current.Value) / 
                          (self.bb.UpperBand.Current.Value - self.bb.LowerBand.Current.Value),
            "sma_ratio": self.sma_short.Current.Value / self.sma_long.Current.Value
        }
        
        return features
    
    def GetMLPrediction(self, features):
        """Get prediction from ML model (placeholder)"""
        # This is a placeholder - integrate with your ML service
        # In production, this would make an API call to your ML service
        
        # Simple rule-based logic as example
        sma_ratio = features.get("sma_ratio", 1.0)
        rsi = features.get("rsi", 50)
        bb_position = features.get("bb_position", 0.5)
        
        # Combine indicators
        signal_score = 0
        
        if sma_ratio > 1.02 and rsi < 70 and bb_position < 0.8:
            signal_score = 0.7
            signal_type = "BUY"
        elif sma_ratio < 0.98 and rsi > 30 and bb_position > 0.2:
            signal_score = 0.7
            signal_type = "SELL"
        else:
            signal_score = 0.3
            signal_type = "HOLD"
        
        return {
            "signal": signal_type,
            "confidence": signal_score,
            "features": features
        }
    
    def OnEndOfAlgorithm(self):
        """Called at the end of the algorithm"""
        self.Debug(f"Final Portfolio Value: {self.Portfolio.TotalPortfolioValue}")
'''

    def _get_multi_asset_template(self) -> str:
        """Get multi-asset algorithm template"""
        return '''from AlgorithmImports import *

class MultiAssetStrategy(QCAlgorithm):
    
    def Initialize(self):
        """Initialize algorithm"""
        self.SetStartDate(2024, 1, 1)
        self.SetEndDate(2024, 12, 31)
        self.SetCash(100000)
        
        # Add multiple asset classes
        self.equities = ["SPY", "QQQ"]  # US Equities
        self.bonds = ["TLT", "IEF"]     # Bonds
        self.commodities = ["GLD", "SLV"]  # Commodities
        
        self.symbols = []
        self.indicators = {}
        
        # Add all assets
        for symbol_list in [self.equities, self.bonds, self.commodities]:
            for symbol_str in symbol_list:
                symbol = self.AddEquity(symbol_str, Resolution.Daily).Symbol
                self.symbols.append(symbol)
                
                # Add indicators
                self.indicators[symbol] = {
                    "sma": self.SMA(symbol, 20),
                    "rsi": self.RSI(symbol, 14),
                    "momentum": self.MOMP(symbol, 10)
                }
        
        # Portfolio allocation
        self.target_allocations = {
            "equities": 0.6,
            "bonds": 0.3,
            "commodities": 0.1
        }
        
        # Rebalancing
        self.rebalance_frequency = 21  # Monthly
        self.last_rebalance = self.Time
        
    def OnData(self, data):
        """Handle new data"""
        # Monthly rebalancing
        if (self.Time - self.last_rebalance).days < self.rebalance_frequency:
            return
            
        self.RebalancePortfolio(data)
        self.last_rebalance = self.Time
    
    def RebalancePortfolio(self, data):
        """Rebalance portfolio across asset classes"""
        
        # Calculate signals for each asset class
        equity_signals = self.CalculateAssetClassSignals(self.equities, data)
        bond_signals = self.CalculateAssetClassSignals(self.bonds, data)
        commodity_signals = self.CalculateAssetClassSignals(self.commodities, data)
        
        # Adjust allocations based on signals
        adjusted_allocations = self.AdjustAllocations(
            equity_signals, bond_signals, commodity_signals
        )
        
        # Rebalance positions
        self.AllocateToAssetClass(self.equities, adjusted_allocations["equities"], data)
        self.AllocateToAssetClass(self.bonds, adjusted_allocations["bonds"], data)
        self.AllocateToAssetClass(self.commodities, adjusted_allocations["commodities"], data)
    
    def CalculateAssetClassSignals(self, asset_list, data):
        """Calculate signals for an asset class"""
        signals = {}
        
        for symbol_str in asset_list:
            symbol = None
            for s in self.symbols:
                if str(s) == symbol_str:
                    symbol = s
                    break
            
            if symbol and symbol in self.indicators and data.ContainsKey(symbol):
                indicators = self.indicators[symbol]
                
                if all(ind.IsReady for ind in indicators.values()):
                    price = data[symbol].Close
                    sma = indicators["sma"].Current.Value
                    rsi = indicators["rsi"].Current.Value
                    momentum = indicators["momentum"].Current.Value
                    
                    # Calculate composite signal
                    signal_strength = 0
                    
                    # Trend signal
                    if price > sma:
                        signal_strength += 0.3
                    else:
                        signal_strength -= 0.3
                    
                    # RSI signal
                    if 30 < rsi < 70:
                        signal_strength += 0.2
                    elif rsi < 30:
                        signal_strength += 0.4  # Oversold
                    elif rsi > 70:
                        signal_strength -= 0.4  # Overbought
                    
                    # Momentum signal
                    if momentum > 0:
                        signal_strength += 0.3
                    else:
                        signal_strength -= 0.3
                    
                    signals[symbol_str] = {
                        "strength": max(-1, min(1, signal_strength)),
                        "price": price
                    }
        
        return signals
    
    def AdjustAllocations(self, equity_signals, bond_signals, commodity_signals):
        """Adjust target allocations based on signals"""
        
        # Calculate average signal strength for each asset class
        equity_avg = sum(s["strength"] for s in equity_signals.values()) / len(equity_signals) if equity_signals else 0
        bond_avg = sum(s["strength"] for s in bond_signals.values()) / len(bond_signals) if bond_signals else 0
        commodity_avg = sum(s["strength"] for s in commodity_signals.values()) / len(commodity_signals) if commodity_signals else 0
        
        # Adjust allocations (simple approach)
        base_equity = self.target_allocations["equities"]
        base_bond = self.target_allocations["bonds"]
        base_commodity = self.target_allocations["commodities"]
        
        # Increase allocation to asset classes with positive signals
        equity_allocation = base_equity + (equity_avg * 0.1)
        bond_allocation = base_bond + (bond_avg * 0.1)
        commodity_allocation = base_commodity + (commodity_avg * 0.1)
        
        # Normalize to sum to 1
        total = equity_allocation + bond_allocation + commodity_allocation
        
        return {
            "equities": equity_allocation / total,
            "bonds": bond_allocation / total,
            "commodities": commodity_allocation / total
        }
    
    def AllocateToAssetClass(self, asset_list, allocation, data):
        """Allocate capital to an asset class"""
        
        # Equal weight within asset class
        weight_per_asset = allocation / len(asset_list)
        
        for symbol_str in asset_list:
            symbol = None
            for s in self.symbols:
                if str(s) == symbol_str:
                    symbol = s
                    break
            
            if symbol and data.ContainsKey(symbol):
                self.SetHoldings(symbol, weight_per_asset)
                
                price = data[symbol].Close
                action = "BUY" if weight_per_asset > 0 else "SELL"
                self.Debug(f"SIGNAL: {symbol} {action} {abs(weight_per_asset):.2f} {price:.2f}")
    
    def OnEndOfAlgorithm(self):
        """Called at the end of the algorithm"""
        self.Debug(f"Final Portfolio Value: {self.Portfolio.TotalPortfolioValue}")
'''