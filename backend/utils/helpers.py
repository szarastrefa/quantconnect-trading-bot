#!/usr/bin/env python3
"""
Utility Helper Functions for QuantConnect Trading Bot
Provides common utility functions used across the application
"""

import re
import os
import json
import hashlib
import logging
from typing import Any, Dict, List, Optional, Union
from datetime import datetime
from pathlib import Path

logger = logging.getLogger(__name__)

def validate_json(data: Union[str, Dict]) -> bool:
    """Validate JSON data"""
    try:
        if isinstance(data, str):
            json.loads(data)
        elif isinstance(data, dict):
            json.dumps(data)
        return True
    except (json.JSONDecodeError, TypeError):
        return False

def sanitize_input(input_string: str, max_length: int = 255) -> str:
    """Sanitize user input string"""
    if not isinstance(input_string, str):
        input_string = str(input_string)
    
    # Remove potentially dangerous characters
    sanitized = re.sub(r'[<>"\'\/\\]', '', input_string)
    
    # Trim whitespace and limit length
    sanitized = sanitized.strip()[:max_length]
    
    return sanitized

def sanitize_filename(filename: str) -> str:
    """Sanitize filename for safe file operations"""
    if not isinstance(filename, str):
        filename = str(filename)
    
    # Remove or replace unsafe characters
    sanitized = re.sub(r'[<>:"/\\|?*]', '_', filename)
    sanitized = re.sub(r'[\x00-\x1f]', '', sanitized)  # Remove control characters
    sanitized = sanitized.strip(' .')
    
    # Ensure filename is not empty and not too long
    if not sanitized:
        sanitized = 'untitled'
    
    return sanitized[:255]

def validate_file_type(file_path: str, allowed_extensions: List[str]) -> bool:
    """Validate file type by extension"""
    file_path = Path(file_path)
    file_extension = file_path.suffix.lower()
    
    return file_extension in [ext.lower() for ext in allowed_extensions]

def validate_api_credentials(credentials: Dict[str, Any], required_fields: List[str]) -> bool:
    """Validate API credentials structure"""
    if not isinstance(credentials, dict):
        return False
    
    return all(field in credentials and credentials[field] for field in required_fields)

def format_currency_pair(pair: str) -> str:
    """Format currency pair to standard format"""
    if not isinstance(pair, str):
        return str(pair).upper()
    
    # Remove separators and convert to uppercase
    pair = re.sub(r'[^A-Za-z]', '', pair).upper()
    
    # Standard forex pairs are 6 characters
    if len(pair) == 6:
        return f"{pair[:3]}{pair[3:]}"
    
    return pair

def generate_hash(data: Union[str, Dict, List]) -> str:
    """Generate SHA256 hash of data"""
    if isinstance(data, (dict, list)):
        data = json.dumps(data, sort_keys=True)
    elif not isinstance(data, str):
        data = str(data)
    
    return hashlib.sha256(data.encode('utf-8')).hexdigest()

def safe_float(value: Any, default: float = 0.0) -> float:
    """Safely convert value to float"""
    try:
        return float(value)
    except (ValueError, TypeError):
        return default

def safe_int(value: Any, default: int = 0) -> int:
    """Safely convert value to integer"""
    try:
        return int(float(value))  # Handle string floats like "1.0"
    except (ValueError, TypeError):
        return default

def format_percentage(value: float, decimal_places: int = 2) -> str:
    """Format float as percentage string"""
    try:
        return f"{value:.{decimal_places}f}%"
    except (ValueError, TypeError):
        return "0.00%"

def format_currency(value: float, currency: str = "USD", decimal_places: int = 2) -> str:
    """Format float as currency string"""
    try:
        if currency.upper() == "USD":
            return f"${value:,.{decimal_places}f}"
        elif currency.upper() == "EUR":
            return f"€{value:,.{decimal_places}f}"
        elif currency.upper() == "GBP":
            return f"£{value:,.{decimal_places}f}"
        else:
            return f"{value:,.{decimal_places}f} {currency.upper()}"
    except (ValueError, TypeError):
        return f"0.00 {currency.upper()}"

