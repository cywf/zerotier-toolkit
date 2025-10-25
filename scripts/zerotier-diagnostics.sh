#!/bin/bash

#####################################################################
# ZeroTier Network Diagnostics Script
# 
# Comprehensive diagnostic tool for troubleshooting ZeroTier
# networks, connectivity, routing, and firewall issues.
#
# Usage: ./zerotier-diagnostics.sh [OPTIONS]
#
# Options:
#   -h, --help              Show this help message
#   -v, --verbose           Enable verbose output
#   -n, --network ID        Test specific network
#   -p, --peer ADDRESS      Test connectivity to specific peer
#   -o, --output FILE       Save report to file
#   --full                  Run full comprehensive diagnostics
#
#####################################################################

set -euo pipefail

# Script metadata
SCRIPT_VERSION="1.0.0"
SCRIPT_NAME="$(basename "$0")"

# Configuration
VERBOSE=0
NETWORK_ID=""
PEER_ADDRESS=""
OUTPUT_FILE=""
FULL_DIAGNOSTICS=0

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

#####################################################################
# Functions
#####################################################################

usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Comprehensive diagnostic tool for ZeroTier networks.

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -n, --network ID        Test specific network (16 hex chars)
    -p, --peer ADDRESS      Test connectivity to specific peer IP
    -o, --output FILE       Save diagnostic report to file
    --full                  Run full comprehensive diagnostics
    --version               Show script version

EXAMPLES:
    # Quick diagnostics
    $SCRIPT_NAME

    # Full diagnostic report
    $SCRIPT_NAME --full

    # Diagnose specific network
    $SCRIPT_NAME -n a1b2c3d4e5f6a7b8

    # Test connectivity to peer
    $SCRIPT_NAME -p 172.27.0.5

    # Save report to file
    $SCRIPT_NAME --full -o /tmp/zt-diagnostics.txt

EOF
    exit 0
}

log() {
    local level="$1"
    shift
    local message="$*"
    
    case "$level" in
        ERROR)
            echo -e "${RED}[✗]${NC} $message" >&2
            ;;
        WARN)
            echo -e "${YELLOW}[!]${NC} $message" >&2
            ;;
        SUCCESS)
            echo -e "${GREEN}[✓]${NC} $message"
            ;;
        INFO)
            echo -e "${BLUE}[i]${NC} $message"
            ;;
        SECTION)
            echo -e "\n${CYAN}=== $message ===${NC}\n"
            ;;
        DEBUG)
            [[ $VERBOSE -eq 1 ]] && echo -e "[DEBUG] $message"
            ;;
    esac
    
    # Also write to output file if specified
    if [[ -n "$OUTPUT_FILE" ]]; then
        echo "[$level] $message" >> "$OUTPUT_FILE"
    fi
}

# Check if ZeroTier is installed
check_installation() {
    log SECTION "Checking ZeroTier Installation"
    
    if ! command -v zerotier-cli &> /dev/null; then
        log ERROR "ZeroTier is not installed"
        log INFO "Install with: ./zerotier-install.sh"
        return 1
    fi
    log SUCCESS "ZeroTier is installed"
    
    local version
    version=$(zerotier-cli -v 2>/dev/null || echo "unknown")
    log INFO "Version: $version"
    
    return 0
}

# Check service status
check_service() {
    log SECTION "Checking ZeroTier Service"
    
    if ! sudo zerotier-cli info &> /dev/null; then
        log ERROR "ZeroTier service is not running"
        log INFO "Start with: sudo systemctl start zerotier-one"
        return 1
    fi
    log SUCCESS "ZeroTier service is running"
    
    local info
    info=$(sudo zerotier-cli info)
    log INFO "Node info: $info"
    
    return 0
}

# Check network memberships
check_networks() {
    log SECTION "Checking Network Memberships"
    
    local networks
    networks=$(sudo zerotier-cli listnetworks 2>/dev/null)
    
    if [[ -z "$networks" ]] || [[ $(echo "$networks" | wc -l) -le 1 ]]; then
        log WARN "No networks joined"
        log INFO "Join a network with: sudo zerotier-cli join <network_id>"
        return 1
    fi
    
    log SUCCESS "Networks joined:"
    echo "$networks" | tail -n +2 | while read -r line; do
        local net_id status type dev
        net_id=$(echo "$line" | awk '{print $3}')
        status=$(echo "$line" | awk '{print $6}')
        type=$(echo "$line" | awk '{print $5}')
        dev=$(echo "$line" | awk '{print $8}')
        
        if [[ "$status" == "OK" ]]; then
            log SUCCESS "  Network: $net_id [$type] on $dev - $status"
        else
            log WARN "  Network: $net_id [$type] on $dev - $status"
        fi
    done
    
    return 0
}

