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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/shell-common.sh
source "${SCRIPT_DIR}/lib/shell-common.sh"
# shellcheck source=lib/remote-common.sh
source "${SCRIPT_DIR}/lib/remote-common.sh"

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
	trap - EXIT
	if [[ -n "${OPENER_PID:-}" ]] && kill -0 "$OPENER_PID" 2>/dev/null; then
		kill "$OPENER_PID" 2>/dev/null || true
		wait "$OPENER_PID" 2>/dev/null || true
	fi
	if [[ -n "${TEMP_FILE:-}" && -f "$TEMP_FILE" ]]; then
		rm -f "$TEMP_FILE"
	fi
	exit "$exit_code"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Default values
HOST="megamind.local"
REMOTE_USER="jkh"
REMOTE_DIR="Src/Notebooks"

# Parse options
while getopts "H:u:d:h" opt; do
	case "$opt" in
	H)
		HOST="$OPTARG"
		;;
	u)
		REMOTE_USER="$OPTARG"
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
shift $((OPTIND - 1))

# Validate prerequisites and normalize the target consistently with s/sc.
require_command ssh "ssh command not found"
require_command open "open command not found (are you on macOS?)"
HOST="$(remote_fqdn "$HOST")"
REMOTE_TARGET="${REMOTE_USER}@${HOST}"

# Create temporary file for capturing output
TEMP_ROOT="${TMPDIR:-/tmp}"
TEMP_FILE=$(mktemp "${TEMP_ROOT%/}/jupyter-notebook.XXXXXX")

info "Remote Jupyter Notebook Launcher"
info "================================"
info "Host: ${REMOTE_TARGET}"
info "Directory: ${REMOTE_DIR}"
info "Output captured to: ${TEMP_FILE}"
echo ""

# Test SSH connection first
info "Testing SSH connection..."
if ! remote_ssh_available "$REMOTE_TARGET"; then
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
			url=$(awk '/^[[:space:]]+http:\/\/(127\.0\.0\.1|localhost|0\.0\.0\.0):/ {print $1; exit}' "$temp_file")

			if [[ -n "$url" ]]; then
				local browser_url="$url"
				browser_url="${browser_url/#http:\/\/127.0.0.1:/http://${HOST}:}"
				browser_url="${browser_url/#http:\/\/localhost:/http://${HOST}:}"
				browser_url="${browser_url/#http:\/\/0.0.0.0:/http://${HOST}:}"

				success "Found Jupyter URL: $url"
				info "Opening in browser..."
				open "$browser_url"
				return 0
			fi
		fi

		sleep 1
		((attempt += 1))
	done

	warn "Could not detect Jupyter URL after ${max_attempts} seconds"
	warn "Check ${temp_file} for the URL and open manually"
	return 1
}

quote_for_remote_shell() {
	local value="$1"
	value=${value//\'/\'\\\'\'}
	printf "'%s'" "$value"
}

# Start the URL opener in background
(open_notebook_url "$TEMP_FILE") &
OPENER_PID=$!

# SSH command to start Jupyter
REMOTE_DIR_QUOTED=$(quote_for_remote_shell "$REMOTE_DIR")
JUPYTER_CMD="if ! cd ${REMOTE_DIR_QUOTED} 2>/dev/null; then cd ~ || exit 1; fi; exec jupyter notebook --no-browser --ip=0.0.0.0"

info "Connecting to ${REMOTE_TARGET}..."
info "Starting Jupyter notebook..."
echo ""
warn "Press Ctrl+C to stop the notebook server"
echo ""

# Run the SSH command and tee output
SESSION_STATUS=0
if ssh "$REMOTE_TARGET" "$JUPYTER_CMD" 2>&1 | tee "$TEMP_FILE"; then
	success "Session ended normally"
else
	SESSION_STATUS=$?
	if [[ $SESSION_STATUS -eq 130 ]]; then
		info "Interrupted by user"
	else
		error "SSH session ended with error code: $SESSION_STATUS"
	fi
fi

# Wait for opener process to finish
if kill -0 $OPENER_PID 2>/dev/null; then
	wait $OPENER_PID 2>/dev/null || true
fi

exit "$SESSION_STATUS"
