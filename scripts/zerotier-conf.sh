#!/bin/bash

#####################################################################
# ZeroTier Network Configuration Script
# 
# Configure ZeroTier as a NAT router/gateway with advanced features
# including support for multiple distributions, IPv6, various firewall
# systems, and complex network topologies.
#
# Usage: ./zerotier-conf.sh [OPTIONS]
#
# Options:
#   -h, --help              Show this help message
#   -v, --verbose           Enable verbose output
#   -d, --dry-run           Show what would be done without executing
#   -c, --config FILE       Load configuration from file
#   -n, --network ID        ZeroTier network ID
#   -p, --physical IFACE    Physical network interface
#   -z, --zt-interface IF   ZeroTier interface name
#   -s, --subnet CIDR       Physical network subnet (e.g., 192.168.1.0/24)
#   --ipv6                  Enable IPv6 forwarding
#   --no-backup             Skip backup of existing configuration
#   -y, --yes               Skip confirmation prompts
#
#####################################################################

set -euo pipefail

# Script metadata
SCRIPT_VERSION="2.0.0"
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default configuration
VERBOSE=0
DRY_RUN=0
AUTO_YES=0
CONFIG_FILE=""
ENABLE_IPV6=0
SKIP_BACKUP=0
LOG_FILE=""

# Network configuration
ZT_NETWORK_ID=""
PHY_IFACE=""
ZT_IFACE=""
PHY_SUBNET=""
ZT_SUBNET=""

# Backup directory
BACKUP_DIR="/var/backup/zerotier-conf-$(date +%Y%m%d-%H%M%S)"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

#####################################################################
# Functions
#####################################################################

usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Configure ZeroTier as a NAT router/gateway with advanced network capabilities.

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -d, --dry-run           Show what would be done without executing
    -c, --config FILE       Load configuration from file
    -n, --network ID        ZeroTier network ID (16 hex chars)
    -p, --physical IFACE    Physical network interface (auto-detected if not specified)
    -z, --zt-interface IF   ZeroTier interface name (auto-detected if not specified)
    -s, --subnet CIDR       Physical network subnet (e.g., 192.168.1.0/24)
    --ipv6                  Enable IPv6 forwarding
    --no-backup             Skip backup of existing configuration
    -y, --yes               Skip confirmation prompts
    --version               Show script version

CONFIGURATION FILE FORMAT:
    A configuration file can specify settings in KEY=VALUE format:
    
    ZT_NETWORK_ID=a1b2c3d4e5f6a7b8
    PHY_IFACE=eth0
    PHY_SUBNET=192.168.1.0/24
    ENABLE_IPV6=1

EXAMPLES:
    # Interactive configuration (auto-detects interfaces)
    $SCRIPT_NAME

    # Configure with specific network and interface
    $SCRIPT_NAME -n a1b2c3d4e5f6a7b8 -p eth0 -s 192.168.1.0/24

    # Use configuration file
    $SCRIPT_NAME -c /etc/zerotier/gateway.conf

    # Dry-run to preview changes
    $SCRIPT_NAME --dry-run -n a1b2c3d4e5f6a7b8

    # Enable IPv6 forwarding
    $SCRIPT_NAME -n a1b2c3d4e5f6a7b8 --ipv6

EOF
    exit 0
}

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ -n "$LOG_FILE" ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
    
    case "$level" in
        ERROR)
            echo -e "${RED}[ERROR]${NC} $message" >&2
            ;;
        WARN)
            echo -e "${YELLOW}[WARN]${NC} $message" >&2
            ;;
        SUCCESS)
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
        INFO)
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        DEBUG)
            [[ $VERBOSE -eq 1 ]] && echo -e "[DEBUG] $message"
            ;;
    esac
}

error_exit() {
    log ERROR "$1"
    exit "${2:-1}"
}

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log ERROR "Script failed with exit code: $exit_code"
        log INFO "Backup files are available in: $BACKUP_DIR"
    fi
    exit "$exit_code"
}

trap cleanup EXIT INT TERM

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    elif [[ -f /etc/redhat-release ]]; then
        echo "rhel"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

check_root() {
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        error_exit "This script requires root privileges. Please run with sudo."
    fi
}

execute() {
    local cmd="$*"
    log DEBUG "Executing: $cmd"
    
    if [[ $DRY_RUN -eq 1 ]]; then
        log INFO "[DRY-RUN] Would execute: $cmd"
        return 0
    fi
    
    if [[ $VERBOSE -eq 1 ]]; then
        eval "$cmd"
    else
        eval "$cmd" &>/dev/null
    fi
}

