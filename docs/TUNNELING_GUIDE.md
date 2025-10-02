# QuantConnect Trading Bot - Comprehensive Tunneling Guide

## 🌐 Overview

The QuantConnect Trading Bot supports **7 professional tunneling platforms** to overcome NAT, firewall, and CGNAT restrictions. This guide provides comprehensive documentation for each platform to help you choose and configure the best networking solution for your deployment.

## 🎯 Quick Start

### Interactive Menu Setup
```bash
# Launch interactive tunnel selection menu
curl -fsSL https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh | bash
```

### Direct Platform Selection
```bash
# Use specific tunnel type directly
curl -fsSL https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh | bash -s -- --tunnel-localtunnel
```

---

## 📊 Platform Comparison Matrix

| Platform | Cost | Setup Complexity | Reliability | SSL/TLS | Custom Domains | Best For |
|----------|------|------------------|-------------|---------|----------------|----------|
| **Classical DDNS** | Free | Medium | High | ✅ | ✅ | Production deployments |
| **Ngrok Professional** | Paid | Low | Very High | ✅ | ✅ | Development & enterprise |
| **LocalTunnel** | Free | Very Low | Medium | ✅ | ❌ | Quick testing & demos |
| **Serveo SSH** | Free | Very Low | Medium | ✅ | ❌ | Minimal setups |
| **Cloudflare Tunnel** | Free* | Medium | Very High | ✅ | ✅ | High-traffic production |
| **PageKite** | Paid | Medium | High | ✅ | ✅ | Commercial applications |
| **Telebit** | Varies | Medium | Medium | ✅ | ✅ | Privacy-focused |

*Requires Cloudflare domain management

---

## 🏠 1. Classical DDNS (eqtrader.ddnskita.my.id)

### Overview
Professional dedicated domain with automatic DDNS updates, SSL certificates, and production-ready infrastructure.

### Features
- ✅ **Dedicated domain**: `eqtrader.ddnskita.my.id`
- ✅ **Automatic DDNS updates** (every 5 minutes)
- ✅ **SSL/TLS certificates** via Let's Encrypt
- ✅ **Production-ready** infrastructure
- ✅ **Enhanced error handling** (Indonesian "Masih Sama!" responses)

### Setup
```bash
# Automatic selection (default)
curl -fsSL https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh | bash

# Explicit selection
curl -fsSL https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh | bash -s -- --tunnel-classical

# Skip DDNS errors if needed
curl -fsSL https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh | bash -s -- --tunnel-classical --skip-ddns-error
```

### URLs Structure
- **Frontend**: `https://eqtrader.ddnskita.my.id`
- **Backend API**: `https://eqtrader.ddnskita.my.id/api`
- **WebSocket**: `wss://eqtrader.ddnskita.my.id/socket.io`
- **Health Check**: `https://eqtrader.ddnskita.my.id/health`

### Troubleshooting
- **"Masih Sama!" Error**: IP unchanged - this is normal, use `--skip-ddns-error`
- **SSL Certificate Issues**: Use `--skip-ssl-snapd` for VPS/containers
- **Connection Timeout**: Check firewall settings and domain propagation

---

## 🚀 2. Ngrok Professional

### Overview
Enterprise-grade tunneling service with custom subdomains, real-time dashboard, and professional features.

### Features
- ✅ **Custom subdomains** (e.g., `yourname-app.ngrok.io`)
- ✅ **Real-time dashboard** at `http://localhost:4040`
- ✅ **Traffic inspection** and request/response analysis
- ✅ **Enterprise authentication** and access controls
- ✅ **Load balancing** and failover support
- ✅ **Reserved domains** and custom certificates

### Setup
```bash
# With auth token
curl -fsSL https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh | bash -s -- --tunnel-ngrok YOUR_AUTH_TOKEN

# Interactive token input
curl -fsSL https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh | bash -s -- --tunnel-ngrok
```

