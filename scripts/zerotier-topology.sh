#!/bin/bash

#####################################################################
# ZeroTier Network Topology Manager
# 
# Advanced tool for managing complex network topologies including
# multi-site deployments, hub-and-spoke, mesh configurations, and
# advanced routing scenarios.
#
# Usage: ./zerotier-topology.sh [OPTIONS] COMMAND
#
# Commands:
#   deploy              Deploy topology from configuration
#   validate            Validate topology configuration
#   status              Show topology status
#   cleanup             Remove topology configuration
#
#####################################################################

set -euo pipefail

# Script metadata
SCRIPT_VERSION="1.0.0"
SCRIPT_NAME="$(basename "$0")"

# Configuration
VERBOSE=0
DRY_RUN=0
CONFIG_FILE=""
TOPOLOGY_TYPE=""

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
Usage: $SCRIPT_NAME [OPTIONS] COMMAND

Advanced network topology manager for ZeroTier.

COMMANDS:
    deploy              Deploy topology from configuration file
    validate            Validate topology configuration
    status              Show current topology status
    cleanup             Remove topology configuration

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -d, --dry-run           Show what would be done without executing
    -c, --config FILE       Topology configuration file (required)
    -t, --type TYPE         Topology type: hub-spoke, mesh, multi-site
    --version               Show script version

TOPOLOGY TYPES:
    hub-spoke           Hub-and-spoke: Central hub with multiple spokes
    mesh                Full mesh: All nodes can reach each other
    multi-site          Multi-site: Multiple networks with gateways
    custom              Custom: Define your own topology

CONFIGURATION FILE FORMAT (YAML-style):
    topology:
      type: hub-spoke
      networks:
        - id: a1b2c3d4e5f6a7b8
          role: hub
          subnets:
            - 192.168.1.0/24
            - 10.0.1.0/24
        - id: b2c3d4e5f6a7b8c9
          role: spoke
          subnets:
            - 192.168.2.0/24
      routing:
        enable_forwarding: true
        nat: true
        ipv6: false

EXAMPLES:
    # Validate topology configuration
    $SCRIPT_NAME -c topology.conf validate

    # Deploy hub-and-spoke topology
    $SCRIPT_NAME -c topology.conf deploy

    # Dry-run deployment
    $SCRIPT_NAME -c topology.conf -d deploy

    # Check topology status
    $SCRIPT_NAME -c topology.conf status

EOF
    exit 0
}

log() {
    local level="$1"
    shift
    local message="$*"
    
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
        SECTION)
            echo -e "\n${CYAN}=== $message ===${NC}\n"
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

# Parse configuration file
parse_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        error_exit "Configuration file not found: $CONFIG_FILE"
    fi
    
    log INFO "Parsing configuration: $CONFIG_FILE"
    
    # Simple parser for key=value format
    # In production, consider using a proper YAML/JSON parser
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^[[:space:]]*# ]] || [[ -z "$key" ]] && continue
        
        # Remove leading/trailing whitespace and quotes
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs | sed 's/^["'\'']\|["'\'']$//g')
        
        case "$key" in
            topology.type|type)
                TOPOLOGY_TYPE="$value"
                ;;
        esac
    done < "$CONFIG_FILE"
    
    log SUCCESS "Configuration parsed"
}

# Validate configuration
validate_config() {
    log SECTION "Validating Topology Configuration"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log ERROR "Configuration file not found: $CONFIG_FILE"
        return 1
    fi
    
    parse_config
    
    local issues=0
    
    # Check topology type
    if [[ -z "$TOPOLOGY_TYPE" ]]; then
        log ERROR "Topology type not specified"
        ((issues++))
    else
        case "$TOPOLOGY_TYPE" in
            hub-spoke|mesh|multi-site|custom)
                log SUCCESS "Topology type: $TOPOLOGY_TYPE"
                ;;
            *)
                log ERROR "Invalid topology type: $TOPOLOGY_TYPE"
                ((issues++))
                ;;
        esac
    fi
    
    # Check ZeroTier installation
    if ! command -v zerotier-cli &>/dev/null; then
        log ERROR "ZeroTier is not installed"
        ((issues++))
    else
        log SUCCESS "ZeroTier is installed"
    fi
    
    # Check for required tools
    local required_tools=("iptables" "ip" "sysctl")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            log WARN "Required tool not found: $tool"
            ((issues++))
        fi
    done
    
    if [[ $issues -eq 0 ]]; then
        log SUCCESS "Configuration validation passed"
        return 0
    else
        log ERROR "Configuration validation failed with $issues issue(s)"
        return 1
    fi
}

