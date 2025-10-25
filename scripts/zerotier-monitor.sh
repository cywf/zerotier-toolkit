#!/bin/bash

#####################################################################
# ZeroTier Network Health Monitor
# 
# Monitor ZeroTier network health, connectivity, and performance.
# Can run continuously or as a one-shot check.
#
# Usage: ./zerotier-monitor.sh [OPTIONS]
#
# Options:
#   -h, --help              Show this help message
#   -i, --interval SECONDS  Monitoring interval (default: 60)
#   -n, --network ID        Monitor specific network
#   -l, --log FILE          Log output to file
#   --once                  Run once and exit
#   --alert-email EMAIL     Send alerts to email
#   --alert-webhook URL     Send alerts to webhook
#
#####################################################################

set -euo pipefail

# Script metadata
SCRIPT_VERSION="1.0.0"
SCRIPT_NAME="$(basename "$0")"

# Configuration
INTERVAL=60
NETWORK_ID=""
LOG_FILE=""
RUN_ONCE=0
ALERT_EMAIL=""
ALERT_WEBHOOK=""

# Monitoring state
LAST_PEER_COUNT=0
LAST_STATUS=""
ALERT_SENT=0

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

Monitor ZeroTier network health and connectivity.

OPTIONS:
    -h, --help              Show this help message
    -i, --interval SECONDS  Monitoring interval in seconds (default: 60)
    -n, --network ID        Monitor specific network (16 hex chars)
    -l, --log FILE          Log output to file
    --once                  Run once and exit (no continuous monitoring)
    --alert-email EMAIL     Send alerts to this email (requires mail/mailx)
    --alert-webhook URL     Send alerts to webhook URL
    --version               Show script version

EXAMPLES:
    # Continuous monitoring every 60 seconds
    $SCRIPT_NAME

    # Monitor specific network every 30 seconds
    $SCRIPT_NAME -n a1b2c3d4e5f6a7b8 -i 30

    # One-shot health check
    $SCRIPT_NAME --once

    # Monitor with logging
    $SCRIPT_NAME -l /var/log/zerotier-monitor.log

    # Monitor with webhook alerts
    $SCRIPT_NAME --alert-webhook https://example.com/webhook

EOF
    exit 0
}

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Format message
    local formatted
    case "$level" in
        ERROR)
            formatted="${RED}[ERROR]${NC} $message"
            ;;
        WARN)
            formatted="${YELLOW}[WARN]${NC} $message"
            ;;
        SUCCESS)
            formatted="${GREEN}[OK]${NC} $message"
            ;;
        INFO)
            formatted="${BLUE}[INFO]${NC} $message"
            ;;
        *)
            formatted="[$level] $message"
            ;;
    esac
    
    echo -e "$formatted"
    
    # Log to file if specified
    if [[ -n "$LOG_FILE" ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
}

# Send alert
send_alert() {
    local subject="$1"
    local message="$2"
    
    # Prevent alert spam
    if [[ $ALERT_SENT -eq 1 ]]; then
        return 0
    fi
    
    # Send email alert
    if [[ -n "$ALERT_EMAIL" ]] && command -v mail &>/dev/null; then
        echo "$message" | mail -s "$subject" "$ALERT_EMAIL" 2>/dev/null && \
            log INFO "Alert sent to $ALERT_EMAIL"
    fi
    
    # Send webhook alert
    if [[ -n "$ALERT_WEBHOOK" ]] && command -v curl &>/dev/null; then
        curl -X POST "$ALERT_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"subject\":\"$subject\",\"message\":\"$message\"}" \
            &>/dev/null && \
            log INFO "Alert sent to webhook"
    fi
    
    ALERT_SENT=1
}

# Check ZeroTier service
check_service() {
    if ! sudo zerotier-cli info &>/dev/null; then
        log ERROR "ZeroTier service is not running"
        send_alert "ZeroTier Service Down" "ZeroTier service is not responding"
        return 1
    fi
    return 0
}

# Check network connectivity
check_network() {
    local net_id="$1"
    
    local status
    status=$(sudo zerotier-cli listnetworks | grep "$net_id" | awk '{print $6}' || echo "UNKNOWN")
    
    if [[ "$status" != "OK" ]]; then
        log WARN "Network $net_id status: $status"
        if [[ "$LAST_STATUS" == "OK" ]]; then
            send_alert "ZeroTier Network Issue" "Network $net_id changed status from OK to $status"
        fi
        LAST_STATUS="$status"
        return 1
    fi
    
    if [[ "$LAST_STATUS" != "OK" ]] && [[ -n "$LAST_STATUS" ]]; then
        log SUCCESS "Network $net_id recovered (status: OK)"
        ALERT_SENT=0  # Reset alert flag on recovery
    fi
    
    LAST_STATUS="OK"
    return 0
}

# Check peer count
check_peers() {
    local peer_count
    peer_count=$(sudo zerotier-cli listpeers 2>/dev/null | tail -n +2 | wc -l)
    
    if [[ $peer_count -eq 0 ]]; then
        log WARN "No peers connected"
        if [[ $LAST_PEER_COUNT -gt 0 ]]; then
            send_alert "ZeroTier Peer Loss" "All peers disconnected"
        fi
    elif [[ $LAST_PEER_COUNT -eq 0 ]] && [[ $peer_count -gt 0 ]]; then
        log SUCCESS "Peers reconnected ($peer_count peers)"
        ALERT_SENT=0
    fi
    
    LAST_PEER_COUNT=$peer_count
    log INFO "Connected peers: $peer_count"
    return 0
}

# Check interface status
check_interface() {
    local net_id="$1"
    
    local iface
    iface=$(sudo zerotier-cli listnetworks | grep "$net_id" | awk '{print $8}' || echo "")
    
    if [[ -z "$iface" ]]; then
        log WARN "Could not determine interface for network $net_id"
        return 1
    fi
    
    if ! ip link show "$iface" &>/dev/null; then
        log ERROR "Interface $iface does not exist"
        return 1
    fi
    
    local state
    state=$(ip link show "$iface" | grep -oP 'state \K\w+' || echo "UNKNOWN")
    
    if [[ "$state" != "UNKNOWN" ]]; then
        log INFO "Interface $iface state: $state"
    fi
    
    # Check if interface has IP address
    if ! ip addr show "$iface" | grep -q "inet "; then
        log WARN "Interface $iface has no IP address"
        return 1
    fi
    
    return 0
}

# Collect metrics
collect_metrics() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    local info
    info=$(sudo zerotier-cli info 2>/dev/null || echo "N/A")
    
    local networks
    networks=$(sudo zerotier-cli listnetworks 2>/dev/null | tail -n +2 | wc -l)
    
    local peers
    peers=$(sudo zerotier-cli listpeers 2>/dev/null | tail -n +2 | wc -l)
    
    log INFO "=== Metrics @ $timestamp ==="
    log INFO "Node: $info"
    log INFO "Networks: $networks"
    log INFO "Peers: $peers"
}

