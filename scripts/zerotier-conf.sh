#!/bin/bash

## ZeroTier configuration script to configure it as a basic IPv4 NAT router


# Set Variables
ZT_NETWORK_ID="your_network_id"
ZT_GATEWAY_IP="your_gateway_ip"
ZT_NETWORK_IP="your_network_ip"

# Install ZeroTier
curl -s https://install.zerotier.com | bash

# Configure ZeroTier as a basic IPv4 NAT router
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

# Install iptables-services
yum install -y iptables-services
systemctl enable iptables
systemctl start iptables

# Configure iptables
echo "*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -o eth0 -s $ZT_NETWORK_IP -j SNAT --to-source $ZT_GATEWAY_IP
COMMIT
*filter
:INPUT ACCEPT [0:0]
:FORWARD DROP [0:0]
-A FORWARD -i zt+ -s $ZT_NETWORK_IP -d 0.0.0.0/0 -j ACCEPT
-A FORWARD -i eth0 -s 0.0.0.0/0 -d $ZT_NETWORK_IP -j ACCEPT
:OUTPUT ACCEPT [0:0]
COMMIT" >> /etc/sysconfig/iptables

# Add default route
sudo zerotier-cli set $ZT_NETWORK_ID allowDefault=1

# Allow Default Route Override on Member Devices
sudo zerotier-cli set $ZT_NETWORK_ID allowDefault=1