# Deploy hub-and-spoke topology
deploy_hub_spoke() {
    log SECTION "Deploying Hub-and-Spoke Topology"
    
    log INFO "This topology creates a central hub that routes traffic between spokes"
    log INFO "Spokes connect to the hub and can reach each other through it"
    
    # Read hub and spoke configuration from config file
    local hub_network=""
    local spoke_networks=()
    
    # Parse networks from config
    # This is a simplified example - in production use proper parsing
    while IFS= read -r line; do
        if [[ "$line" =~ network[[:space:]]*=[[:space:]]*(.*) ]]; then
            local net_id="${BASH_REMATCH[1]}"
            net_id=$(echo "$net_id" | xargs | sed 's/^["'\'']\|["'\'']$//g')
            
            if [[ -z "$hub_network" ]]; then
                hub_network="$net_id"
                log INFO "Hub network: $hub_network"
            else
                spoke_networks+=("$net_id")
                log INFO "Spoke network: $net_id"
            fi
        fi
    done < <(grep "network" "$CONFIG_FILE" 2>/dev/null || true)
    
    if [[ -z "$hub_network" ]]; then
        error_exit "No hub network defined in configuration"
    fi
    
    # Join hub network
    log INFO "Joining hub network: $hub_network"
    execute "sudo zerotier-cli join $hub_network"
    
    # Join spoke networks
    for spoke in "${spoke_networks[@]}"; do
        log INFO "Joining spoke network: $spoke"
        execute "sudo zerotier-cli join $spoke"
    done
    
    # Enable IP forwarding
    log INFO "Enabling IP forwarding..."
    execute "sudo sysctl -w net.ipv4.ip_forward=1"
    
    # Configure routing (simplified)
    log INFO "Configuring routing..."
    log WARN "Note: Additional manual configuration may be required"
    log INFO "Please configure managed routes at my.zerotier.com for each network"
    
    log SUCCESS "Hub-and-spoke topology deployed"
}

# Deploy mesh topology
deploy_mesh() {
    log SECTION "Deploying Mesh Topology"
    
    log INFO "This topology allows all nodes to communicate directly"
    log INFO "Best for small to medium deployments where all nodes need full connectivity"
    
    # Parse networks from config
    local networks=()
    while IFS= read -r line; do
        if [[ "$line" =~ network[[:space:]]*=[[:space:]]*(.*) ]]; then
            local net_id="${BASH_REMATCH[1]}"
            net_id=$(echo "$net_id" | xargs | sed 's/^["'\'']\|["'\'']$//g')
            networks+=("$net_id")
            log INFO "Network: $net_id"
        fi
    done < <(grep "network" "$CONFIG_FILE" 2>/dev/null || true)
    
    if [[ ${#networks[@]} -eq 0 ]]; then
        error_exit "No networks defined in configuration"
    fi
    
    # Join all networks
    for network in "${networks[@]}"; do
        log INFO "Joining network: $network"
        execute "sudo zerotier-cli join $network"
    done
    
    log SUCCESS "Mesh topology deployed"
    log INFO "Ensure all nodes are authorized on their respective networks"
}

# Deploy multi-site topology
deploy_multi_site() {
    log SECTION "Deploying Multi-Site Topology"
    
    log INFO "This topology connects multiple physical sites via ZeroTier gateways"
    log INFO "Each site has a gateway that routes traffic between local and remote networks"
    
    # This would be more complex in practice
    log WARN "Multi-site deployment requires additional manual configuration"
    log INFO "Steps:"
    log INFO "  1. Deploy a gateway at each site"
    log INFO "  2. Configure NAT/routing on each gateway"
    log INFO "  3. Set up managed routes on the ZeroTier controller"
    log INFO "  4. Verify connectivity between sites"
    
    log INFO "Use zerotier-conf.sh to configure each gateway"
    
    log SUCCESS "Multi-site topology framework deployed"
}

# Deploy topology
deploy_topology() {
    log SECTION "Deploying Network Topology"
    
    validate_config || error_exit "Configuration validation failed"
    
    case "$TOPOLOGY_TYPE" in
        hub-spoke)
            deploy_hub_spoke
            ;;
        mesh)
            deploy_mesh
            ;;
        multi-site)
            deploy_multi_site
            ;;
        custom)
            log WARN "Custom topology deployment requires manual configuration"
            log INFO "Use the configuration as a guide for manual setup"
            ;;
        *)
            error_exit "Unknown topology type: $TOPOLOGY_TYPE"
            ;;
    esac
    
    log SUCCESS "Topology deployment completed"
}