# Perform health check
health_check() {
    log INFO "Running health check..."
    
    local issues=0
    
    # Check service
    if ! check_service; then
        ((issues++))
    fi
    
    # Check networks
    if [[ -n "$NETWORK_ID" ]]; then
        if ! check_network "$NETWORK_ID"; then
            ((issues++))
        fi
        if ! check_interface "$NETWORK_ID"; then
            ((issues++))
        fi
    else
        # Check all networks
        local networks
        networks=$(sudo zerotier-cli listnetworks 2>/dev/null | tail -n +2 | awk '{print $3}')
        
        if [[ -z "$networks" ]]; then
            log WARN "No networks joined"
        else
            while IFS= read -r net_id; do
                check_network "$net_id" || ((issues++))
            done <<< "$networks"
        fi
    fi
    
    # Check peers
    check_peers || ((issues++))
    
    # Collect metrics
    collect_metrics
    
    if [[ $issues -eq 0 ]]; then
        log SUCCESS "All checks passed"
    else
        log WARN "Health check completed with $issues issue(s)"
    fi
    
    return 0
}

# Main monitoring loop
main_monitor() {
    log INFO "ZeroTier Network Monitor v$SCRIPT_VERSION started"
    
    if [[ -n "$LOG_FILE" ]]; then
        log INFO "Logging to: $LOG_FILE"
    fi
    
    if [[ $RUN_ONCE -eq 1 ]]; then
        log INFO "Running single health check..."
        health_check
        exit 0
    fi
    
    log INFO "Monitoring interval: ${INTERVAL}s"
    log INFO "Press Ctrl+C to stop"
    
    # Trap for cleanup
    trap 'log INFO "Monitoring stopped"; exit 0' INT TERM
    
    while true; do
        health_check
        
        if [[ $RUN_ONCE -eq 0 ]]; then
            sleep "$INTERVAL"
        else
            break
        fi
    done
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
            -i|--interval)
                INTERVAL="$2"
                if ! [[ "$INTERVAL" =~ ^[0-9]+$ ]]; then
                    echo "Error: Interval must be a positive number" >&2
                    exit 1
                fi
                shift 2
                ;;
            -n|--network)
                NETWORK_ID="$2"
                shift 2
                ;;
            -l|--log)
                LOG_FILE="$2"
                shift 2
                ;;
            --once)
                RUN_ONCE=1
                shift
                ;;
            --alert-email)
                ALERT_EMAIL="$2"
                shift 2
                ;;
            --alert-webhook)
                ALERT_WEBHOOK="$2"
                shift 2
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
main_monitor