def truncate_string(text: str, max_length: int = 50, suffix: str = "...") -> str:
    """Truncate string to maximum length"""
    if not isinstance(text, str):
        text = str(text)
    
    if len(text) <= max_length:
        return text
    
    return text[:max_length - len(suffix)] + suffix

def is_valid_email(email: str) -> bool:
    """Validate email address format"""
    if not isinstance(email, str):
        return False
    
    email_pattern = re.compile(
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    )
    return bool(email_pattern.match(email))

def parse_timeframe(timeframe: str) -> Optional[int]:
    """Parse timeframe string to seconds"""
    if not isinstance(timeframe, str):
        return None
    
    timeframe = timeframe.lower().strip()
    
    # Parse format like "1h", "30m", "1d"
    match = re.match(r'^(\d+)([smhd])$', timeframe)
    if not match:
        return None
    
    value, unit = match.groups()
    value = int(value)
    
    multipliers = {
        's': 1,           # seconds
        'm': 60,          # minutes
        'h': 3600,        # hours
        'd': 86400        # days
    }
    
    return value * multipliers.get(unit, 1)

def create_directory_if_not_exists(path: Union[str, Path]) -> bool:
    """Create directory if it doesn't exist"""
    try:
        Path(path).mkdir(parents=True, exist_ok=True)
        return True
    except Exception as e:
        logger.error(f"Error creating directory {path}: {e}")
        return False

def get_file_size(file_path: Union[str, Path]) -> int:
    """Get file size in bytes"""
    try:
        return Path(file_path).stat().st_size
    except Exception:
        return 0

def format_file_size(size_bytes: int) -> str:
    """Format file size in human readable format"""
    if size_bytes == 0:
        return "0 B"
    
    units = ['B', 'KB', 'MB', 'GB', 'TB']
    unit_index = 0
    size = float(size_bytes)
    
    while size >= 1024.0 and unit_index < len(units) - 1:
        size /= 1024.0
        unit_index += 1
    
    if unit_index == 0:
        return f"{int(size)} {units[unit_index]}"
    else:
        return f"{size:.1f} {units[unit_index]}"

def merge_dicts(dict1: Dict, dict2: Dict, deep: bool = True) -> Dict:
    """Merge two dictionaries"""
    if not deep:
        return {**dict1, **dict2}
    
    result = dict1.copy()
    
    for key, value in dict2.items():
        if key in result and isinstance(result[key], dict) and isinstance(value, dict):
            result[key] = merge_dicts(result[key], value, deep=True)
        else:
            result[key] = value
    
    return result

def chunk_list(lst: List, chunk_size: int) -> List[List]:
    """Split list into chunks of specified size"""
    return [lst[i:i + chunk_size] for i in range(0, len(lst), chunk_size)]

def flatten_dict(d: Dict, parent_key: str = '', sep: str = '.') -> Dict:
    """Flatten nested dictionary"""
    items = []
    
    for key, value in d.items():
        new_key = f"{parent_key}{sep}{key}" if parent_key else key
        
        if isinstance(value, dict):
            items.extend(flatten_dict(value, new_key, sep=sep).items())
        else:
            items.append((new_key, value))
    
    return dict(items)

def get_nested_value(data: Dict, keys: str, default: Any = None, sep: str = '.') -> Any:
    """Get value from nested dictionary using dot notation"""
    try:
        result = data
        for key in keys.split(sep):
            result = result[key]
        return result
    except (KeyError, TypeError):
        return default

def set_nested_value(data: Dict, keys: str, value: Any, sep: str = '.') -> None:
    """Set value in nested dictionary using dot notation"""
    key_list = keys.split(sep)
    current = data
    
    for key in key_list[:-1]:
        if key not in current or not isinstance(current[key], dict):
            current[key] = {}
        current = current[key]
    
    current[key_list[-1]] = value

def validate_required_fields(data: Dict, required_fields: List[str]) -> List[str]:
    """Validate that required fields are present in data"""
    missing_fields = []
    
    for field in required_fields:
        if '.' in field:
            # Handle nested fields
            if get_nested_value(data, field) is None:
                missing_fields.append(field)
        else:
            if field not in data or data[field] is None:
                missing_fields.append(field)
    
    return missing_fields

