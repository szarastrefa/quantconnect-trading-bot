# 🔧 Troubleshooting Guide - QuantConnect Trading Bot

This guide helps resolve common issues during installation and operation of the QuantConnect Trading Bot.

## 🚨 **Common Installation Issues**

### **1. Environment File Format Error**

**Error:** `failed to read .env: line XX: unexpected character "+" in variable name`

**Cause:** Invalid characters in environment variable values (usually base64 strings with special characters)

**Solution:**
```bash
# Option 1: Use the validation script to fix automatically
./scripts/validate_environment.sh --fix-env

# Option 2: Manually fix the .env file
nano /opt/quantconnect-trading-bot/.env
# Remove any lines with +, =, or / characters in values
# Replace with alphanumeric passwords
```

**Prevention:** The updated setup script now generates safe alphanumeric passwords.

### **2. Docker Compose Configuration Invalid**

**Error:** `Invalid Docker Compose configuration`

**Solution:**
```bash
# Validate configuration
cd /opt/quantconnect-trading-bot
docker-compose -f docker-compose.production.yml config

# Fix .env file issues
./scripts/validate_environment.sh --fix-env

# Test configuration again
docker-compose -f docker-compose.production.yml config
```

### **3. Permission Denied Errors**

**Error:** `Permission denied` when running Docker commands

**Solution:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Or restart your session
sudo su - $USER
```

### **4. Port Already in Use**

**Error:** `Port 80/443 already in use`

**Solution:**
```bash
# Check what's using the ports
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443

# Stop conflicting services
sudo systemctl stop apache2
sudo systemctl stop nginx

# Or kill specific processes
sudo kill -9 <PID>
```

### **5. DDNS Update Failed**

**Error:** `DDNS update failed`

**Solution:**
```bash
# Test DDNS manually
curl -s "https://tunnel.hostddns.us/ddns/377b9a29c7bba5435e4b5d53e3ead4aa"

# Check network connectivity
ping 8.8.8.8

# Update DDNS manually
trading-bot ddns-update
```

---

## 🛠️ **Quick Fix Commands**

### **Complete System Reset**
```bash
# Remove old installation
sudo rm -rf /opt/quantconnect-trading-bot

# Stop any running containers
docker stop $(docker ps -aq --filter "name=trading_bot")
docker rm $(docker ps -aq --filter "name=trading_bot")

# Re-run installer
curl -fsSL https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh | bash
```

### **Fix Environment File**
```bash
# Navigate to project
cd /opt/quantconnect-trading-bot

# Run validation and fix
./scripts/validate_environment.sh --fix-env

# Test configuration
docker-compose -f docker-compose.production.yml config
```

### **Restart All Services**
```bash
# Using management script
trading-bot restart

# Or manually
cd /opt/quantconnect-trading-bot
docker-compose -f docker-compose.production.yml down
docker-compose -f docker-compose.production.yml up -d
```

---

## 📋 **Diagnostic Commands**

### **System Health Check**
```bash
# Full system validation
./scripts/validate_environment.sh

# Quick status check
trading-bot status

# Detailed health check
trading-bot health

# View logs
trading-bot logs
trading-bot logs api
trading-bot logs nginx
```

### **Check Services**
```bash
# Check Docker status
sudo systemctl status docker

# Check running containers
docker ps

# Check container logs
docker logs trading_bot_api
docker logs trading_bot_nginx
docker logs trading_bot_db

# Check system resources
docker stats
```

### **Network & Connectivity**
```bash
# Check domain resolution
nslookup eqtrader.ddnskita.my.id

# Test API endpoint
curl -k https://eqtrader.ddnskita.my.id/health
curl -k https://eqtrader.ddnskita.my.id/api/health

# Check SSL certificate
openssl s_client -connect eqtrader.ddnskita.my.id:443 -servername eqtrader.ddnskita.my.id

