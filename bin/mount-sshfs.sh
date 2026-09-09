#!/usr/bin/env bash

#
# mount-sshfs.sh - Mount remote filesystems via SSHFS
#
# This script mounts a remote directory via SSHFS with sensible options
# for macOS. Originally designed for 3D printer file access.
#
# Usage: mount-sshfs.sh [-u user] [-p port] [-r remote_path] [-l local_path] hostname
#   -u USER   Remote username (default: root)
#   -p PORT   SSH port (default: 22)
#   -r PATH   Remote path (default: /dos/)
#   -l PATH   Local mount point (default: ~/hostname)
#   -h        Show this help
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/shell-common.sh
source "${SCRIPT_DIR}/lib/shell-common.sh"
# shellcheck source=lib/remote-common.sh
source "${SCRIPT_DIR}/lib/remote-common.sh"

usage() {
	cat <<EOF
Usage: $(basename "$0") [-u user] [-p port] [-r remote_path] [-l local_path] hostname

Mount a remote filesystem via SSHFS.

Options:
  -u USER   Remote username (default: root)
  -p PORT   SSH port (default: 22)
  -r PATH   Remote path to mount (default: /dos/)
  -l PATH   Local mount point (default: ~/hostname)
  -h        Show this help message

Examples:
  $(basename "$0") myprinter                    # Mount root@myprinter.local:/dos/
  $(basename "$0") -u pi mypi                   # Mount pi@mypi.local:/dos/
  $(basename "$0") -r /home -l ~/mnt myserver   # Mount myserver.local:/home to ~/mnt

Notes:
  - SSHFS must be installed (brew install macfuse and sshfs on macOS)
  - SSH key authentication is recommended for passwordless mounting
  - The hostname will have '.local' appended automatically

EOF
	exit "${1:-0}"
}

# Check prerequisites
check_prerequisites() {
	require_command ssh "ssh command not found"
	require_command sshfs \
		"sshfs not found. Install with: brew install --cask macfuse && brew install gromgit/fuse/sshfs-mac"
}

# Check if mount point is already mounted
is_mounted() {
	local mount_point="$1"
	if mount | grep -Fq " on ${mount_point} "; then
		return 0
	fi
	return 1
}

# Default values
REMOTE_USER="root"
PORT="22"
REMOTE_PATH="/dos/"
LOCAL_PATH=""

# Parse options
while getopts "u:p:r:l:h" opt; do
	case "$opt" in
	u)
		REMOTE_USER="$OPTARG"
		;;
	p)
		PORT="$OPTARG"
		validate_port "$PORT"
		;;
	r)
		REMOTE_PATH="$OPTARG"
		;;
	l)
		LOCAL_PATH="$OPTARG"
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

# Validate hostname argument
if [[ $# -lt 1 ]]; then
	error "Missing hostname argument"
	usage 1
fi

HOST="$1"

# Validate hostname
if [[ -z "$HOST" ]]; then
	die "Hostname cannot be empty"
fi

check_prerequisites

# Set default local path if not specified
if [[ -z "$LOCAL_PATH" ]]; then
	LOCAL_PATH="${HOME}/${HOST}"
fi

# Construct the target without appending .local to an existing FQDN.
FULL_HOST="$(remote_fqdn "$HOST")"
REMOTE_TARGET="${REMOTE_USER}@${FULL_HOST}"

info "SSHFS Mount Configuration"
info "========================="
info "Remote: ${REMOTE_TARGET}:${REMOTE_PATH}"
info "Local:  ${LOCAL_PATH}"
info "Port:   ${PORT}"
echo ""

# Check if already mounted
if is_mounted "$LOCAL_PATH"; then
	die "Already mounted at: $LOCAL_PATH"
fi

# Create mount point if it doesn't exist
if [[ ! -d "$LOCAL_PATH" ]]; then
	info "Creating mount point: $LOCAL_PATH"
	mkdir -p "$LOCAL_PATH" || die "Failed to create mount point"
fi

# Check if mount point is empty
if [[ -n "$(ls -A "$LOCAL_PATH" 2>/dev/null)" ]]; then
	warn "Mount point is not empty: $LOCAL_PATH"
	read -rp "Continue anyway? [y/N] " response
	if [[ ! "$response" =~ ^[Yy]$ ]]; then
		die "Aborted by user"
	fi
fi

# Test SSH connectivity first
info "Testing SSH connection to ${REMOTE_TARGET}:${PORT}..."
if ! remote_ssh_available "$REMOTE_TARGET" "$PORT"; then
	warn "SSH connection test failed. This might be normal if you need password/interactive auth."
	info "Proceeding with mount attempt..."
fi

# Mount options optimized for macOS
MOUNT_OPTIONS=(
	"port=${PORT}"
	"auto_cache"
	"reconnect"
	"defer_permissions"
	"noappledouble"
	"negative_vncache"
	"volname=${HOST}"
)

REMOTE_SPEC="${REMOTE_TARGET}:${REMOTE_PATH}"
MOUNT_OPTIONS_CSV="$(
	IFS=,
	echo "${MOUNT_OPTIONS[*]}"
)"
SSHFS_CMD=(sshfs "$REMOTE_SPEC" "$LOCAL_PATH" "-o${MOUNT_OPTIONS_CSV}")

info "Mounting..."
info "Command: $(shell_join "${SSHFS_CMD[@]}")"

# Attempt to mount
if "${SSHFS_CMD[@]}"; then
	success "Successfully mounted ${FULL_HOST}:${REMOTE_PATH} at ${LOCAL_PATH}"
	echo ""
	info "To unmount, run: umount \"${LOCAL_PATH}\""
	exit 0
else
	error "Failed to mount filesystem"
	error "Troubleshooting:"
	error "  1. Check SSH connection: ssh -p ${PORT} ${REMOTE_TARGET}"
	error "  2. Verify remote path exists: ${REMOTE_PATH}"
	error "  3. Ensure SSHFS/macFUSE is properly installed"
	exit 1
fi