def generate_unique_id(prefix: str = '', length: int = 8) -> str:
    """Generate unique identifier"""
    import secrets
    import string
    
    alphabet = string.ascii_letters + string.digits
    unique_part = ''.join(secrets.choice(alphabet) for _ in range(length))
    
    if prefix:
        return f"{prefix}_{unique_part}"
    return unique_part

def retry_on_failure(max_retries: int = 3, delay: float = 1.0):
    """Decorator to retry function on failure"""
    import time
    import functools
    
    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            last_exception = None
            
            for attempt in range(max_retries):
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    last_exception = e
                    if attempt < max_retries - 1:
                        logger.warning(f"Attempt {attempt + 1} failed for {func.__name__}: {e}")
                        time.sleep(delay * (attempt + 1))  # Exponential backoff
                    else:
                        logger.error(f"All {max_retries} attempts failed for {func.__name__}")
            
            raise last_exception
        
        return wrapper
    return decorator

def format_datetime(dt: datetime, format_string: str = "%Y-%m-%d %H:%M:%S") -> str:
    """Format datetime to string"""
    try:
        return dt.strftime(format_string)
    except (AttributeError, ValueError):
        return str(dt)

def parse_datetime(dt_string: str, format_string: str = "%Y-%m-%d %H:%M:%S") -> Optional[datetime]:
    """Parse datetime from string"""
    try:
        return datetime.strptime(dt_string, format_string)
    except (ValueError, TypeError):
        # Try ISO format as fallback
        try:
            return datetime.fromisoformat(dt_string.replace('Z', '+00:00'))
        except (ValueError, AttributeError):
            return None

def calculate_percentage_change(old_value: float, new_value: float) -> float:
    """Calculate percentage change between two values"""
    try:
        if old_value == 0:
            return 100.0 if new_value > 0 else 0.0
        return ((new_value - old_value) / abs(old_value)) * 100
    except (TypeError, ZeroDivisionError):
        return 0.0

def is_market_open(symbol: str = "EURUSD") -> bool:
    """Check if market is open (simplified check)"""
    import pytz
    from datetime import datetime
    
    try:
        # Get current time in relevant timezone
        if symbol.upper() in ['EURUSD', 'GBPUSD', 'EURGBP']:
            # London timezone for European pairs
            tz = pytz.timezone('Europe/London')
        elif symbol.upper() in ['USDJPY', 'AUDUSD', 'NZDUSD']:
            # New York timezone for USD pairs
            tz = pytz.timezone('America/New_York')
        else:
            # UTC as fallback
            tz = pytz.UTC
        
        current_time = datetime.now(tz)
        weekday = current_time.weekday()
        hour = current_time.hour
        
        # Simple check: Monday to Friday, roughly 9 AM to 5 PM
        if weekday < 5 and 9 <= hour <= 17:
            return True
        
        return False
        
    except Exception:
        # If timezone check fails, assume market is open
        return True

def load_json_file(file_path: Union[str, Path]) -> Optional[Dict]:
    """Load JSON file safely"""
    try:
        with open(file_path, 'r') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError, IOError) as e:
        logger.error(f"Error loading JSON file {file_path}: {e}")
        return None

def save_json_file(data: Dict, file_path: Union[str, Path], indent: int = 2) -> bool:
    """Save data to JSON file safely"""
    try:
        # Create directory if it doesn't exist
        Path(file_path).parent.mkdir(parents=True, exist_ok=True)
        
        with open(file_path, 'w') as f:
            json.dump(data, f, indent=indent, default=str)
        return True
    except (IOError, TypeError) as e:
        logger.error(f"Error saving JSON file {file_path}: {e}")
        return False

def get_environment_variable(var_name: str, default: Any = None, var_type: type = str) -> Any:
    """Get environment variable with type conversion"""
    value = os.getenv(var_name, default)
    
    if value is None or value == default:
        return default
    
    try:
        if var_type == bool:
            return value.lower() in ('true', '1', 'yes', 'on')
        elif var_type == int:
            return int(value)
        elif var_type == float:
            return float(value)
        elif var_type == list:
            return value.split(',')
        else:
            return var_type(value)
    except (ValueError, TypeError):
        logger.warning(f"Could not convert environment variable {var_name}={value} to {var_type}")
        return default