# Load configuration from file
load_config() {
    if [[ -z "$CONFIG_FILE" ]]; then
        return 0
    fi
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        error_exit "Configuration file not found: $CONFIG_FILE"
    fi
    
    log INFO "Loading configuration from: $CONFIG_FILE"
    
    # Source the config file safely
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^#.*$ ]] || [[ -z "$key" ]] && continue
        
        # Remove quotes from value
        value="${value%\"}"
        value="${value#\"}"
        
        case "$key" in
            ZT_NETWORK_ID) ZT_NETWORK_ID="$value" ;;
            PHY_IFACE) PHY_IFACE="$value" ;;
            ZT_IFACE) ZT_IFACE="$value" ;;
            PHY_SUBNET) PHY_SUBNET="$value" ;;
            ZT_SUBNET) ZT_SUBNET="$value" ;;
            ENABLE_IPV6) ENABLE_IPV6="$value" ;;
        esac
    done < "$CONFIG_FILE"
    
    log SUCCESS "Configuration loaded successfully"
}

# Validate network ID format
validate_network_id() {
    if [[ ! "$ZT_NETWORK_ID" =~ ^[0-9a-fA-F]{16}$ ]]; then
        error_exit "Invalid network ID format. Expected 16 hexadecimal characters."
    fi
}

# Auto-detect physical interface
detect_physical_interface() {
    if [[ -n "$PHY_IFACE" ]]; then
        if ! ip link show "$PHY_IFACE" &>/dev/null; then
            error_exit "Specified interface $PHY_IFACE does not exist"
        fi
        return 0
    fi
    
    log INFO "Auto-detecting physical network interface..."
    
    # Get default route interface
    PHY_IFACE=$(ip route | grep default | head -n1 | awk '{print $5}')
    
    if [[ -z "$PHY_IFACE" ]]; then
        error_exit "Could not auto-detect physical interface. Please specify with -p option."
    fi
    
    log SUCCESS "Detected physical interface: $PHY_IFACE"
}

# Auto-detect ZeroTier interface
detect_zt_interface() {
    if [[ -n "$ZT_IFACE" ]]; then
        if ! ip link show "$ZT_IFACE" &>/dev/null; then
            log WARN "Specified ZeroTier interface $ZT_IFACE does not exist yet"
        fi
        return 0
    fi
    
    log INFO "Auto-detecting ZeroTier interface..."
    
    # List ZeroTier networks and get interface name
    local zt_info
    if zt_info=$(sudo zerotier-cli listnetworks 2>/dev/null); then
        ZT_IFACE=$(echo "$zt_info" | grep "$ZT_NETWORK_ID" | awk '{print $8}' | head -n1)
    fi
    
    if [[ -z "$ZT_IFACE" ]]; then
        log WARN "Could not auto-detect ZeroTier interface. Will use pattern: zt*"
        ZT_IFACE="zt+"
    else
        log SUCCESS "Detected ZeroTier interface: $ZT_IFACE"
    fi
}

# Detect physical subnet
detect_physical_subnet() {
    if [[ -n "$PHY_SUBNET" ]]; then
        return 0
    fi
    
    log INFO "Auto-detecting physical network subnet..."
    
    local ip_info
    ip_info=$(ip -4 addr show "$PHY_IFACE" | grep inet | head -n1)
    
    if [[ -z "$ip_info" ]]; then
        error_exit "Could not detect subnet for $PHY_IFACE. Please specify with -s option."
    fi
    
    PHY_SUBNET=$(echo "$ip_info" | awk '{print $2}')
    
    log SUCCESS "Detected physical subnet: $PHY_SUBNET"
}

# Check if ZeroTier is installed
check_zerotier() {
    log INFO "Checking ZeroTier installation..."
    
    if ! command -v zerotier-cli &> /dev/null; then
        error_exit "ZeroTier is not installed. Please run zerotier-install.sh first."
    fi
    
    if ! sudo zerotier-cli info &> /dev/null; then
        error_exit "ZeroTier service is not running. Please start it with: sudo systemctl start zerotier-one"
    fi
    
    log SUCCESS "ZeroTier is installed and running"
}

