# ZeroTier Toolkit Quick Reference

Quick reference guide for common tasks with ZeroTier Toolkit.

## 🚀 Installation

```bash
# Install ZeroTier
./scripts/zerotier-install.sh

# Install and join network
./scripts/zerotier-install.sh -n YOUR_NETWORK_ID

# Verbose installation with logging
./scripts/zerotier-install.sh -v -l /var/log/zerotier-install.log
```

## 🔧 Gateway Configuration

```bash
# Interactive setup
./scripts/zerotier-conf.sh

# Configure with parameters
./scripts/zerotier-conf.sh -n NETWORK_ID -p eth0 -s 192.168.1.0/24

# Use configuration file
./scripts/zerotier-conf.sh -c examples/gateway.conf

# Enable IPv6
./scripts/zerotier-conf.sh -n NETWORK_ID --ipv6

# Dry-run (preview changes)
./scripts/zerotier-conf.sh --dry-run -n NETWORK_ID
```

## 🔍 Diagnostics

```bash
# Quick check
./scripts/zerotier-diagnostics.sh

# Full diagnostic report
./scripts/zerotier-diagnostics.sh --full

# Save report to file
./scripts/zerotier-diagnostics.sh --full -o report.txt

# Check specific network
./scripts/zerotier-diagnostics.sh -n NETWORK_ID

# Test connectivity to peer
./scripts/zerotier-diagnostics.sh -p PEER_IP
```

## 📊 Monitoring

```bash
# Continuous monitoring (60s interval)
./scripts/zerotier-monitor.sh

# Custom interval (30s)
./scripts/zerotier-monitor.sh -i 30

# One-shot health check
./scripts/zerotier-monitor.sh --once

# With logging
./scripts/zerotier-monitor.sh -l /var/log/zt-monitor.log

# With webhook alerts
./scripts/zerotier-monitor.sh --alert-webhook https://hooks.example.com/zt
```

## 🗺️ Topology Management

```bash
# Validate configuration
./scripts/zerotier-topology.sh -c topology.conf validate

# Deploy topology
./scripts/zerotier-topology.sh -c topology.conf deploy

# Check status
./scripts/zerotier-topology.sh -c topology.conf status

# Cleanup
./scripts/zerotier-topology.sh -c topology.conf cleanup

# Dry-run deployment
./scripts/zerotier-topology.sh -c topology.conf -d deploy
```

## 📝 Common Tasks

### Setup Gateway/Router

1. Install ZeroTier:
   ```bash
   ./scripts/zerotier-install.sh
   ```

2. Configure gateway:
   ```bash
   ./scripts/zerotier-conf.sh -n NETWORK_ID -p eth0 -s 192.168.1.0/24
   ```