### Getting Started
1. **Sign up**: [https://dashboard.ngrok.com/signup](https://dashboard.ngrok.com/signup)
2. **Get auth token**: [https://dashboard.ngrok.com/get-started/your-authtoken](https://dashboard.ngrok.com/get-started/your-authtoken)
3. **Run setup** with your token

### URLs Structure
- **Frontend**: `https://eqtrader-app.ngrok.io`
- **Backend API**: `https://eqtrader-api.ngrok.io`
- **WebSocket**: `wss://eqtrader-api.ngrok.io/socket.io`
- **Dashboard**: `http://localhost:4040`

### Configuration
The installer creates `~/.ngrok2/ngrok.yml`:
```yaml
version: "2"
authtoken: YOUR_TOKEN
tunnels:
  frontend:
    addr: 3000
    proto: http
    subdomain: eqtrader-app
  backend:
    addr: 5000
    proto: http
    subdomain: eqtrader-api
```

### Service Management
```bash
# Check status
systemctl status trading-bot-tunnel.service

# View dashboard
open http://localhost:4040

# Restart tunnels
systemctl restart trading-bot-tunnel.service
```

---

## 🌐 3. LocalTunnel (Completely Free)

### Overview
Zero-configuration, completely free tunneling service with unlimited bandwidth and no account requirements.

### Features
- ✅ **Completely FREE** with unlimited bandwidth
- ✅ **Zero configuration** - works out of the box
- ✅ **No account required** - instant setup
- ✅ **NPX support** - no permanent installation needed
- ✅ **Custom subdomains** (when available)
- ✅ **SSL/TLS included** automatically

### Setup
```bash
# Default setup
curl -fsSL https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh | bash -s -- --tunnel-localtunnel

# Custom subdomain
curl -fsSL https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh | bash -s -- --tunnel-localtunnel myproject
```

### URLs Structure
- **Frontend**: `https://eqtrader-app-k7m9.loca.lt`
- **Backend API**: `https://eqtrader-api-k7m9.loca.lt`
- **WebSocket**: `wss://eqtrader-api-k7m9.loca.lt/socket.io`

*Note: Random suffix added for uniqueness*

### Manual Usage
```bash
# Install globally
npm install -g localtunnel

# Create tunnels
lt --port 3000 --subdomain myapp-frontend
lt --port 5000 --subdomain myapp-api
```

### Best Practices
- **Development**: Perfect for quick demos and testing
- **Sharing**: Great for showing work to clients
- **Cost-conscious**: Ideal when budget is a constraint
- **Simple projects**: Best for non-critical applications

---

## 🔒 4. Serveo SSH Tunneling

### Overview
SSH-based tunneling that requires no installation and works anywhere SSH is available.

### Features
- ✅ **No installation** required - uses SSH
- ✅ **Works everywhere** SSH is available
- ✅ **Simple port forwarding** mechanism
- ✅ **Minimal resource usage**
- ✅ **Secure by design** - uses SSH encryption
- ✅ **Custom subdomains** support

### Setup
```bash
# Default setup
curl -fsSL https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh | bash -s -- --tunnel-serveo

# Custom subdomain
curl -fsSL https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh | bash -s -- --tunnel-serveo myproject
```

### URLs Structure
- **Frontend**: `https://eqtrader-app-k7m9.serveo.net`
- **Backend API**: `https://eqtrader-api-k7m9.serveo.net`
- **WebSocket**: `wss://eqtrader-api-k7m9.serveo.net/socket.io`

### Manual SSH Commands
```bash
# Frontend tunnel
ssh -o StrictHostKeyChecking=no -R myapp-frontend:80:localhost:3000 serveo.net

# Backend tunnel
ssh -o StrictHostKeyChecking=no -R myapp-api:80:localhost:5000 serveo.net
```

### SSH Configuration
For persistent connections, add to `~/.ssh/config`:
```
Host serveo
    HostName serveo.net
    User serveo
    ServerAliveInterval 60
    ServerAliveCountMax 3
    RemoteForward myapp-frontend:80 localhost:3000
    RemoteForward myapp-api:80 localhost:5000
```

### Best Use Cases
- **SSH experts**: Familiar with SSH port forwarding
- **Minimal setups**: When you can't install additional software
- **Firewalled environments**: Where only SSH is allowed out
- **IoT/embedded**: Devices with SSH client only

---

## ☁️ 5. Cloudflare Tunnel (Enterprise)

### Overview
Enterprise-grade tunneling with global CDN, DDoS protection, and zero-trust security model.

### Features
- ✅ **Global CDN** with 200+ edge locations
- ✅ **DDoS protection** included automatically
- ✅ **Zero-trust security** model
- ✅ **Custom domains** (requires Cloudflare DNS)
- ✅ **Advanced analytics** and monitoring
- ✅ **Load balancing** and failover
- ✅ **Access controls** and authentication

### Prerequisites
- Domain managed by Cloudflare DNS
- Cloudflare account (free tier available)

### Setup
```bash
# With your domain
curl -fsSL https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh | bash -s -- --tunnel-cloudflare yourdomain.com

# Interactive domain input
curl -fsSL https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh | bash -s -- --tunnel-cloudflare
```

### URLs Structure
- **Frontend**: `https://app.yourdomain.com`
- **Backend API**: `https://api.yourdomain.com`
- **WebSocket**: `wss://api.yourdomain.com/socket.io`

### Configuration Process
1. **Authentication**: Browser login to Cloudflare
2. **Tunnel creation**: Unique tunnel with UUID
3. **DNS records**: Automatic CNAME creation
4. **Configuration**: `~/.cloudflared/config.yml`

### Example Config
```yaml
tunnel: 12345678-1234-1234-1234-123456789abc
credentials-file: ~/.cloudflared/12345678-1234-1234-1234-123456789abc.json

ingress:
  - hostname: app.yourdomain.com
    service: http://localhost:3000
  - hostname: api.yourdomain.com
    service: http://localhost:5000
  - service: http_status:404
```

### DNS Configuration
Cloudflare automatically creates:
```
app.yourdomain.com CNAME 12345678-1234-1234-1234-123456789abc.cfargotunnel.com
api.yourdomain.com CNAME 12345678-1234-1234-1234-123456789abc.cfargotunnel.com
```

### Best Use Cases
- **High-traffic production**: Websites with significant traffic
- **Enterprise security**: Zero-trust network requirements
- **Global audience**: Users worldwide needing fast access
- **DDoS concerns**: Applications requiring protection

---

## 🎪 6. PageKite Commercial

### Overview
Reliable commercial tunneling service with custom domains, professional support, and enterprise features.

### Features
- ✅ **Commercial reliability** with SLA
- ✅ **Custom domains** support
- ✅ **Professional support** team
- ✅ **Advanced authentication** mechanisms
- ✅ **Traffic statistics** and monitoring
- ✅ **Multiple protocol support** (HTTP, HTTPS, SSH)

### Prerequisites
- PageKite account: [https://pagekite.net/signup/](https://pagekite.net/signup/)
- Subscription plan based on usage

### Setup
```bash
# With your PageKite name
curl -fsSL https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh | bash -s -- --tunnel-pagekite yourname

# Interactive name input
curl -fsSL https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh | bash -s -- --tunnel-pagekite
```

### URLs Structure
- **Frontend**: `http://yourname-app.pagekite.me`
- **Backend API**: `http://yourname-api.pagekite.me`
- **WebSocket**: `ws://yourname-api.pagekite.me/socket.io`

### Configuration
Manual configuration in `~/.pagekite.d/10_account.rc`:
```ini
kitename   = yourname
kitesecret = your_pagekite_secret_from_account
```

### Service Command
```bash
pagekite --defaults \
  --service_on=http:yourname-app.pagekite.me:localhost:3000:your_secret \
  --service_on=http:yourname-api.pagekite.me:localhost:5000:your_secret
```

### Pricing Tiers
- **Personal**: $3/month - Basic features
- **Professional**: $8/month - Custom domains
- **Business**: $20/month - Advanced features
- **Enterprise**: Custom pricing - Full support

### Best Use Cases
- **Commercial applications**: Business-critical deployments
- **Professional support**: When you need guaranteed help
- **Custom domains**: Brand-specific URLs required
- **Compliance**: Regulated industries with support requirements

---

## 🔧 7. Telebit (Modern P2P)

### Overview
Modern peer-to-peer tunneling technology with end-to-end encryption and decentralized architecture.

### Features
- ✅ **End-to-end encryption** for maximum privacy
- ✅ **Decentralized P2P** architecture
- ✅ **Modern protocol** design
- ✅ **Custom domains** support
- ✅ **ACME/Let's Encrypt** integration
- ✅ **WebRTC support** for direct connections

### Setup
```bash
# With custom secret
curl -fsSL https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh | bash -s -- --tunnel-telebit your-secret-key

# Auto-generated secret
curl -fsSL https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh | bash -s -- --tunnel-telebit
```

### URLs Structure
- **Frontend**: `https://eqtrader-k7m9.telebit.cloud`
- **Backend API**: `https://eqtrader-api-k7m9.telebit.cloud`
- **WebSocket**: `wss://eqtrader-api-k7m9.telebit.cloud/socket.io`

### Configuration
Environment file `~/.telebit.env`:
```bash
SECRET=your-generated-secret-key
TUNNEL_RELAY_URL=https://telebit.cloud/
LOCALS=https:*:3000,https:*:5000
ACME_AGREE=true
ACME_EMAIL=admin@your-subdomain.telebit.cloud
```

### Advanced Configuration
```bash
telebit \
  --secret your-secret-key \
  --tunnel-relay-url https://telebit.cloud/ \
  --locals https:*:3000,https:*:5000 \
  --acme-agree \
  --acme-email your@email.com
```

### Best Use Cases
- **Privacy-focused**: When data privacy is paramount
- **Decentralized apps**: Blockchain or P2P applications
- **Modern architecture**: Cutting-edge technology requirements
- **Research projects**: Experimental or academic deployments

---

## 🛠️ Management Commands

### Universal Commands
These commands work regardless of your chosen tunnel platform:

```bash
# System management
trading-bot start              # Start all services
trading-bot stop               # Stop all services
trading-bot restart            # Restart all services
trading-bot status             # Show container status
trading-bot logs               # View and follow logs
trading-bot health             # Check API health
trading-bot update             # Update from repository

# Tunnel management
trading-bot tunnel status      # Show tunnel status
trading-bot tunnel start       # Start tunnels
trading-bot tunnel stop        # Stop tunnels
trading-bot tunnel restart     # Restart tunnels
```

### Systemd Services
```bash
# Main application
systemctl status quantconnect-trading-bot.service
systemctl start quantconnect-trading-bot.service
systemctl stop quantconnect-trading-bot.service

# Tunnel service (if applicable)
systemctl status trading-bot-tunnel.service
systemctl start trading-bot-tunnel.service
systemctl stop trading-bot-tunnel.service
```

### Health Monitoring
```bash
# Check tunnel connectivity
curl -f https://your-frontend-url/health

# Monitor tunnel logs
journalctl -u trading-bot-tunnel -f

# Check tunnel service status
systemctl is-active trading-bot-tunnel.service
```

---

## 🔍 Troubleshooting Guide

### Common Issues

#### 1. SSL Certificate Problems
```bash
# For VPS/Container environments
curl -fsSL https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh | bash -s -- --skip-ssl-snapd

# Skip SSL entirely
curl -fsSL https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh | bash -s -- --skip-ssl
```

#### 2. DDNS "Masih Sama!" Error
```bash
# This means "Still the same!" in Indonesian - IP hasn't changed
curl -fsSL https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh | bash -s -- --skip-ddns-error
```

#### 3. Tunnel Connection Issues
```bash
# Check tunnel service
systemctl status trading-bot-tunnel.service

# Restart tunnel
systemctl restart trading-bot-tunnel.service

# Check logs
journalctl -u trading-bot-tunnel -f
```

#### 4. Port Already in Use
```bash
# Find what's using the port
sudo lsof -i :3000
sudo lsof -i :5000

# Kill conflicting processes
sudo pkill -f "port 3000"
sudo pkill -f "port 5000"
```

#### 5. Container/VPS Compatibility
```bash
# For limited container environments
curl -fsSL https://raw.githubusercontent.com/szarastrefa/quantconnect-trading-bot/main/scripts/setup_ubuntu.sh | bash -s -- --tunnel-localtunnel --dev-mode --skip-ssl --skip-firewall
```

### Platform-Specific Troubleshooting

#### Ngrok Issues
```bash
# Invalid auth token
ngrok config add-authtoken YOUR_NEW_TOKEN

# Check account limits
open http://localhost:4040

# Reset configuration
rm -rf ~/.ngrok2/
```

#### LocalTunnel Issues
```bash
# Subdomain taken
lt --port 3000 --subdomain $(openssl rand -hex 4)-myapp

# Connection timeout
lt --port 3000 --local-host 127.0.0.1

# Force HTTP
lt --port 3000 --local-https false
```

#### Serveo Issues
```bash
# SSH key problems
ssh-keygen -R serveo.net

# Connection drops
ssh -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -R myapp:80:localhost:3000 serveo.net

# Subdomain conflicts
ssh -R $(date +%s)-myapp:80:localhost:3000 serveo.net
```

#### Cloudflare Issues
```bash
# Re-authenticate
cloudflared tunnel login

# Check DNS propagation
dig app.yourdomain.com
nslookup app.yourdomain.com

# Verify tunnel status
cloudflared tunnel list
cloudflared tunnel info your-tunnel-name
```

### Performance Optimization

#### 1. Connection Optimization
```bash
# Increase connection limits
echo '* soft nofile 65536' >> /etc/security/limits.conf
echo '* hard nofile 65536' >> /etc/security/limits.conf

# Optimize network parameters
echo 'net.core.somaxconn = 65536' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_max_syn_backlog = 65536' >> /etc/sysctl.conf
sysctl -p
```

#### 2. Tunnel Optimization
```bash
# For Ngrok - increase timeout
echo 'connect_timeout: 30s' >> ~/.ngrok2/ngrok.yml
echo 'heartbeat_interval: 1m' >> ~/.ngrok2/ngrok.yml

# For SSH tunnels - keep alive
echo 'ServerAliveInterval 60' >> ~/.ssh/config
echo 'ServerAliveCountMax 3' >> ~/.ssh/config
```

---

## 🚀 Best Practices

### Security
1. **Use HTTPS**: All tunnels provide SSL/TLS encryption
2. **Limit access**: Configure firewalls appropriately
3. **Monitor logs**: Regular log review for security events
4. **Update regularly**: Keep tunnel software updated
5. **Strong credentials**: Use secure passwords and tokens

### Reliability
1. **Health checks**: Monitor tunnel connectivity
2. **Auto-restart**: Configure service auto-restart
3. **Monitoring**: Set up alerting for failures
4. **Backup tunnels**: Consider multiple tunnel types
5. **Documentation**: Document your specific configuration

### Performance
1. **Location**: Choose tunnel servers close to users
2. **Bandwidth**: Consider tunnel bandwidth limits
3. **Caching**: Use CDN features when available
4. **Optimization**: Compress responses when possible
5. **Load balancing**: Distribute traffic across tunnels

---

## 📞 Support and Resources

### Official Documentation
- **Ngrok**: [https://ngrok.com/docs](https://ngrok.com/docs)
- **LocalTunnel**: [https://github.com/localtunnel/localtunnel](https://github.com/localtunnel/localtunnel)
- **Serveo**: [https://serveo.net](https://serveo.net)
- **Cloudflare**: [https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- **PageKite**: [https://pagekite.net/wiki/](https://pagekite.net/wiki/)
- **Telebit**: [https://telebit.cloud](https://telebit.cloud)

### Community Support
- **GitHub Issues**: [https://github.com/szarastrefa/quantconnect-trading-bot/issues](https://github.com/szarastrefa/quantconnect-trading-bot/issues)
- **Discussions**: [https://github.com/szarastrefa/quantconnect-trading-bot/discussions](https://github.com/szarastrefa/quantconnect-trading-bot/discussions)

### Quick Help
For immediate assistance, create an issue with:
1. **Tunnel type** you're using
2. **Error messages** (full logs)
3. **System information** (OS, version)
4. **Command used** for installation
5. **Expected vs actual** behavior

---

*This guide is part of the QuantConnect Trading Bot documentation. For more information, see the main [README.md](../README.md) file.*