# Join ZeroTier network
join_network() {
    log INFO "Joining ZeroTier network: $ZT_NETWORK_ID"
    
    # Check if already joined
    if sudo zerotier-cli listnetworks | grep -q "$ZT_NETWORK_ID"; then
        log INFO "Already joined to network $ZT_NETWORK_ID"
        return 0
    fi
    
    if execute "sudo zerotier-cli join $ZT_NETWORK_ID"; then
        log SUCCESS "Joined network: $ZT_NETWORK_ID"
        log INFO "Please authorize this node at https://my.zerotier.com/network/$ZT_NETWORK_ID"
        
        if [[ $DRY_RUN -eq 0 ]]; then
            log INFO "Waiting for network authorization..."
            sleep 5
        fi
    else
        error_exit "Failed to join network: $ZT_NETWORK_ID"
    fi
}

# Create backup
create_backup() {
    if [[ $SKIP_BACKUP -eq 1 ]] || [[ $DRY_RUN -eq 1 ]]; then
        return 0
    fi
    
    log INFO "Creating backup of existing configuration..."
    
    sudo mkdir -p "$BACKUP_DIR"
    
    # Backup sysctl config
    if [[ -f /etc/sysctl.conf ]]; then
        sudo cp /etc/sysctl.conf "$BACKUP_DIR/"
    fi
    
    # Backup firewall rules based on system
    local distro
    distro=$(detect_distro)
    
    case "$distro" in
        ubuntu|debian)
            if command -v iptables-save &>/dev/null; then
                sudo iptables-save > "$BACKUP_DIR/iptables.rules"
            fi
            if command -v ip6tables-save &>/dev/null; then
                sudo ip6tables-save > "$BACKUP_DIR/ip6tables.rules"
            fi
            ;;
        fedora|rhel|centos|rocky|almalinux)
            if [[ -f /etc/sysconfig/iptables ]]; then
                sudo cp /etc/sysconfig/iptables "$BACKUP_DIR/"
            fi
            if command -v firewall-cmd &>/dev/null; then
                sudo firewall-cmd --list-all > "$BACKUP_DIR/firewalld.conf" 2>/dev/null || true
            fi
            ;;
    esac
    
    log SUCCESS "Backup created at: $BACKUP_DIR"
}

# Detect firewall system
detect_firewall() {
    if command -v firewall-cmd &>/dev/null && sudo systemctl is-active firewalld &>/dev/null; then
        echo "firewalld"
    elif command -v ufw &>/dev/null && sudo ufw status | grep -q "Status: active"; then
        echo "ufw"
    elif command -v nft &>/dev/null && sudo nft list tables 2>/dev/null | grep -q .; then
        echo "nftables"
    elif command -v iptables &>/dev/null; then
        echo "iptables"
    else
        echo "none"
    fi
}

# Enable IP forwarding
enable_ip_forwarding() {
    log INFO "Enabling IP forwarding..."
    
    # Enable IPv4 forwarding
    execute "sudo sysctl -w net.ipv4.ip_forward=1"
    
    # Make persistent
    if [[ $DRY_RUN -eq 0 ]]; then
        if ! grep -q "^net.ipv4.ip_forward" /etc/sysctl.conf; then
            echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf >/dev/null
        else
            sudo sed -i 's/^net.ipv4.ip_forward.*/net.ipv4.ip_forward = 1/' /etc/sysctl.conf
        fi
    fi
    
    # Enable IPv6 forwarding if requested
    if [[ $ENABLE_IPV6 -eq 1 ]]; then
        log INFO "Enabling IPv6 forwarding..."
        execute "sudo sysctl -w net.ipv6.conf.all.forwarding=1"
        
        if [[ $DRY_RUN -eq 0 ]]; then
            if ! grep -q "^net.ipv6.conf.all.forwarding" /etc/sysctl.conf; then
                echo "net.ipv6.conf.all.forwarding = 1" | sudo tee -a /etc/sysctl.conf >/dev/null
            else
                sudo sed -i 's/^net.ipv6.conf.all.forwarding.*/net.ipv6.conf.all.forwarding = 1/' /etc/sysctl.conf
            fi
        fi
    fi
    
    execute "sudo sysctl -p"
    log SUCCESS "IP forwarding enabled"
}

