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

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() {
	echo -e "${BLUE}[INFO]${NC} $*"
}

warn() {
	echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
	echo -e "${RED}[ERROR]${NC} $*" >&2
}

success() {
	echo -e "${GREEN}[SUCCESS]${NC} $*"
}

die() {
	error "$*"
	exit 1
}

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
	if ! command -v sshfs &>/dev/null; then
		die "sshfs not found. Install with: brew install --cask macfuse && brew install gromgit/fuse/sshfs-mac"
	fi
}

# Check if mount point is already mounted
is_mounted() {
	local mount_point="$1"
	if mount | grep -q " on ${mount_point} "; then
		return 0
	fi
	return 1
}

# Default values
USER="root"
PORT="22"
REMOTE_PATH="/dos/"
LOCAL_PATH=""

# Parse options
while getopts "u:p:r:l:h" opt; do
	case "$opt" in
	u)
		USER="$OPTARG"
		;;
	p)
		PORT="$OPTARG"
		if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [[ "$PORT" -lt 1 ]] || [[ "$PORT" -gt 65535 ]]; then
			die "Invalid port number: $PORT"
		fi
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

# Set default local path if not specified
if [[ -z "$LOCAL_PATH" ]]; then
	LOCAL_PATH="${HOME}/${HOST}"
fi

# Construct full hostname
FULL_HOST="${HOST}.local"

info "SSHFS Mount Configuration"
info "========================="
info "Remote: ${USER}@${FULL_HOST}:${REMOTE_PATH}"
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
info "Testing SSH connection to ${USER}@${FULL_HOST}:${PORT}..."
if ! ssh -p "$PORT" -o ConnectTimeout=5 -o BatchMode=yes "${USER}@${FULL_HOST}" true 2>/dev/null; then
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

# Build the sshfs command
SSHFS_CMD="sshfs ${USER}@${FULL_HOST}:${REMOTE_PATH} ${LOCAL_PATH} -o$(
	IFS=,
	echo "${MOUNT_OPTIONS[*]}"
)"

info "Mounting..."
info "Command: $SSHFS_CMD"

# Attempt to mount
if eval "$SSHFS_CMD"; then
	success "Successfully mounted ${FULL_HOST}:${REMOTE_PATH} at ${LOCAL_PATH}"
	echo ""
	info "To unmount, run: umount \"${LOCAL_PATH}\""
	exit 0
else
	error "Failed to mount filesystem"
	error "Troubleshooting:"
	error "  1. Check SSH connection: ssh -p ${PORT} ${USER}@${FULL_HOST}"
	error "  2. Verify remote path exists: ${REMOTE_PATH}"
	error "  3. Ensure SSHFS/macFUSE is properly installed"
	exit 1
fi