# Test DDNS
curl -s "https://tunnel.hostddns.us/ddns/377b9a29c7bba5435e4b5d53e3ead4aa"
```

---

## 🔍 **Detailed Troubleshooting**

### **Database Issues**

**Problem:** Database connection errors

**Diagnosis:**
```bash
# Check database container
docker logs trading_bot_db

# Test database connection
docker exec -it trading_bot_db psql -U postgres -d quantconnect_trading

# Check database credentials in .env
grep POSTGRES_ /opt/quantconnect-trading-bot/.env
```

**Solutions:**
```bash
# Reset database
docker-compose -f docker-compose.production.yml down
docker volume rm $(docker volume ls -q --filter name=postgres)
docker-compose -f docker-compose.production.yml up -d

# Or recreate with new credentials
./scripts/validate_environment.sh --fix-env
trading-bot restart
```

### **SSL Certificate Issues**

**Problem:** SSL certificate errors or HTTPS not working

**Diagnosis:**
```bash
# Check certificate files
sudo ls -la /etc/letsencrypt/live/eqtrader.ddnskita.my.id/

# Check certificate validity
sudo openssl x509 -in /etc/letsencrypt/live/eqtrader.ddnskita.my.id/fullchain.pem -text -noout

# Check nginx configuration
docker exec -it trading_bot_nginx nginx -t
```

**Solutions:**
```bash
# Obtain new SSL certificate
sudo certbot certonly --standalone -d eqtrader.ddnskita.my.id

# Or disable SSL temporarily
# Edit nginx/production.conf to remove SSL sections
# Restart nginx container
docker-compose -f docker-compose.production.yml restart nginx
```

### **Frontend Not Loading**

**Problem:** Web interface doesn't load or shows errors

**Diagnosis:**
```bash
# Check frontend container
docker logs trading_bot_frontend

# Check nginx routing
docker logs trading_bot_nginx

# Test direct frontend access
curl http://localhost:3000
```

**Solutions:**
```bash
# Rebuild frontend
cd /opt/quantconnect-trading-bot
docker-compose -f docker-compose.production.yml build frontend
docker-compose -f docker-compose.production.yml restart frontend

# Check environment variables
grep REACT_APP /opt/quantconnect-trading-bot/.env
```

### **API Not Responding**

**Problem:** Backend API returns errors or doesn't respond

**Diagnosis:**
```bash
# Check API container logs
docker logs trading_bot_api --tail 50

# Test API directly
curl http://localhost:5000/api/health

# Check API container status
docker exec -it trading_bot_api ps aux
```

**Solutions:**
```bash
# Restart API service
docker-compose -f docker-compose.production.yml restart api

# Check Python dependencies
docker exec -it trading_bot_api pip list

# Rebuild API container
docker-compose -f docker-compose.production.yml build api
docker-compose -f docker-compose.production.yml up -d api
```

---

## 🔑 **Broker Connection Issues**

### **Binance Connection Failed**

**Problem:** Cannot connect to Binance API

**Solutions:**
```bash
# Check API keys in .env
grep BINANCE /opt/quantconnect-trading-bot/.env

# Test API keys manually
curl -H "X-MBX-APIKEY: your_api_key" "https://api.binance.com/api/v3/account"

# Enable testnet for testing
echo "BINANCE_TESTNET=true" >> /opt/quantconnect-trading-bot/.env
trading-bot restart
```

### **XTB Connection Issues**

**Problem:** XTB broker authentication failed

**Solutions:**
```bash
# Verify credentials
grep XTB /opt/quantconnect-trading-bot/.env

# Enable demo mode
echo "XTB_DEMO=true" >> /opt/quantconnect-trading-bot/.env
trading-bot restart

# Check XTB server status
telnet xapi.xtb.com 5124
```

---

## 📊 **Performance Issues**

### **High Resource Usage**

**Problem:** System using too much CPU/Memory

**Diagnosis:**
```bash
# Check resource usage
docker stats
htop