# Configure firewall with iptables
configure_iptables() {
    log INFO "Configuring iptables rules..."
    
    # NAT rule for outbound traffic
    execute "sudo iptables -t nat -A POSTROUTING -o $PHY_IFACE -j MASQUERADE"
    
    # Forward rules
    execute "sudo iptables -A FORWARD -i $PHY_IFACE -o $ZT_IFACE -m state --state RELATED,ESTABLISHED -j ACCEPT"
    execute "sudo iptables -A FORWARD -i $ZT_IFACE -o $PHY_IFACE -j ACCEPT"
    
    # IPv6 rules if enabled
    if [[ $ENABLE_IPV6 -eq 1 ]]; then
        log INFO "Configuring IPv6 iptables rules..."
        execute "sudo ip6tables -t nat -A POSTROUTING -o $PHY_IFACE -j MASQUERADE"
        execute "sudo ip6tables -A FORWARD -i $PHY_IFACE -o $ZT_IFACE -m state --state RELATED,ESTABLISHED -j ACCEPT"
        execute "sudo ip6tables -A FORWARD -i $ZT_IFACE -o $PHY_IFACE -j ACCEPT"
    fi
    
    # Make rules persistent
    local distro
    distro=$(detect_distro)
    
    case "$distro" in
        ubuntu|debian)
            if ! command -v iptables-persistent &>/dev/null; then
                log INFO "Installing iptables-persistent..."
                execute "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent"
            fi
            execute "sudo iptables-save | sudo tee /etc/iptables/rules.v4 >/dev/null"
            if [[ $ENABLE_IPV6 -eq 1 ]]; then
                execute "sudo ip6tables-save | sudo tee /etc/iptables/rules.v6 >/dev/null"
            fi
            ;;
        fedora|rhel|centos|rocky|almalinux)
            if ! rpm -q iptables-services &>/dev/null; then
                log INFO "Installing iptables-services..."
                execute "sudo yum install -y iptables-services || sudo dnf install -y iptables-services"
            fi
            execute "sudo systemctl enable iptables"
            execute "sudo iptables-save | sudo tee /etc/sysconfig/iptables >/dev/null"
            if [[ $ENABLE_IPV6 -eq 1 ]]; then
                execute "sudo systemctl enable ip6tables"
                execute "sudo ip6tables-save | sudo tee /etc/sysconfig/ip6tables >/dev/null"
            fi
            ;;
    esac
    
    log SUCCESS "Iptables configured and persisted"
}

# Configure firewall with firewalld
configure_firewalld() {
    log INFO "Configuring firewalld..."
    
    execute "sudo firewall-cmd --permanent --add-masquerade"
    execute "sudo firewall-cmd --permanent --add-forward"
    
    # Add ZeroTier interface to trusted zone
    execute "sudo firewall-cmd --permanent --zone=trusted --add-interface=$ZT_IFACE"
    
    # Reload firewalld
    execute "sudo firewall-cmd --reload"
    
    log SUCCESS "Firewalld configured"
}

# Configure firewall with ufw
configure_ufw() {
    log INFO "Configuring ufw..."
    
    # Enable forwarding in ufw
    if [[ $DRY_RUN -eq 0 ]]; then
        sudo sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
    fi
    
    # Add NAT rules
    local ufw_before_rules="/etc/ufw/before.rules"
    if [[ $DRY_RUN -eq 0 ]] && ! grep -q "POSTROUTING.*$PHY_IFACE" "$ufw_before_rules"; then
        sudo sed -i "/# Don't delete these required lines/a\
# NAT table rules\n\
*nat\n\
:POSTROUTING ACCEPT [0:0]\n\
-A POSTROUTING -o $PHY_IFACE -j MASQUERADE\n\
COMMIT\n" "$ufw_before_rules"
    fi
    
    execute "sudo ufw reload"
    
    log SUCCESS "UFW configured"
}

# Configure firewall with nftables
configure_nftables() {
    log INFO "Configuring nftables..."
    
    local nft_config="/etc/nftables.conf"
    
    if [[ $DRY_RUN -eq 0 ]]; then
        cat | sudo tee -a "$nft_config" >/dev/null <<EOF

# ZeroTier NAT configuration
table ip nat {
    chain postrouting {
        type nat hook postrouting priority 100;
        oifname "$PHY_IFACE" masquerade
    }
}

table ip filter {
    chain forward {
        type filter hook forward priority 0; policy drop;
        iifname "$PHY_IFACE" oifname "$ZT_IFACE" ct state related,established accept
        iifname "$ZT_IFACE" oifname "$PHY_IFACE" accept
    }
}
EOF
    fi
    
    execute "sudo nft -f $nft_config"
    execute "sudo systemctl enable nftables"
    
    log SUCCESS "Nftables configured"
}