# Check specific network details
check_network_details() {
    if [[ -z "$NETWORK_ID" ]]; then
        return 0
    fi
    
    log SECTION "Detailed Network Information: $NETWORK_ID"
    
    local net_info
    net_info=$(sudo zerotier-cli listnetworks | grep "$NETWORK_ID" || true)
    
    if [[ -z "$net_info" ]]; then
        log ERROR "Not joined to network: $NETWORK_ID"
        return 1
    fi
    
    echo "$net_info" | while read -r line; do
        log INFO "  $line"
    done
    
    # Get interface details
    local iface
    iface=$(echo "$net_info" | awk '{print $8}')
    
    if [[ -n "$iface" ]] && ip link show "$iface" &>/dev/null; then
        log INFO "Interface details:"
        ip addr show "$iface" | while read -r line; do
            log INFO "    $line"
        done
    fi
    
    return 0
}

# Check peers
check_peers() {
    log SECTION "Checking Peers"
    
    local peers
    peers=$(sudo zerotier-cli listpeers 2>/dev/null)
    
    if [[ -z "$peers" ]]; then
        log WARN "No peers found"
        return 1
    fi
    
    local peer_count
    peer_count=$(echo "$peers" | tail -n +2 | wc -l)
    log SUCCESS "Connected to $peer_count peers"
    
    if [[ $VERBOSE -eq 1 ]] || [[ $FULL_DIAGNOSTICS -eq 1 ]]; then
        log INFO "Peer details:"
        echo "$peers" | tail -n +2 | head -20 | while read -r line; do
            log INFO "  $line"
        done
    fi
    
    return 0
}

# Check IP forwarding
check_ip_forwarding() {
    log SECTION "Checking IP Forwarding"
    
    local ipv4_forward
    ipv4_forward=$(cat /proc/sys/net/ipv4/ip_forward)
    
    if [[ "$ipv4_forward" == "1" ]]; then
        log SUCCESS "IPv4 forwarding is enabled"
    else
        log WARN "IPv4 forwarding is disabled"
        log INFO "Enable with: sudo sysctl -w net.ipv4.ip_forward=1"
    fi
    
    if [[ -f /proc/sys/net/ipv6/conf/all/forwarding ]]; then
        local ipv6_forward
        ipv6_forward=$(cat /proc/sys/net/ipv6/conf/all/forwarding)
        
        if [[ "$ipv6_forward" == "1" ]]; then
            log SUCCESS "IPv6 forwarding is enabled"
        else
            log INFO "IPv6 forwarding is disabled"
        fi
    fi
    
    return 0
}

# Check firewall configuration
check_firewall() {
    log SECTION "Checking Firewall Configuration"
    
    # Detect firewall system
    if command -v firewall-cmd &>/dev/null && sudo systemctl is-active firewalld &>/dev/null; then
        log INFO "Firewall: firewalld (active)"
        
        if [[ $VERBOSE -eq 1 ]] || [[ $FULL_DIAGNOSTICS -eq 1 ]]; then
            log INFO "Firewalld zones:"
            sudo firewall-cmd --list-all-zones | head -50 | while read -r line; do
                log INFO "  $line"
            done
        fi
    elif command -v ufw &>/dev/null && sudo ufw status | grep -q "Status: active"; then
        log INFO "Firewall: ufw (active)"
        
        if [[ $VERBOSE -eq 1 ]] || [[ $FULL_DIAGNOSTICS -eq 1 ]]; then
            sudo ufw status verbose | while read -r line; do
                log INFO "  $line"
            done
        fi
    elif command -v iptables &>/dev/null; then
        log INFO "Firewall: iptables"
        
        # Check for NAT rules
        if sudo iptables -t nat -L POSTROUTING -n 2>/dev/null | grep -q MASQUERADE; then
            log SUCCESS "NAT (MASQUERADE) rules detected"
        else
            log INFO "No NAT rules detected"
        fi
        
        if [[ $VERBOSE -eq 1 ]] || [[ $FULL_DIAGNOSTICS -eq 1 ]]; then
            log INFO "NAT table:"
            sudo iptables -t nat -L -n -v | head -30 | while read -r line; do
                log INFO "  $line"
            done
        fi
    else
        log INFO "No active firewall detected"
    fi
    
    return 0
}

# Check routing
check_routing() {
    log SECTION "Checking Routing Tables"
    
    log INFO "IPv4 routes:"
    ip -4 route show | while read -r line; do
        log INFO "  $line"
    done
    
    if [[ $FULL_DIAGNOSTICS -eq 1 ]]; then
        log INFO "IPv6 routes:"
        ip -6 route show | head -20 | while read -r line; do
            log INFO "  $line"
        done
    fi
    
    return 0
}

# Test connectivity to peer
test_peer_connectivity() {
    if [[ -z "$PEER_ADDRESS" ]]; then
        return 0
    fi
    
    log SECTION "Testing Connectivity to Peer: $PEER_ADDRESS"
    
    # Ping test
    log INFO "Running ping test..."
    if ping -c 3 -W 2 "$PEER_ADDRESS" &>/dev/null; then
        log SUCCESS "Ping successful to $PEER_ADDRESS"
    else
        log ERROR "Ping failed to $PEER_ADDRESS"
        log INFO "Checking route to $PEER_ADDRESS"
        ip route get "$PEER_ADDRESS" 2>&1 | while read -r line; do
            log INFO "  $line"
        done
    fi
    
    # Traceroute
    if command -v traceroute &>/dev/null || command -v tracepath &>/dev/null; then
        log INFO "Running traceroute..."
        if command -v traceroute &>/dev/null; then
            timeout 10 traceroute -m 10 "$PEER_ADDRESS" 2>&1 | while read -r line; do
                log INFO "  $line"
            done
        else
            timeout 10 tracepath "$PEER_ADDRESS" 2>&1 | head -15 | while read -r line; do
                log INFO "  $line"
            done
        fi
    fi
    
    return 0
}