# Show topology status
show_status() {
    log SECTION "Topology Status"
    
    if [[ -f "$CONFIG_FILE" ]]; then
        parse_config
        log INFO "Configured topology type: $TOPOLOGY_TYPE"
    fi
    
    # Show joined networks
    log INFO "Joined networks:"
    sudo zerotier-cli listnetworks 2>/dev/null | tail -n +2 | while read -r line; do
        log INFO "  $line"
    done
    
    # Show routing status
    log INFO "IP forwarding status:"
    local ipv4_forward
    ipv4_forward=$(cat /proc/sys/net/ipv4/ip_forward)
    if [[ "$ipv4_forward" == "1" ]]; then
        log SUCCESS "  IPv4 forwarding: enabled"
    else
        log INFO "  IPv4 forwarding: disabled"
    fi
    
    # Show active interfaces
    log INFO "ZeroTier interfaces:"
    ip -brief addr show | grep zt | while read -r line; do
        log INFO "  $line"
    done
}

# Cleanup topology
cleanup_topology() {
    log SECTION "Cleaning Up Topology"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log WARN "No configuration file specified"
        return 0
    fi
    
    parse_config
    
    log WARN "This will leave all ZeroTier networks"
    read -p "Are you sure? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log INFO "Cleanup cancelled"
        return 0
    fi
    
    # Leave all networks
    log INFO "Leaving all networks..."
    sudo zerotier-cli listnetworks 2>/dev/null | tail -n +2 | awk '{print $3}' | while read -r net_id; do
        log INFO "Leaving network: $net_id"
        execute "sudo zerotier-cli leave $net_id"
    done
    
    log SUCCESS "Cleanup completed"
}

# Main function
main() {
    local command="${1:-}"
    
    if [[ -z "$command" ]]; then
        usage
    fi
    
    case "$command" in
        validate)
            validate_config
            ;;
        deploy)
            deploy_topology
            ;;
        status)
            show_status
            ;;
        cleanup)
            cleanup_topology
            ;;
        *)
            error_exit "Unknown command: $command. Use -h for help."
            ;;
    esac
}

#####################################################################
# Parse arguments
#####################################################################

parse_args() {
    # Parse options before command
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
            -t|--type)
                TOPOLOGY_TYPE="$2"
                shift 2
                ;;
            --version)
                echo "$SCRIPT_VERSION"
                exit 0
                ;;
            -*)
                error_exit "Unknown option: $1. Use -h for help."
                ;;
            *)
                # Command found, pass remaining args to main
                main "$@"
                exit 0
                ;;
        esac
    done
    
    # No command provided
    usage
}

#####################################################################
# Entry point
#####################################################################

parse_args "$@"