# Configure firewall
configure_firewall() {
    local fw_system
    fw_system=$(detect_firewall)
    
    log INFO "Detected firewall system: $fw_system"
    
    case "$fw_system" in
        firewalld)
            configure_firewalld
            ;;
        ufw)
            configure_ufw
            ;;
        nftables)
            configure_nftables
            ;;
        iptables|none)
            configure_iptables
            ;;
    esac
}

# Configure ZeroTier network settings
configure_zt_network() {
    log INFO "Configuring ZeroTier network settings..."
    
    # Allow default route override
    execute "sudo zerotier-cli set $ZT_NETWORK_ID allowDefault=1"
    
    log SUCCESS "ZeroTier network configured"
}

# Display configuration summary
display_summary() {
    log INFO "Configuration Summary:"
    echo ""
    echo "  Network ID:        $ZT_NETWORK_ID"
    echo "  Physical Interface: $PHY_IFACE"
    echo "  ZeroTier Interface: $ZT_IFACE"
    echo "  Physical Subnet:    $PHY_SUBNET"
    echo "  IPv6 Enabled:       $([[ $ENABLE_IPV6 -eq 1 ]] && echo 'Yes' || echo 'No')"
    echo "  Firewall:           $(detect_firewall)"
    echo "  Backup Location:    $BACKUP_DIR"
    echo ""
}

# Interactive configuration
interactive_config() {
    log INFO "Starting interactive configuration..."
    
    # Get network ID
    if [[ -z "$ZT_NETWORK_ID" ]]; then
        read -p "Enter ZeroTier Network ID (16 hex chars): " ZT_NETWORK_ID
    fi
    
    validate_network_id
    
    # Auto-detect or confirm interfaces
    detect_physical_interface
    detect_physical_subnet
    
    # Ask for IPv6
    if [[ $ENABLE_IPV6 -eq 0 ]]; then
        read -p "Enable IPv6 forwarding? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ENABLE_IPV6=1
        fi
    fi
    
    # Confirm configuration
    display_summary
    
    if [[ $AUTO_YES -eq 0 ]]; then
        read -p "Proceed with this configuration? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log INFO "Configuration cancelled by user"
            exit 0
        fi
    fi
}

# Main configuration function
main_configure() {
    log INFO "Starting ZeroTier gateway configuration (version $SCRIPT_VERSION)"
    
    check_root
    check_zerotier
    load_config
    
    # If no config provided, run interactive mode
    if [[ -z "$ZT_NETWORK_ID" ]]; then
        interactive_config
    else
        validate_network_id
        detect_physical_interface
        detect_physical_subnet
        display_summary
    fi
    
    create_backup
    join_network
    detect_zt_interface
    enable_ip_forwarding
    configure_firewall
    configure_zt_network
    
    log SUCCESS "Configuration completed successfully!"
    log INFO "Your ZeroTier gateway is now configured"
    log INFO "Authorize this node at: https://my.zerotier.com/network/$ZT_NETWORK_ID"
    log INFO "Add a managed route on the controller:"
    log INFO "  Destination: $PHY_SUBNET"
    log INFO "  Via: <this node's ZeroTier IP>"
}

#####################################################################
# Parse arguments
#####################################################################

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=1
                log INFO "Dry-run mode enabled"
                shift
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -n|--network)
                ZT_NETWORK_ID="$2"
                shift 2
                ;;
            -p|--physical)
                PHY_IFACE="$2"
                shift 2
                ;;
            -z|--zt-interface)
                ZT_IFACE="$2"
                shift 2
                ;;
            -s|--subnet)
                PHY_SUBNET="$2"
                shift 2
                ;;
            --ipv6)
                ENABLE_IPV6=1
                shift
                ;;
            --no-backup)
                SKIP_BACKUP=1
                shift
                ;;
            -y|--yes)
                AUTO_YES=1
                shift
                ;;
            --version)
                echo "$SCRIPT_VERSION"
                exit 0
                ;;
            *)
                error_exit "Unknown option: $1. Use -h for help."
                ;;
        esac
    done
}

#####################################################################
# Main
#####################################################################

LOG_FILE="/tmp/zerotier-conf-$(date +%Y%m%d-%H%M%S).log"

parse_args "$@"
main_configure
