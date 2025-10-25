# ZeroTier Toolkit Scripts

This directory contains powerful scripts for installing, configuring, and managing ZeroTier networks with enterprise-grade features.

## 🚀 Scripts Overview

### 1. zerotier-install.sh
**Robust ZeroTier installer with multi-distribution support**

- ✅ Automatic dependency checking and installation
- ✅ GPG signature verification for security
- ✅ Support for Debian/Ubuntu, RHEL/CentOS/Fedora, Arch Linux
- ✅ Automatic network joining after installation
- ✅ Dry-run mode for safe testing
- ✅ Comprehensive logging and error handling

**Usage:**
```bash
# Basic installation
./zerotier-install.sh

# Install and auto-join network
./zerotier-install.sh -n a1b2c3d4e5f6a7b8

# Dry-run to preview changes
./zerotier-install.sh --dry-run

# Verbose mode with logging
./zerotier-install.sh -v -l /var/log/zerotier-install.log
```

### 2. zerotier-conf.sh
**Advanced network configuration for gateway/router deployments**

- ✅ Multi-distribution firewall support (iptables, firewalld, ufw, nftables)
- ✅ Automatic interface detection
- ✅ IPv4 and IPv6 forwarding
- ✅ NAT/MASQUERADE configuration
- ✅ Configuration backup and rollback
- ✅ Interactive and non-interactive modes
- ✅ Configuration file support

**Usage:**
```bash
# Interactive configuration
./zerotier-conf.sh

# Configure with specific parameters
./zerotier-conf.sh -n a1b2c3d4e5f6a7b8 -p eth0 -s 192.168.1.0/24

# Use configuration file
./zerotier-conf.sh -c ../examples/gateway.conf

# Enable IPv6 forwarding
./zerotier-conf.sh -n a1b2c3d4e5f6a7b8 --ipv6

# Dry-run mode
./zerotier-conf.sh -n a1b2c3d4e5f6a7b8 --dry-run
```

### 3. zerotier-diagnostics.sh
**Comprehensive diagnostic tool for troubleshooting**

- ✅ Service and installation checks
- ✅ Network membership validation
- ✅ Peer connectivity testing
- ✅ Firewall and routing inspection
- ✅ Interface status monitoring
- ✅ DNS resolution testing
- ✅ ZeroTier infrastructure connectivity checks
- ✅ Detailed report generation

**Usage:**
```bash
# Quick diagnostics
./zerotier-diagnostics.sh

# Full diagnostic report
./zerotier-diagnostics.sh --full

# Diagnose specific network
./zerotier-diagnostics.sh -n a1b2c3d4e5f6a7b8

# Test connectivity to peer
./zerotier-diagnostics.sh -p 172.27.0.5

# Save report to file
./zerotier-diagnostics.sh --full -o /tmp/zt-report.txt
```

### 4. zerotier-monitor.sh
**Network health monitoring with alerting**

- ✅ Continuous or one-shot monitoring
- ✅ Service health checks
- ✅ Network status monitoring
- ✅ Peer connectivity tracking
- ✅ Email alerts (via mail/mailx)
- ✅ Webhook alerts for integration with monitoring systems
- ✅ Configurable check intervals
- ✅ Logging support

**Usage:**
```bash
# Continuous monitoring (60s interval)
./zerotier-monitor.sh

# Monitor with 30-second interval
./zerotier-monitor.sh -i 30

# One-shot health check
./zerotier-monitor.sh --once

# Monitor specific network with logging
./zerotier-monitor.sh -n a1b2c3d4e5f6a7b8 -l /var/log/zt-monitor.log

# Enable webhook alerts
./zerotier-monitor.sh --alert-webhook https://hooks.example.com/zerotier
```

### 5. zerotier-topology.sh
**Advanced topology manager for complex deployments**

- ✅ Hub-and-spoke topology deployment
- ✅ Mesh topology configuration
- ✅ Multi-site network management
- ✅ Configuration validation
- ✅ Topology status reporting
- ✅ Automated cleanup

**Usage:**
```bash
# Validate topology configuration
./zerotier-topology.sh -c ../examples/hub-spoke-topology.conf validate

# Deploy hub-and-spoke topology
./zerotier-topology.sh -c ../examples/hub-spoke-topology.conf deploy

# Check topology status
./zerotier-topology.sh -c ../examples/hub-spoke-topology.conf status

# Dry-run deployment
./zerotier-topology.sh -c ../examples/mesh-topology.conf -d deploy

# Cleanup topology
./zerotier-topology.sh -c ../examples/hub-spoke-topology.conf cleanup
```

## 📋 Common Workflows

### Setting Up a Gateway/Router

1. Install ZeroTier:
   ```bash
   ./zerotier-install.sh
   ```

2. Configure as gateway:
   ```bash
   ./zerotier-conf.sh -n YOUR_NETWORK_ID -p eth0 -s 192.168.1.0/24
   ```

3. Authorize the node at https://my.zerotier.com