# Check container resource limits
docker inspect trading_bot_api | grep -i memory
```

**Solutions:**
```bash
# Adjust resource limits in docker-compose.production.yml
# Add under each service:
deploy:
  resources:
    limits:
      memory: 512M
      cpus: '0.5'

# Restart with new limits
trading-bot restart
```

### **Slow Response Times**

**Problem:** API or web interface is slow

**Solutions:**
```bash
# Check database performance
docker exec -it trading_bot_db psql -U postgres -c "SELECT * FROM pg_stat_activity;"

# Clear Redis cache
docker exec -it trading_bot_redis redis-cli FLUSHALL

# Restart services
trading-bot restart
```

---

## 🆘 **Emergency Procedures**

### **Complete System Recovery**

If the system is completely broken:

```bash
# 1. Stop everything
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)
docker volume prune -f
docker network prune -f

# 2. Clean installation directory
sudo rm -rf /opt/quantconnect-trading-bot

# 3. Re-run installer
curl -fsSL https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh | bash

# 4. Reconfigure broker credentials
nano /opt/quantconnect-trading-bot/.env

# 5. Start system
trading-bot start
```

### **Backup & Restore**

**Create Backup:**
```bash
# Backup configuration and data
trading-bot backup

# Manual backup
cp -r /opt/quantconnect-trading-bot/data ~/backup-$(date +%Y%m%d)
cp /opt/quantconnect-trading-bot/.env ~/backup-$(date +%Y%m%d)/
```

**Restore from Backup:**
```bash
# Restore configuration
cp ~/backup-20241001/.env /opt/quantconnect-trading-bot/

# Restore data
cp -r ~/backup-20241001/data /opt/quantconnect-trading-bot/

# Restart system
trading-bot restart
```

---

## 📞 **Getting Help**

### **Log Collection for Support**

```bash
# Collect all logs
mkdir ~/trading-bot-logs
docker logs trading_bot_api > ~/trading-bot-logs/api.log 2>&1
docker logs trading_bot_nginx > ~/trading-bot-logs/nginx.log 2>&1
docker logs trading_bot_db > ~/trading-bot-logs/db.log 2>&1
cp /opt/quantconnect-trading-bot/.env ~/trading-bot-logs/env.txt
docker ps > ~/trading-bot-logs/containers.txt

# Create archive
tar -czf ~/trading-bot-logs.tar.gz ~/trading-bot-logs/
```

### **System Information**

```bash
# Generate system info for support
echo "=== System Information ===" > ~/system-info.txt
uname -a >> ~/system-info.txt
docker version >> ~/system-info.txt
docker-compose version >> ~/system-info.txt
df -h >> ~/system-info.txt
free -h >> ~/system-info.txt
./scripts/validate_environment.sh >> ~/system-info.txt 2>&1
```

### **Support Channels**

- **GitHub Issues:** [Create Issue](https://github.com/szarastrefa/quantconnect-trading-bot/issues)
- **Documentation:** [Project Wiki](https://github.com/szarastrefa/quantconnect-trading-bot/wiki)
- **Discussions:** [GitHub Discussions](https://github.com/szarastrefa/quantconnect-trading-bot/discussions)

---

## 🔧 **Useful Commands Reference**

| Command | Description |
|---------|-------------|
| `trading-bot start` | Start the system |
| `trading-bot stop` | Stop the system |
| `trading-bot status` | Show system status |
| `trading-bot logs` | View all logs |
| `trading-bot health` | Run health check |
| `trading-bot restart` | Restart all services |
| `trading-bot update` | Update system from repository |
| `trading-bot ddns-update` | Update DDNS record |
| `trading-bot backup` | Create system backup |
| `./scripts/validate_environment.sh` | Validate configuration |
| `./scripts/validate_environment.sh --fix-env` | Fix .env file issues |

---

**Remember:** Always backup your configuration and data before making major changes!

**💡 Pro Tip:** Use `trading-bot status` to quickly check if everything is running correctly.

**⚠️ Warning:** Never share your actual API keys or passwords when asking for help. Always redact sensitive information.