# ZeroTier Toolkit Troubleshooting Guide

This guide helps you diagnose and resolve common issues with ZeroTier networks and the toolkit scripts.

## Table of Contents

- [Installation Issues](#installation-issues)
- [Configuration Issues](#configuration-issues)
- [Connectivity Issues](#connectivity-issues)
- [Routing Issues](#routing-issues)
- [Firewall Issues](#firewall-issues)
- [Performance Issues](#performance-issues)
- [Script Issues](#script-issues)

## Installation Issues

### ZeroTier won't install

**Symptoms:**
- Installation script fails
- GPG verification errors
- Package manager errors

**Solutions:**

1. **Check internet connectivity:**
   ```bash
   ping -c 3 8.8.8.8
   curl -I https://install.zerotier.com
   ```

2. **Verify GPG is installed:**
   ```bash
   which gpg
   # If not found, install it:
   sudo apt-get install gnupg  # Debian/Ubuntu
   sudo yum install gnupg      # RHEL/CentOS
   ```

3. **Try manual installation:**
   ```bash
   curl -s https://install.zerotier.com | sudo bash
   ```

4. **Check for conflicting services:**
   ```bash
   sudo systemctl status zerotier-one
   sudo netstat -tlnp | grep 9993
   ```

### Service won't start

**Symptoms:**
- `zerotier-cli info` fails
- Service is inactive

**Solutions:**

1. **Check service status:**
   ```bash
   sudo systemctl status zerotier-one
   sudo journalctl -u zerotier-one -n 50
   ```

2. **Restart service:**
   ```bash
   sudo systemctl restart zerotier-one
   sudo systemctl enable zerotier-one
   ```

3. **Check permissions:**
   ```bash
   ls -la /var/lib/zerotier-one/
   sudo chown -R root:root /var/lib/zerotier-one/
   ```

4. **Check port availability:**
   ```bash
   sudo ss -tlnp | grep 9993
   # Port 9993 should be free or used by zerotier-one
   ```

## Configuration Issues

### Can't join network

**Symptoms:**
- Network shows as "REQUESTING_CONFIGURATION"
- Network status is not "OK"

**Solutions:**

1. **Verify network ID:**
   ```bash
   # Network ID must be exactly 16 hexadecimal characters
   echo "a1b2c3d4e5f6a7b8" | wc -c  # Should output 17 (16 + newline)
   ```

2. **Authorize node on controller:**
   - Go to https://my.zerotier.com/network/YOUR_NETWORK_ID
   - Find your node in the members list
   - Check the "Auth" checkbox

3. **Check network status:**
   ```bash
   sudo zerotier-cli listnetworks
   sudo zerotier-cli peers
   ```

4. **Try leaving and rejoining:**
   ```bash
   sudo zerotier-cli leave YOUR_NETWORK_ID
   sleep 5
   sudo zerotier-cli join YOUR_NETWORK_ID
   ```

### Configuration script fails

**Symptoms:**
- zerotier-conf.sh reports errors
- Firewall rules don't apply

**Solutions:**

1. **Run diagnostics:**
   ```bash
   ./scripts/zerotier-diagnostics.sh --full
   ```

2. **Check interface names:**
   ```bash
   ip link show
   # Verify physical interface name (eth0, ens33, etc.)
   
   sudo zerotier-cli listnetworks
   # Verify ZeroTier interface name
   ```

3. **Try dry-run first:**
   ```bash
   ./scripts/zerotier-conf.sh --dry-run -n YOUR_NETWORK_ID
   ```

4. **Check existing configuration:**
   ```bash
   # Check existing firewall rules
   sudo iptables -L -n -v
   sudo iptables -t nat -L -n -v
   
   # Check IP forwarding
   cat /proc/sys/net/ipv4/ip_forward
   ```

## Connectivity Issues

### Can't reach other nodes

**Symptoms:**
- Ping fails between ZeroTier nodes
- No communication possible

**Solutions:**

1. **Run diagnostics:**
   ```bash
   ./scripts/zerotier-diagnostics.sh -p TARGET_IP_ADDRESS
   ```

2. **Check network status:**
   ```bash
   sudo zerotier-cli listnetworks
   # Status should be "OK"
   ```

3. **Check managed routes:**
   - Go to https://my.zerotier.com/network/YOUR_NETWORK_ID
   - Settings → Managed Routes
   - Verify routes are configured correctly

4. **Test direct connectivity:**
   ```bash
   # Get peer status
   sudo zerotier-cli listpeers
   
   # Ping ZeroTier interface
   ping -c 3 TARGET_ZT_IP
   ```

5. **Check firewall on both ends:**
   ```bash
   # Temporarily disable firewall for testing
   sudo systemctl stop firewalld  # or
   sudo ufw disable
   
   # Test connectivity
   ping TARGET_IP
   
   # Re-enable firewall
   sudo systemctl start firewalld  # or
   sudo ufw enable
   ```

### Can't connect to ZeroTier planet

**Symptoms:**
- No peers connected
- "REQUESTING_CONFIGURATION" status persists

**Solutions:**

1. **Check internet connectivity:**
   ```bash
   ping -c 3 8.8.8.8
   curl -I https://my.zerotier.com
   ```

2. **Check firewall allows ZeroTier:**
   ```bash
   # ZeroTier uses UDP port 9993
   sudo ufw allow 9993/udp  # Ubuntu/Debian
   sudo firewall-cmd --add-port=9993/udp --permanent  # RHEL/CentOS
   sudo firewall-cmd --reload
   ```

3. **Test planet connectivity:**
   ```bash
   ./scripts/zerotier-diagnostics.sh -v
   # Check "ZeroTier Infrastructure Connectivity" section
   ```

4. **Check for NAT/proxy issues:**
   - ZeroTier works through most NATs but may have issues with symmetric NAT
   - Consider using a moon (custom root server) for difficult networks

## Routing Issues

### Can't reach physical network from ZeroTier

**Symptoms:**
- Can reach gateway but not devices behind it
- No route to physical subnet

**Solutions:**

1. **Verify managed routes:**
   - Go to https://my.zerotier.com/network/YOUR_NETWORK_ID
   - Settings → Managed Routes
   - Add route: Destination: 192.168.1.0/24, Via: GATEWAY_ZT_IP

2. **Check IP forwarding on gateway:**
   ```bash
   cat /proc/sys/net/ipv4/ip_forward
   # Should output: 1
   
   # If not:
   sudo sysctl -w net.ipv4.ip_forward=1
   sudo sysctl -p
   ```

3. **Verify NAT rules:**
   ```bash
   sudo iptables -t nat -L -n -v
   # Should see MASQUERADE rule for physical interface
   
   # If missing:
   sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
   ```

4. **Check routing table:**
   ```bash
   ip route show
   # Should see route to ZeroTier network
   ```

5. **Test from gateway:**
   ```bash
   # From gateway node, test reaching physical network
   ping 192.168.1.1
   
   # From ZeroTier node, test via gateway
   traceroute 192.168.1.1
   ```

### Asymmetric routing issues

**Symptoms:**
- One-way connectivity
- Packets reach destination but replies don't return

**Solutions:**

1. **Check return routes:**
   ```bash
   # On physical network devices, add route back through ZT gateway
   ip route add 172.27.0.0/16 via 192.168.1.100  # Gateway IP
   ```

2. **Use smaller subnet in managed routes:**
   - Use /23 instead of /24 to make ZT route less preferred for local traffic
   - Example: 192.168.0.0/23 instead of 192.168.1.0/24

3. **Verify source NAT:**
   ```bash
   # Check if NAT is properly configured
   sudo iptables -t nat -L POSTROUTING -n -v
   ```

## Firewall Issues

### Firewall blocking ZeroTier traffic

**Symptoms:**
- Configuration works when firewall is disabled
- Traffic blocked between networks

**Solutions:**

1. **Check firewall type:**
   ```bash
   ./scripts/zerotier-diagnostics.sh -v
   # Shows detected firewall system
   ```

2. **Reconfigure with correct firewall:**
   ```bash
   # Let script detect and configure firewall
   ./scripts/zerotier-conf.sh -n YOUR_NETWORK_ID
   ```

3. **Manual firewall configuration:**

   **For iptables:**
   ```bash
   sudo iptables -A FORWARD -i zt+ -j ACCEPT
   sudo iptables -A FORWARD -o zt+ -j ACCEPT
   sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
   ```

   **For firewalld:**
   ```bash
   sudo firewall-cmd --permanent --zone=trusted --add-interface=zt+
   sudo firewall-cmd --permanent --add-masquerade
   sudo firewall-cmd --reload
   ```

   **For ufw:**
   ```bash
   sudo ufw allow in on zt+
   sudo ufw allow out on zt+
   ```

4. **Check FORWARD chain policy:**
   ```bash
   sudo iptables -L FORWARD -n -v
   # Default policy should allow or have specific rules
   ```

## Performance Issues

### Slow connection between nodes

**Symptoms:**
- High latency
- Low throughput
- Packet loss

**Solutions:**

1. **Check peer connectivity:**
   ```bash
   sudo zerotier-cli listpeers
   # Look for DIRECT connections, RELAY means slower path
   ```

2. **Test with iperf:**
   ```bash
   # On server:
   iperf3 -s
   
   # On client:
   iperf3 -c SERVER_ZT_IP
   ```

3. **Check MTU settings:**
   ```bash
   ip link show zt+
   # ZeroTier default MTU is 2800
   
   # If issues, try reducing:
   sudo ip link set zt7nnig26 mtu 1400
   ```

4. **Monitor with diagnostics:**
   ```bash
   ./scripts/zerotier-monitor.sh -i 10 -v
   ```

### High CPU usage

**Symptoms:**
- zerotier-one using excessive CPU

**Solutions:**

1. **Check for packet storms:**
   ```bash
   sudo tcpdump -i zt7nnig26 -c 100
   # Look for unusual traffic patterns
   ```

2. **Restart service:**
   ```bash
   sudo systemctl restart zerotier-one
   ```

3. **Check for loops:**
   ```bash
   # Ensure no routing loops exist
   ip route show
   sudo iptables -L -n -v | grep zt
   ```

## Script Issues

### Script won't run

**Symptoms:**
- "Permission denied" errors
- "Command not found" errors

**Solutions:**

1. **Make executable:**
   ```bash
   chmod +x scripts/*.sh
   ```

2. **Run with bash:**
   ```bash
   bash scripts/zerotier-install.sh
   ```

3. **Check bash version:**
   ```bash
   bash --version
   # Need bash 4.0 or later
   ```

4. **Check dependencies:**
   ```bash
   which curl gpg iptables ip
   ```

### Script fails with errors

**Symptoms:**
- Unexpected errors during execution

**Solutions:**

1. **Run in verbose mode:**
   ```bash
   ./scripts/zerotier-conf.sh -v -n YOUR_NETWORK_ID
   ```

2. **Check logs:**
   ```bash
   # Scripts create logs in /tmp
   ls -lt /tmp/zerotier-*.log
   tail -50 /tmp/zerotier-conf-*.log
   ```

3. **Use dry-run mode:**
   ```bash
   ./scripts/zerotier-conf.sh --dry-run -n YOUR_NETWORK_ID
   ```

4. **Check for running processes:**
   ```bash
   ps aux | grep zerotier
   ```

## Getting Help

If you're still experiencing issues:

1. **Run full diagnostics:**
   ```bash
   ./scripts/zerotier-diagnostics.sh --full -o /tmp/diagnostics.txt
   ```

2. **Collect logs:**
   ```bash
   sudo journalctl -u zerotier-one > /tmp/zerotier-service.log
   ```

3. **Check ZeroTier status:**
   ```bash
   sudo zerotier-cli info
   sudo zerotier-cli listnetworks
   sudo zerotier-cli listpeers
   ```

4. **Open an issue:**
   - Go to https://github.com/cywf/zerotier-toolkit/issues
   - Provide:
     - Your OS and version
     - ZeroTier version
     - Full diagnostic output
     - Steps to reproduce
     - Error messages

5. **Community resources:**
   - [ZeroTier Discussions](https://github.com/cywf/zerotier-toolkit/discussions)
   - [ZeroTier Official Docs](https://docs.zerotier.com/)
   - [ZeroTier Community](https://discuss.zerotier.com/)

## Prevention Best Practices

1. **Always backup before changes:**
   ```bash
   # Scripts do this automatically, but manual backup:
   sudo cp /etc/sysctl.conf /etc/sysctl.conf.backup
   sudo iptables-save > /tmp/iptables.backup
   ```

2. **Test in dry-run mode first:**
   ```bash
   ./scripts/zerotier-conf.sh --dry-run -n YOUR_NETWORK_ID
   ```

3. **Use configuration files:**
   ```bash
   # Easier to track and replicate
   ./scripts/zerotier-conf.sh -c gateway.conf
   ```

4. **Monitor your networks:**
   ```bash
   # Set up continuous monitoring
   ./scripts/zerotier-monitor.sh -i 60 -l /var/log/zt-monitor.log &
   ```

5. **Document your setup:**
   - Save configuration files
   - Document network topology
   - Keep track of network IDs and routes

---

**Still need help?** Open an issue at https://github.com/cywf/zerotier-toolkit/issues
