#!/bin/bash

#####################################################################
# ZeroTier Installation Script
# 
# A robust installer for ZeroTier with error handling, logging,
# and support for multiple Linux distributions.
#
# Usage: ./zerotier-install.sh [OPTIONS]
#
# Options:
#   -h, --help           Show this help message
#   -v, --verbose        Enable verbose output
#   -d, --dry-run        Show what would be done without executing
#   -l, --log FILE       Log output to specified file
#   -n, --network ID     Automatically join network after install
#   -y, --yes            Skip confirmation prompts
#
#####################################################################

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Script metadata
SCRIPT_VERSION="2.0.0"
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default configuration
VERBOSE=0
DRY_RUN=0
AUTO_YES=0
LOG_FILE=""
NETWORK_ID=""
LOG_LEVEL="INFO"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#####################################################################
# Functions
#####################################################################

# Print usage information
usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

A robust installer for ZeroTier with error handling and multi-distribution support.

OPTIONS:
    -h, --help           Show this help message
    -v, --verbose        Enable verbose output
    -d, --dry-run        Show what would be done without executing
    -l, --log FILE       Log output to specified file (default: /tmp/zerotier-install.log)
    -n, --network ID     Automatically join network after install
    -y, --yes            Skip confirmation prompts
    --version            Show script version

EXAMPLES:
    # Basic installation
    $SCRIPT_NAME

    # Installation with auto-join to network
    $SCRIPT_NAME -n a1b2c3d4e5f6a7b8

    # Dry-run to see what would happen
    $SCRIPT_NAME --dry-run

    # Verbose installation with logging
    $SCRIPT_NAME -v -l /var/log/zerotier-install.log

EOF
    exit 0
}

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log to file if specified
    if [[ -n "$LOG_FILE" ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
    
    # Print to stdout based on level
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

# Error handler
error_exit() {
    log ERROR "$1"
    exit "${2:-1}"
}

# Cleanup function
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log ERROR "Script failed with exit code: $exit_code"
    fi
    exit "$exit_code"
}

# Set up trap for cleanup
trap cleanup EXIT INT TERM

# Detect Linux distribution
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

# Check if running as root or with sudo
check_root() {
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        error_exit "This script requires root privileges or sudo access. Please run with sudo."
    fi
}

# Execute command with dry-run support
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

# Check dependencies
check_dependencies() {
    log INFO "Checking dependencies..."
    
    local deps=("curl" "gpg")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log WARN "Missing dependencies: ${missing[*]}"
        log INFO "Installing missing dependencies..."
        
        local distro
        distro=$(detect_distro)
        
        case "$distro" in
            ubuntu|debian)
                execute "sudo apt-get update"
                execute "sudo apt-get install -y ${missing[*]}"
                ;;
            fedora|rhel|centos|rocky|almalinux)
                execute "sudo yum install -y ${missing[*]} || sudo dnf install -y ${missing[*]}"
                ;;
            arch|manjaro)
                execute "sudo pacman -Sy --noconfirm ${missing[*]}"
                ;;
            *)
                error_exit "Unsupported distribution: $distro. Please install: ${missing[*]}"
                ;;
        esac
    fi
    
    log SUCCESS "All dependencies satisfied"
}

# Check if ZeroTier is already installed
check_existing_installation() {
    if command -v zerotier-cli &> /dev/null; then
        local version
        version=$(zerotier-cli -v 2>/dev/null || echo "unknown")
        log WARN "ZeroTier is already installed (version: $version)"
        
        if [[ $AUTO_YES -eq 0 ]]; then
            read -p "Do you want to continue and reinstall? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log INFO "Installation cancelled by user"
                exit 0
            fi
        fi
    fi
}

# Verify GPG signature
verify_gpg_signature() {
    log INFO "Verifying ZeroTier GPG signature..."
    
    if ! execute "curl -s 'https://raw.githubusercontent.com/zerotier/ZeroTierOne/master/doc/contact%40zerotier.com.gpg' | gpg --import"; then
        error_exit "Failed to import GPG key"
    fi
    
    log SUCCESS "GPG key imported successfully"
}

# Install ZeroTier
install_zerotier() {
    log INFO "Installing ZeroTier..."
    
    # Download and verify installer
    local installer
    if ! installer=$(curl -s 'https://install.zerotier.com/' | gpg 2>&1); then
        error_exit "Failed to download or verify ZeroTier installer"
    fi
    
    # Execute installer
    if [[ $DRY_RUN -eq 1 ]]; then
        log INFO "[DRY-RUN] Would install ZeroTier"
        return 0
    fi
    
    if ! echo "$installer" | sudo bash; then
        error_exit "ZeroTier installation failed"
    fi
    
    log SUCCESS "ZeroTier installed successfully"
}

# Verify installation
verify_installation() {
    log INFO "Verifying installation..."
    
    if ! command -v zerotier-cli &> /dev/null; then
        error_exit "ZeroTier installation verification failed: zerotier-cli not found"
    fi
    
    if ! sudo zerotier-cli info &> /dev/null; then
        error_exit "ZeroTier service is not running properly"
    fi
    
    local version
    version=$(zerotier-cli -v)
    log SUCCESS "ZeroTier $version is installed and running"
}

# Join network if specified
join_network() {
    if [[ -n "$NETWORK_ID" ]]; then
        log INFO "Joining network: $NETWORK_ID"
        
        if [[ $DRY_RUN -eq 1 ]]; then
            log INFO "[DRY-RUN] Would join network: $NETWORK_ID"
            return 0
        fi
        
        if sudo zerotier-cli join "$NETWORK_ID"; then
            log SUCCESS "Successfully joined network: $NETWORK_ID"
            log INFO "Note: The node must be authorized on the network controller"
            log INFO "Visit https://my.zerotier.com/network/$NETWORK_ID to authorize"
        else
            log ERROR "Failed to join network: $NETWORK_ID"
            return 1
        fi
    fi
}

# Main installation function
main_install() {
    log INFO "Starting ZeroTier installation (version $SCRIPT_VERSION)"
    
    check_root
    check_dependencies
    check_existing_installation
    verify_gpg_signature
    install_zerotier
    verify_installation
    join_network
    
    log SUCCESS "Installation completed successfully!"
    log INFO "Use 'sudo zerotier-cli' to manage your ZeroTier node"
}

#####################################################################
# Parse command line arguments
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
            -l|--log)
                LOG_FILE="$2"
                shift 2
                ;;
            -n|--network)
                NETWORK_ID="$2"
                shift 2
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

# Set default log file if not specified
if [[ -z "$LOG_FILE" ]]; then
    LOG_FILE="/tmp/zerotier-install-$(date +%Y%m%d-%H%M%S).log"
fi

parse_args "$@"
main_install