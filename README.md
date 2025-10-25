# 🌐 **ZeroTier Toolkit**

A powerful, enterprise-grade suite designed to empower network & system administrators! 🛠️ With this toolkit, seamlessly build, configure, deploy, and troubleshoot ZeroTier networks with confidence and reliability. 🚀💡

## ✨ Features

- 🔧 **Robust Installation Scripts** - Multi-distribution support with automatic dependency management
- 🌐 **Advanced Network Configuration** - Gateway, NAT, and routing setup with multiple firewall systems
- 🔍 **Comprehensive Diagnostics** - Troubleshoot network issues with detailed analysis
- 📊 **Health Monitoring** - Continuous monitoring with alerting capabilities
- 🗺️ **Topology Management** - Deploy complex network topologies (hub-spoke, mesh, multi-site)
- 🛡️ **Security First** - Input validation, GPG verification, backup/rollback support
- 📝 **Extensive Logging** - Track all operations with detailed logs
- 🐧 **Cross-Platform** - Support for Debian, Ubuntu, RHEL, CentOS, Fedora, Arch Linux

## 🎯 Goals of the Project

- **Simplicity**: Provide easy-to-use scripts and tools that simplify the process of setting up and managing ZeroTier networks.
  
- **Robustness**: Deliver production-ready tools with comprehensive error handling, logging, and recovery mechanisms.
  
- **Flexibility**: Support complex network topologies and advanced configurations for enterprise deployments.
  
- **Education**: Offer comprehensive documentation and guides to help administrators understand the nuances of ZeroTier and how to leverage its features effectively.
  
- **Community Engagement**: Foster a community where users can share their experiences, ask questions, and contribute to the toolkit's growth.
  
- **Continuous Improvement**: Regularly update the toolkit with new features, enhancements, and bug fixes based on community feedback and technological advancements.

## 🚀 Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/cywf/zerotier-toolkit.git
cd zerotier-toolkit

# Make scripts executable
chmod +x scripts/*.sh

# Install ZeroTier
./scripts/zerotier-install.sh
```

### Basic Gateway Setup

```bash
# Configure as a gateway/router
./scripts/zerotier-conf.sh -n YOUR_NETWORK_ID -p eth0 -s 192.168.1.0/24

# Run diagnostics
./scripts/zerotier-diagnostics.sh --full
```

### Monitor Network Health

```bash
# Continuous monitoring
./scripts/zerotier-monitor.sh -i 30

# One-shot health check
./scripts/zerotier-monitor.sh --once
```

## 📚 Documentation

### Scripts

- **[zerotier-install.sh](scripts/)** - Robust ZeroTier installer with multi-distribution support
- **[zerotier-conf.sh](scripts/)** - Advanced gateway/router configuration
- **[zerotier-diagnostics.sh](scripts/)** - Comprehensive diagnostic tool
- **[zerotier-monitor.sh](scripts/)** - Network health monitoring with alerts
- **[zerotier-topology.sh](scripts/)** - Complex topology deployment and management

📖 **[Complete Scripts Documentation](scripts/README.md)**

### Networking Guides

- [Route between ZeroTier and Physical Networks](networking/route-between-zerotier-and-physical-networks.md)
- [Private Root Servers](networking/private-root-servers.md)

### Examples

- [Gateway Configuration](examples/gateway.conf)
- [Hub-and-Spoke Topology](examples/hub-spoke-topology.conf)
- [Mesh Topology](examples/mesh-topology.conf)

## 💡 Use Cases

### Simple Home Network Gateway
Connect your home devices to a ZeroTier network for remote access.

### Enterprise Hub-and-Spoke
Deploy a central hub that routes traffic between multiple spoke sites.

### Multi-Site Mesh Network
Connect multiple office locations with full mesh connectivity.

### Development/Testing Environment
Quickly spin up isolated network environments for testing.

### Remote Site Access
Securely access remote sites without exposing services to the internet.

## 🔧 Advanced Features

### Configuration Files
Use configuration files for repeatable, automated deployments:
```bash
./scripts/zerotier-conf.sh -c examples/gateway.conf
```

### Dry-Run Mode
Preview changes without applying them:
```bash
./scripts/zerotier-conf.sh --dry-run -n YOUR_NETWORK_ID
```

### IPv6 Support
Enable IPv6 forwarding and routing:
```bash
./scripts/zerotier-conf.sh -n YOUR_NETWORK_ID --ipv6
```

### Automated Monitoring
Set up continuous monitoring with alerts:
```bash
./scripts/zerotier-monitor.sh --alert-webhook https://your-webhook-url
```

### Multi-Firewall Support
Automatically detects and configures:
- iptables (traditional)
- firewalld (RHEL/CentOS)
- ufw (Ubuntu/Debian)
- nftables (modern Linux)

## 🛡️ Security

- ✅ GPG signature verification for ZeroTier installation
- ✅ Input validation and sanity checks
- ✅ Automatic configuration backups
- ✅ Secure default configurations
- ✅ Root/sudo privilege verification
- ✅ Safe error handling and rollback

## 📊 System Requirements

- Linux OS (Debian/Ubuntu, RHEL/CentOS/Fedora, Arch)
- Bash 4.0+
- Root or sudo access
- Internet connectivity
- Basic networking tools (auto-installed if missing)


## 🤝 Contributing

We welcome contributions from the community! Whether it's a bug report, feature request, or a code contribution, your input is valuable to us.

### How to Contribute

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Test your changes thoroughly
4. Commit your changes (`git commit -m 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

### Reporting Issues

Please use the [GitHub issue tracker](https://github.com/cywf/zerotier-toolkit/issues) to report bugs or request features.

## 📣 Feedback

Your feedback is crucial for the continuous improvement of the toolkit. If you have any suggestions, issues, or ideas, please:

- 🐛 Open an [issue](https://github.com/cywf/zerotier-toolkit/issues)
- 💬 Join our [discussion board](https://github.com/cywf/zerotier-toolkit/discussions)
- ⭐ Star the repository if you find it useful!

## 📄 License

This project is licensed under the terms specified in the [LICENSE](LICENSE) file.

## 🙏 Acknowledgments

- [ZeroTier, Inc.](https://www.zerotier.com/) for creating an amazing networking platform
- All contributors who have helped improve this toolkit
- The open-source community for continuous inspiration

## 📞 Support

- 📖 [Documentation](scripts/README.md)
- 💬 [Discussions](https://github.com/cywf/zerotier-toolkit/discussions)
- 🐛 [Issue Tracker](https://github.com/cywf/zerotier-toolkit/issues)
- 🌐 [ZeroTier Official Docs](https://docs.zerotier.com/)

---

**Made with ❤️ for the ZeroTier community**
