#!/usr/bin/env bash

#
# open-notebook.sh - Start remote Jupyter notebook and open in browser
#
# This script connects to a remote host, starts a Jupyter notebook server,
# and automatically opens the notebook URL in your local browser.
#
# Usage: open-notebook.sh [-H host] [-u user] [-d dir]
#   -H HOST   Remote hostname (default: megamind.local)
#   -u USER   Remote username (default: jkh)
#   -d DIR    Remote notebook directory (default: Src/Notebooks)
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
Usage: $(basename "$0") [-H host] [-u user] [-d dir] [-h]

Start a remote Jupyter notebook server and open it in your browser.

Options:
  -H HOST   Remote hostname (default: megamind.local)
  -u USER   Remote username (default: jkh)
  -d DIR    Remote notebook directory (default: Src/Notebooks)
  -h        Show this help message

Examples:
  $(basename "$0")                           # Use defaults
  $(basename "$0") -H myserver.local         # Connect to different host
  $(basename "$0") -u myuser -d Projects     # Custom user and directory

EOF
	exit "${1:-0}"
}

# Cleanup function
cleanup() {
	local exit_code=$?
	if [[ -n "${TEMP_FILE:-}" && -f "$TEMP_FILE" ]]; then
		rm -f "$TEMP_FILE"
	fi
	exit $exit_code
}

trap cleanup EXIT INT TERM

# Default values
HOST="megamind.local"
USER="jkh"
REMOTE_DIR="Src/Notebooks"

# Parse options
while getopts "H:u:d:h" opt; do
	case "$opt" in
	H)
		HOST="$OPTARG"
		;;
	u)
		USER="$OPTARG"
		;;
	d)
		REMOTE_DIR="$OPTARG"
		;;
	h)
		usage 0
		;;
	*)
		usage 1
		;;
	esac
done

# Validate prerequisites
if ! command -v ssh &>/dev/null; then
	die "ssh command not found"
fi

if ! command -v open &>/dev/null; then
	die "open command not found (are you on macOS?)"
fi

# Create temporary file for capturing output
TEMP_FILE=$(mktemp /tmp/jupyter-notebook.XXXXXX)

info "Remote Jupyter Notebook Launcher"
info "================================"
info "Host: ${USER}@${HOST}"
info "Directory: ${REMOTE_DIR}"
info "Output captured to: ${TEMP_FILE}"
echo ""

# Test SSH connection first
info "Testing SSH connection..."
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "${USER}@${HOST}" true 2>/dev/null; then
	warn "SSH key authentication may not be set up"
	info "You may need to enter your password..."
fi

# Function to extract and open URL
open_notebook_url() {
	local temp_file="$1"
	local max_attempts=30
	local attempt=0

	info "Waiting for Jupyter server to start..."

	while [[ $attempt -lt $max_attempts ]]; do
		if [[ -f "$temp_file" ]]; then
			# Look for Jupyter notebook URL
			local url
			url=$(grep -E '^\s+http://(127\.0\.0\.1|localhost|0\.0\.0\.0):' "$temp_file" | head -n1 | awk '{print $1}')

			if [[ -n "$url" ]]; then
				success "Found Jupyter URL: $url"
				info "Opening in browser..."
				open "$url"
				return 0
			fi
		fi

		sleep 1
		((attempt++))
	done

	warn "Could not detect Jupyter URL after ${max_attempts} seconds"
	warn "Check ${temp_file} for the URL and open manually"
	return 1
}

# Start the URL opener in background
(open_notebook_url "$TEMP_FILE") &
OPENER_PID=$!

# SSH command to start Jupyter
JUPYTER_CMD="cd ${REMOTE_DIR} 2>/dev/null || cd ~ && jupyter notebook --no-browser --ip=0.0.0.0"

info "Connecting to ${USER}@${HOST}..."
info "Starting Jupyter notebook..."
echo ""
warn "Press Ctrl+C to stop the notebook server"
echo ""

# Run the SSH command and tee output
if ssh "${USER}@${HOST}" "$JUPYTER_CMD" 2>&1 | tee "$TEMP_FILE"; then
	success "Session ended normally"
else
	EXIT_CODE=$?
	if [[ $EXIT_CODE -eq 130 ]]; then
		info "Interrupted by user"
	else
		error "SSH session ended with error code: $EXIT_CODE"
	fi
fi

# Wait for opener process to finish
if kill -0 $OPENER_PID 2>/dev/null; then
	wait $OPENER_PID 2>/dev/null || true
fi