# Check DNS resolution
check_dns() {
    log SECTION "Checking DNS Resolution"
    
    if command -v dig &>/dev/null; then
        log INFO "Testing DNS with my.zerotier.com..."
        if dig +short my.zerotier.com &>/dev/null; then
            log SUCCESS "DNS resolution working"
        else
            log WARN "DNS resolution issues detected"
        fi
    elif command -v nslookup &>/dev/null; then
        log INFO "Testing DNS with my.zerotier.com..."
        if nslookup my.zerotier.com &>/dev/null; then
            log SUCCESS "DNS resolution working"
        else
            log WARN "DNS resolution issues detected"
        fi
    else
        log INFO "No DNS tools available (dig/nslookup)"
    fi
    
    return 0
}

# Check connectivity to ZeroTier infrastructure
check_zt_connectivity() {
    log SECTION "Checking ZeroTier Infrastructure Connectivity"
    
    # Test connection to ZeroTier planet servers
    local planet_ips=("103.195.103.66" "8.17.13.51")
    
    for ip in "${planet_ips[@]}"; do
        log INFO "Testing connectivity to planet server: $ip"
        if timeout 3 bash -c "echo >/dev/tcp/$ip/9993" 2>/dev/null; then
            log SUCCESS "Connected to $ip:9993"
        else
            log WARN "Could not connect to $ip:9993"
        fi
    done
    
    return 0
}

# System information
show_system_info() {
    if [[ $FULL_DIAGNOSTICS -eq 0 ]]; then
        return 0
    fi
    
    log SECTION "System Information"
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        log INFO "OS: $NAME $VERSION"
    fi
    
    log INFO "Kernel: $(uname -r)"
    log INFO "Architecture: $(uname -m)"
    
    # Network interfaces
    log INFO "Network interfaces:"
    ip -brief link show | while read -r line; do
        log INFO "  $line"
    done
    
    return 0
}

# Generate summary
generate_summary() {
    log SECTION "Diagnostic Summary"
    
    local issues=0
    
    if ! command -v zerotier-cli &> /dev/null; then
        ((issues++))
        log ERROR "ZeroTier not installed"
    fi
    
    if ! sudo zerotier-cli info &> /dev/null; then
        ((issues++))
        log ERROR "ZeroTier service not running"
    fi
    
    local networks
    networks=$(sudo zerotier-cli listnetworks 2>/dev/null || echo "")
    if [[ -z "$networks" ]] || [[ $(echo "$networks" | wc -l) -le 1 ]]; then
        ((issues++))
        log WARN "No networks joined"
    fi
    
    local ipv4_forward
    ipv4_forward=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo "0")
    if [[ "$ipv4_forward" != "1" ]]; then
        log INFO "IPv4 forwarding disabled (may be intentional)"
    fi
    
    if [[ $issues -eq 0 ]]; then
        log SUCCESS "No critical issues detected"
    else
        log WARN "Found $issues issue(s) requiring attention"
    fi
    
    return 0
}

# Main diagnostic function
main_diagnostics() {
    local start_time
    start_time=$(date '+%Y-%m-%d %H:%M:%S')
    
    log INFO "ZeroTier Diagnostics v$SCRIPT_VERSION"
    log INFO "Started: $start_time"
    
    if [[ -n "$OUTPUT_FILE" ]]; then
        log INFO "Saving report to: $OUTPUT_FILE"
        echo "ZeroTier Diagnostics Report" > "$OUTPUT_FILE"
        echo "Generated: $start_time" >> "$OUTPUT_FILE"
        echo "======================================" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
    fi
    
    show_system_info
    check_installation || true
    check_service || true
    check_networks || true
    check_network_details || true
    check_peers || true
    check_ip_forwarding || true
    check_firewall || true
    check_routing || true
    check_dns || true
    check_zt_connectivity || true
    test_peer_connectivity || true
    generate_summary
    
    local end_time
    end_time=$(date '+%Y-%m-%d %H:%M:%S')
    log INFO "Completed: $end_time"
    
    if [[ -n "$OUTPUT_FILE" ]]; then
        log SUCCESS "Report saved to: $OUTPUT_FILE"
    fi
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
            -n|--network)
                NETWORK_ID="$2"
                shift 2
                ;;
            -p|--peer)
                PEER_ADDRESS="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --full)
                FULL_DIAGNOSTICS=1
                shift
                ;;
            --version)
                echo "$SCRIPT_VERSION"
                exit 0
                ;;
            *)
                echo "Unknown option: $1. Use -h for help." >&2
                exit 1
                ;;
        esac
    done
}

#####################################################################
# Main
#####################################################################

parse_args "$@"
main_diagnostics
