#!/usr/bin/env bash

#
# wakehost.sh - Wake up hosts using Wake-on-LAN
#
# This script sends a Wake-on-LAN magic packet to wake up registered hosts.
#
# Usage: wakehost.sh [-l] hostname
#   -l        List available hosts
#   -h        Show this help
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

die() {
    error "$*"
    exit 1
}

usage() {
    cat << 'EOF'
Usage: wakehost.sh [-l] [-h] hostname

Wake up a host using Wake-on-LAN.

Options:
  -l        List available hosts
  -h        Show this help message

Examples:
  wakehost.sh megamind        # Wake up megamind
  wakehost.sh -l              # List all registered hosts

EOF
    exit "${1:-0}"
}

# Host database: hostname -> MAC address
# Add your hosts here in the format: [hostname]="MAC:ADDRESS"
declare -A HOSTS=(
    [megamind]="a8:a1:59:17:7a:54"
    [fluffy]="f8:ff:c2:46:45:29"
    [nvwaffle]="3c:22:fb:e5:21:03"
)

# List available hosts
list_hosts() {
    echo "Registered hosts:"
    echo ""
    printf "  %-20s %s\n" "HOSTNAME" "MAC ADDRESS"
    printf "  %-20s %s\n" "--------" "-----------"
    
    for host in "${!HOSTS[@]}"; do
        printf "  %-20s %s\n" "$host" "${HOSTS[$host]}"
    done | sort
    
    echo ""
    echo "Total: ${#HOSTS[@]} host(s)"
}

# Validate MAC address format
is_valid_mac() {
    local mac="$1"
    if [[ "$mac" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
        return 0
    fi
    return 1
}

# Send Wake-on-LAN packet
wake_host() {
    local hostname="$1"
    local mac="${HOSTS[$hostname]}"
    
    if [[ -z "$mac" ]]; then
        die "Host not found: $hostname"
    fi
    
    if ! is_valid_mac "$mac"; then
        die "Invalid MAC address for $hostname: $mac"
    fi
    
    info "Waking up host: $hostname"
    info "MAC address: $mac"
    
    # Try to use wakeonlan command
    if command -v wakeonlan &> /dev/null; then
        if wakeonlan "$mac"; then
            success "Magic packet sent to $hostname ($mac)"
            return 0
        else
            die "Failed to send magic packet"
        fi
    
    # Try etherwake as alternative
    elif command -v etherwake &> /dev/null; then
        if etherwake "$mac"; then
            success "Magic packet sent to $hostname ($mac)"
            return 0
        else
            die "Failed to send magic packet"
        fi
    
    # No WoL tool available
    else
        die "Wake-on-LAN tool not found. Install with: brew install wakeonlan (macOS) or apt install wakeonlan (Linux)"
    fi
}

# Parse options
LIST_ONLY=0

while getopts "lh" opt; do
    case "$opt" in
        l)
            LIST_ONLY=1
            ;;
        h)
            usage 0
            ;;
        *)
            usage 1
            ;;
    esac
done
shift $((OPTIND - 1))

# List hosts if requested
if [[ $LIST_ONLY -eq 1 ]]; then
    list_hosts
    exit 0
fi

# Validate hostname argument
if [[ $# -lt 1 ]]; then
    error "Missing hostname argument"
    echo ""
    list_hosts
    echo ""
    usage 1
fi

hostname="$1"

# Check if host is registered
if [[ -z "${HOSTS[$hostname]:-}" ]]; then
    error "Unknown host: $hostname"
    echo ""
    list_hosts
    exit 1
fi

# Wake up the host
wake_host "$hostname"
