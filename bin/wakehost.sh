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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/shell-common.sh
source "${SCRIPT_DIR}/lib/shell-common.sh"

usage() {
	cat <<'EOF'
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

# Parallel arrays keep this command compatible with macOS Bash 3.2.
HOST_NAMES=(
	"megamind"
	"fluffy"
	"nvwaffle"
)
HOST_MACS=(
	"a8:a1:59:17:7a:54"
	"f8:ff:c2:46:45:29"
	"3c:22:fb:e5:21:03"
)

mac_for_host() {
	local requested_host="$1"
	local index

	for ((index = 0; index < ${#HOST_NAMES[@]}; index++)); do
		if [[ "${HOST_NAMES[$index]}" == "$requested_host" ]]; then
			printf '%s\n' "${HOST_MACS[$index]}"
			return 0
		fi
	done
	return 1
}

# List available hosts
list_hosts() {
	echo "Registered hosts:"
	echo ""
	printf "  %-20s %s\n" "HOSTNAME" "MAC ADDRESS"
	printf "  %-20s %s\n" "--------" "-----------"

	local index
	for ((index = 0; index < ${#HOST_NAMES[@]}; index++)); do
		printf "  %-20s %s\n" "${HOST_NAMES[$index]}" "${HOST_MACS[$index]}"
	done | sort

	echo ""
	echo "Total: ${#HOST_NAMES[@]} host(s)"
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
	local mac
	mac="$(mac_for_host "$hostname")" || die "Host not found: $hostname"

	if ! is_valid_mac "$mac"; then
		die "Invalid MAC address for $hostname: $mac"
	fi

	info "Waking up host: $hostname"
	info "MAC address: $mac"

	# Try to use wakeonlan command
	if command -v wakeonlan &>/dev/null; then
		if wakeonlan "$mac"; then
			success "Magic packet sent to $hostname ($mac)"
			return 0
		else
			die "Failed to send magic packet"
		fi

	# Try etherwake as alternative
	elif command -v etherwake &>/dev/null; then
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
if ! mac_for_host "$hostname" >/dev/null; then
	error "Unknown host: $hostname"
	echo ""
	list_hosts
	exit 1
fi

# Wake up the host
wake_host "$hostname"