4. Add managed route on ZeroTier controller:
   - Destination: `192.168.1.0/24`
   - Via: `<node's ZeroTier IP>`

5. Verify with diagnostics:
   ```bash
   ./zerotier-diagnostics.sh --full
   ```

### Deploying Hub-and-Spoke Topology

1. Create or use example configuration:
   ```bash
   cp ../examples/hub-spoke-topology.conf my-topology.conf
   # Edit my-topology.conf with your network IDs
   ```

2. Validate configuration:
   ```bash
   ./zerotier-topology.sh -c my-topology.conf validate
   ```

3. Deploy topology:
   ```bash
   ./zerotier-topology.sh -c my-topology.conf deploy
   ```

4. Monitor the deployment:
   ```bash
   ./zerotier-monitor.sh --once
   ```

### Troubleshooting Network Issues

1. Run diagnostics:
   ```bash
   ./zerotier-diagnostics.sh --full -o /tmp/diagnostics.txt
   ```

2. Check specific network:
   ```bash
   ./zerotier-diagnostics.sh -n YOUR_NETWORK_ID -v
   ```

3. Test peer connectivity:
   ```bash
   ./zerotier-diagnostics.sh -p PEER_IP_ADDRESS
   ```

4. Monitor for issues:
   ```bash
   ./zerotier-monitor.sh -i 30 -l /var/log/zt-monitor.log
   ```

## 🔧 Advanced Features

### Configuration Files

All scripts support configuration files for repeatable deployments. See `../examples/` for templates.

### Dry-Run Mode

Test changes without applying them:
```bash
./zerotier-conf.sh --dry-run -n YOUR_NETWORK_ID
./zerotier-topology.sh -d -c topology.conf deploy
```

### Backup and Rollback

`zerotier-conf.sh` automatically backs up configurations to `/var/backup/zerotier-conf-TIMESTAMP/`

### Multi-Distribution Support

All scripts automatically detect and work with:
- Debian/Ubuntu (apt, iptables, ufw)
- RHEL/CentOS/Fedora/Rocky/AlmaLinux (yum/dnf, firewalld)
- Arch/Manjaro (pacman)

### IPv6 Support

Enable IPv6 forwarding:
```bash
./zerotier-conf.sh -n YOUR_NETWORK_ID --ipv6
```

### Logging

Most scripts support logging:
```bash
./zerotier-install.sh -l /var/log/zerotier-install.log
./zerotier-monitor.sh -l /var/log/zerotier-monitor.log
```

### Alerting

Set up monitoring with alerts:
```bash
# Email alerts
./zerotier-monitor.sh --alert-email admin@example.com

# Webhook alerts (Slack, Discord, etc.)
./zerotier-monitor.sh --alert-webhook https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

## 🛡️ Security Features

- ✅ GPG signature verification for ZeroTier installation
- ✅ Input validation for network IDs and parameters
- ✅ Automatic backup before configuration changes
- ✅ Firewall rules validation
- ✅ Safe error handling and rollback capability
- ✅ Root/sudo privilege checking

## 📊 System Requirements

- Linux operating system (Debian/Ubuntu, RHEL/CentOS, Fedora, Arch)
- Bash 4.0 or later
- Root or sudo access
- Internet connectivity for ZeroTier installation
- `curl` and `gpg` for installation (auto-installed if missing)

## 🔍 Troubleshooting

### Script won't run
```bash
# Make sure scripts are executable
chmod +x zerotier-*.sh

# Check syntax
bash -n zerotier-install.sh
```

### Permission denied
```bash
# Run with sudo
sudo ./zerotier-conf.sh -n YOUR_NETWORK_ID
```

### Network not connecting
```bash
# Run diagnostics
./zerotier-diagnostics.sh --full

# Check if authorized
sudo zerotier-cli listnetworks
# Status should be "OK"
```

### Firewall blocking traffic
```bash
# Check firewall status
./zerotier-diagnostics.sh -v

# Reconfigure with correct interface
./zerotier-conf.sh -n YOUR_NETWORK_ID -p CORRECT_INTERFACE
```

## 📚 Additional Resources

- [ZeroTier Documentation](https://docs.zerotier.com/)
- [ZeroTier Manual](https://www.zerotier.com/manual/)
- [Networking Guides](../networking/)
- [Example Configurations](../examples/)

## 💡 Tips and Best Practices

1. **Always test in dry-run mode first** before making changes to production systems
2. **Keep backups** of your configurations (they're in `/var/backup/zerotier-conf-*`)
3. **Monitor your networks** regularly with `zerotier-monitor.sh`
4. **Use configuration files** for complex deployments to ensure consistency
5. **Run diagnostics** after any configuration change
6. **Document your topology** by saving configuration files
7. **Set up alerting** for production networks
8. **Test connectivity** after deployment using the diagnostics script

## 🤝 Contributing

Found a bug or have a feature request? Please open an issue on the [GitHub repository](https://github.com/cywf/zerotier-toolkit).

## 📝 License

See the [LICENSE](../LICENSE) file for details.