3. Authorize node at [my.zerotier.com](https://my.zerotier.com)

4. Add managed route:
   - Destination: `192.168.1.0/24`
   - Via: `<node's ZT IP>`

### Join Multiple Networks

```bash
sudo zerotier-cli join NETWORK_ID_1
sudo zerotier-cli join NETWORK_ID_2
sudo zerotier-cli listnetworks
```

### Check Status

```bash
# Node info
sudo zerotier-cli info

# List networks
sudo zerotier-cli listnetworks

# List peers
sudo zerotier-cli listpeers

# Run diagnostics
./scripts/zerotier-diagnostics.sh
```

### Troubleshoot Issues

1. Run diagnostics:
   ```bash
   ./scripts/zerotier-diagnostics.sh --full -o /tmp/diagnostic.txt
   ```

2. Check logs:
   ```bash
   sudo journalctl -u zerotier-one -n 100
   ```

3. Verify authorization:
   ```bash
   sudo zerotier-cli listnetworks
   # Status should be "OK"
   ```

4. Test connectivity:
   ```bash
   ./scripts/zerotier-diagnostics.sh -p PEER_IP
   ```

### Uninstall

```bash
# Stop service
sudo systemctl stop zerotier-one

# Uninstall (Ubuntu/Debian)
sudo apt-get remove zerotier-one

# Uninstall (RHEL/CentOS/Fedora)
sudo yum remove zerotier-one

# Remove data
sudo rm -rf /var/lib/zerotier-one
```

## 🛠️ Firewall Quick Commands

### iptables

```bash
# View rules
sudo iptables -L -n -v
sudo iptables -t nat -L -n -v

# Save rules (Ubuntu/Debian)
sudo iptables-save | sudo tee /etc/iptables/rules.v4

# Save rules (RHEL/CentOS)
sudo iptables-save | sudo tee /etc/sysconfig/iptables

# Flush rules (be careful!)
sudo iptables -F
sudo iptables -t nat -F
```

### firewalld

```bash
# View configuration
sudo firewall-cmd --list-all

# Add ZeroTier port
sudo firewall-cmd --permanent --add-port=9993/udp
sudo firewall-cmd --reload

# Add masquerading
sudo firewall-cmd --permanent --add-masquerade
sudo firewall-cmd --reload

# Add interface to trusted zone
sudo firewall-cmd --permanent --zone=trusted --add-interface=zt+
sudo firewall-cmd --reload
```

### ufw

```bash
# View status
sudo ufw status verbose

# Allow ZeroTier
sudo ufw allow 9993/udp

# Allow ZeroTier interfaces
sudo ufw allow in on zt+
sudo ufw allow out on zt+
```

## 🌐 Network Commands

```bash
# View interfaces
ip link show
ip addr show

# View routes
ip route show
ip -6 route show

# Test connectivity
ping -c 3 PEER_IP
traceroute PEER_IP

# View listening ports
sudo ss -tlnp | grep 9993
sudo netstat -tlnp | grep 9993
```

## 📋 Configuration Files

### Gateway Configuration

Located in `examples/gateway.conf`:
```bash
ZT_NETWORK_ID=YOUR_NETWORK_ID
PHY_IFACE=eth0
PHY_SUBNET=192.168.1.0/24
ENABLE_IPV6=0
```

### Topology Configuration

Located in `examples/hub-spoke-topology.conf`:
```bash
type=hub-spoke
network=NETWORK_ID_1
network=NETWORK_ID_2
enable_forwarding=true
nat=true
```

## 🔐 Security Best Practices

1. **Always test in dry-run mode first**
2. **Keep backups** of configurations
3. **Use strong network IDs** (let ZeroTier generate)
4. **Authorize only known devices** on your network
5. **Monitor regularly** with zerotier-monitor.sh
6. **Keep ZeroTier updated**
7. **Review firewall rules** periodically
8. **Document your setup**

## 📊 Monitoring Checklist

- [ ] ZeroTier service is running
- [ ] Networks show status "OK"
- [ ] Peers are connected (not all RELAY)
- [ ] IP forwarding enabled (for gateways)
- [ ] Firewall rules configured correctly
- [ ] Managed routes set on controller
- [ ] Nodes authorized on controller

## 🆘 Emergency Commands

```bash
# Restart ZeroTier
sudo systemctl restart zerotier-one

# Check service status
sudo systemctl status zerotier-one

# View recent logs
sudo journalctl -u zerotier-one -n 50

# Leave network
sudo zerotier-cli leave NETWORK_ID

# Rejoin network
sudo zerotier-cli join NETWORK_ID

# Reset (be careful!)
sudo systemctl stop zerotier-one
sudo rm -rf /var/lib/zerotier-one/identity.*
sudo systemctl start zerotier-one
```

## 📞 Getting Help

- 📖 [Full Documentation](scripts/README.md)
- 🐛 [Troubleshooting Guide](TROUBLESHOOTING.md)
- 💬 [GitHub Discussions](https://github.com/cywf/zerotier-toolkit/discussions)
- 🐛 [Issue Tracker](https://github.com/cywf/zerotier-toolkit/issues)
- 🌐 [ZeroTier Docs](https://docs.zerotier.com/)

## 📝 Environment Variables

```bash
# Custom log location
LOG_FILE=/var/log/zerotier-custom.log

# Dry-run mode
DRY_RUN=1

# Verbose mode
VERBOSE=1
```

## 🔄 Update Toolkit

```bash
cd zerotier-toolkit
git pull origin main
chmod +x scripts/*.sh
./tests/test-scripts.sh
```

---

For detailed information, see [README.md](README.md) and [scripts/README.md](scripts/README.md)
