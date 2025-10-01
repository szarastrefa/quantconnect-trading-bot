#!/usr/bin/env python3
"""
DDNS Service for QuantConnect Trading Bot
Automatically manages DDNS updates for eqtrader.ddnskita.my.id
Integrates with hostddns.us tunnel service
"""

import os
import asyncio
import aiohttp
import logging
import json
import time
from datetime import datetime, timedelta
from typing import Dict, Optional, Any
from dataclasses import dataclass
from pathlib import Path

logger = logging.getLogger(__name__)

@dataclass
class DDNSConfig:
    """DDNS configuration"""
    update_url: str
    domain: str
    check_interval: int = 300  # 5 minutes
    timeout: int = 30
    retry_attempts: int = 3
    retry_delay: int = 60
    log_file: Optional[str] = None

@dataclass
class DDNSStatus:
    """DDNS status information"""
    current_ip: Optional[str] = None
    last_update: Optional[datetime] = None
    last_success: Optional[datetime] = None
    update_count: int = 0
    error_count: int = 0
    last_error: Optional[str] = None
    is_healthy: bool = True

class DDNSService:
    """DDNS Service for automatic domain updates"""
    
    def __init__(self, config: DDNSConfig):
        self.config = config
        self.status = DDNSStatus()
        self.is_running = False
        self._session: Optional[aiohttp.ClientSession] = None
        self._task: Optional[asyncio.Task] = None
        
        # Setup logging
        if config.log_file:
            handler = logging.FileHandler(config.log_file)
            handler.setFormatter(logging.Formatter(
                '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            ))
            logger.addHandler(handler)
        
        logger.info(f"DDNS Service initialized for {config.domain}")
    
    async def __aenter__(self):
        """Async context manager entry"""
        await self.start()
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit"""
        await self.stop()
    
    async def start(self):
        """Start DDNS monitoring service"""
        if self.is_running:
            logger.warning("DDNS service is already running")
            return
        
        logger.info(f"Starting DDNS service for {self.config.domain}")
        
        # Create HTTP session
        timeout = aiohttp.ClientTimeout(total=self.config.timeout)
        self._session = aiohttp.ClientSession(timeout=timeout)
        
        # Start monitoring task
        self.is_running = True
        self._task = asyncio.create_task(self._monitor_loop())
        
        # Initial update
        await self.update_ddns_record()
        
        logger.info("DDNS service started successfully")
    
    async def stop(self):
        """Stop DDNS monitoring service"""
        if not self.is_running:
            return
        
        logger.info("Stopping DDNS service...")
        
        self.is_running = False
        
        # Cancel monitoring task
        if self._task and not self._task.done():
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        
        # Close HTTP session
        if self._session and not self._session.closed:
            await self._session.close()
        
        logger.info("DDNS service stopped")
    
    async def _monitor_loop(self):
        """Main monitoring loop"""
        try:
            while self.is_running:
                try:
                    # Check if IP has changed
                    current_ip = await self.get_public_ip()
                    
                    if current_ip and current_ip != self.status.current_ip:
                        logger.info(f"IP changed: {self.status.current_ip} -> {current_ip}")
                        await self.update_ddns_record()
                    
                    # Update health status
                    self._update_health_status()
                    
                    # Wait for next check
                    await asyncio.sleep(self.config.check_interval)
                    
                except asyncio.CancelledError:
                    break
                except Exception as e:
                    logger.error(f"Error in monitoring loop: {e}")
                    self.status.error_count += 1
                    self.status.last_error = str(e)
                    await asyncio.sleep(60)  # Wait before retry
        
        except asyncio.CancelledError:
            logger.info("DDNS monitoring loop cancelled")
        except Exception as e:
            logger.error(f"Fatal error in monitoring loop: {e}")
            self.status.is_healthy = False
    
    async def get_public_ip(self) -> Optional[str]:
        """Get current public IP address"""
        ip_services = [
            'https://ifconfig.me/ip',
            'https://api.ipify.org',
            'https://icanhazip.com',
            'https://ident.me'
        ]
        
        if not self._session:
            return None
        
        for service in ip_services:
            try:
                async with self._session.get(service) as response:
                    if response.status == 200:
                        ip = (await response.text()).strip()
                        # Validate IP format
                        if self._validate_ip(ip):
                            return ip
            except Exception as e:
                logger.debug(f"Failed to get IP from {service}: {e}")
                continue
        
        logger.warning("Failed to get public IP from all services")
        return None
    
    def _validate_ip(self, ip: str) -> bool:
        """Validate IP address format"""
        import re
        pattern = re.compile(
            r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}'
            r'(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
        )
        return bool(pattern.match(ip))
    
    async def update_ddns_record(self, force: bool = False) -> Dict[str, Any]:
        """Update DDNS record"""
        if not self._session:
            return {'error': 'Service not started'}
        
        retry_count = 0
        while retry_count < self.config.retry_attempts:
            try:
                logger.info(f"Updating DDNS record for {self.config.domain}")
                
                async with self._session.get(self.config.update_url) as response:
                    response_text = await response.text()
                    
                    # Try to parse JSON response
                    try:
                        response_data = json.loads(response_text)
                    except json.JSONDecodeError:
                        response_data = {'message': response_text}
                    
                    if response.status == 200:
                        # Check if update was successful
                        if response_data.get('result') == 'success':
                            # Extract IP from response message
                            message = response_data.get('message', '')
                            if 'to' in message:
                                import re
                                ip_match = re.search(r'([0-9]{1,3}\.){3}[0-9]{1,3}', message)
                                if ip_match:
                                    new_ip = ip_match.group(0)
                                    self.status.current_ip = new_ip
                            
                            self.status.last_success = datetime.now()
                            self.status.update_count += 1
                            
                            logger.info(f"✅ DDNS updated successfully: {message}")
                            
                            return {
                                'success': True,
                                'ip': self.status.current_ip,
                                'message': message,
                                'timestamp': datetime.now().isoformat()
                            }
                        else:
                            error_msg = response_data.get('message', 'Unknown error')
                            logger.error(f"DDNS update failed: {error_msg}")
                            
                            self.status.error_count += 1
                            self.status.last_error = error_msg
                            
                            return {
                                'success': False,
                                'error': error_msg,
                                'timestamp': datetime.now().isoformat()
                            }
                    else:
                        error_msg = f"HTTP {response.status}: {response_text}"
                        logger.error(f"DDNS update failed: {error_msg}")
                        
                        self.status.error_count += 1
                        self.status.last_error = error_msg
                        
                        return {
                            'success': False,
                            'error': error_msg,
                            'timestamp': datetime.now().isoformat()
                        }
            
            except Exception as e:
                retry_count += 1
                error_msg = f"Error updating DDNS (attempt {retry_count}): {e}"
                logger.error(error_msg)
                
                self.status.error_count += 1
                self.status.last_error = str(e)
                
                if retry_count < self.config.retry_attempts:
                    logger.info(f"Retrying in {self.config.retry_delay} seconds...")
                    await asyncio.sleep(self.config.retry_delay)
                else:
                    return {
                        'success': False,
                        'error': f'Failed after {retry_count} attempts: {str(e)}',
                        'timestamp': datetime.now().isoformat()
                    }
        
        return {
            'success': False,
            'error': f'Failed after {self.config.retry_attempts} attempts',
            'timestamp': datetime.now().isoformat()
        }
    
    def _update_health_status(self):
        """Update service health status"""
        now = datetime.now()
        
        # Check if last successful update was recent
        if self.status.last_success:
            time_since_success = now - self.status.last_success
            max_time_without_success = timedelta(hours=2)  # 2 hours
            
            if time_since_success > max_time_without_success:
                self.status.is_healthy = False
                logger.warning(f"DDNS service unhealthy: No successful update for {time_since_success}")
            else:
                self.status.is_healthy = True
        
        # Update last update timestamp
        self.status.last_update = now
    
    def get_status(self) -> Dict[str, Any]:
        """Get current DDNS service status"""
        return {
            'domain': self.config.domain,
            'current_ip': self.status.current_ip,
            'is_running': self.is_running,
            'is_healthy': self.status.is_healthy,
            'last_update': self.status.last_update.isoformat() if self.status.last_update else None,
            'last_success': self.status.last_success.isoformat() if self.status.last_success else None,
            'update_count': self.status.update_count,
            'error_count': self.status.error_count,
            'last_error': self.status.last_error,
            'check_interval': self.config.check_interval,
            'update_url': self.config.update_url
        }
    
    async def force_update(self) -> Dict[str, Any]:
        """Force immediate DDNS update"""
        logger.info("Force updating DDNS record...")
        return await self.update_ddns_record(force=True)
    
    def get_metrics(self) -> Dict[str, Any]:
        """Get DDNS service metrics for monitoring"""
        uptime = 0
        if self.status.last_success and self.status.last_update:
            uptime = (self.status.last_update - self.status.last_success).total_seconds()
        
        return {
            'ddns_updates_total': self.status.update_count,
            'ddns_errors_total': self.status.error_count,
            'ddns_is_healthy': 1 if self.status.is_healthy else 0,
            'ddns_uptime_seconds': uptime,
            'ddns_current_ip': self.status.current_ip or '',
            'ddns_last_update_timestamp': (
                self.status.last_update.timestamp() 
                if self.status.last_update else 0
            ),
            'ddns_last_success_timestamp': (
                self.status.last_success.timestamp() 
                if self.status.last_success else 0
            )
        }

def create_ddns_service(config_dict: Dict[str, Any] = None) -> DDNSService:
    """Factory function to create DDNS service from configuration"""
    if config_dict is None:
        config_dict = {}
    
    # Get configuration from environment or provided dict
    config = DDNSConfig(
        update_url=config_dict.get('update_url') or os.getenv(
            'DDNS_UPDATE_URL', 
            'https://tunnel.hostddns.us/ddns/377b9a29c7bba5435e4b5d53e3ead4aa'
        ),
        domain=config_dict.get('domain') or os.getenv(
            'DOMAIN', 
            'eqtrader.ddnskita.my.id'
        ),
        check_interval=int(config_dict.get('check_interval', os.getenv('DDNS_CHECK_INTERVAL', '300'))),
        timeout=int(config_dict.get('timeout', os.getenv('DDNS_TIMEOUT', '30'))),
        retry_attempts=int(config_dict.get('retry_attempts', os.getenv('DDNS_RETRY_ATTEMPTS', '3'))),
        retry_delay=int(config_dict.get('retry_delay', os.getenv('DDNS_RETRY_DELAY', '60'))),
        log_file=config_dict.get('log_file') or os.getenv('DDNS_LOG_FILE')
    )
    
    return DDNSService(config)

async def main():
    """Main function for standalone execution"""
    import signal
    import sys
    
    # Setup logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    # Create DDNS service
    ddns_service = create_ddns_service()
    
    # Handle shutdown signals
    def signal_handler(signum, frame):
        logger.info(f"Received signal {signum}, shutting down...")
        asyncio.create_task(ddns_service.stop())
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Start service
    try:
        await ddns_service.start()
        
        # Keep service running
        while ddns_service.is_running:
            await asyncio.sleep(1)
            
    except KeyboardInterrupt:
        logger.info("Keyboard interrupt received")
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        sys.exit(1)
    finally:
        await ddns_service.stop()
        logger.info("DDNS service shutdown complete")

if __name__ == '__main__':
    asyncio.run(main())