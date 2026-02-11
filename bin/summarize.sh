#!/usr/bin/env bash

#
# summarize.sh - Wrapper script for summarize-document.py
#
# This is a convenience wrapper that calls the summarize-document.py script
# from a standard location.
#
# Usage: summarize.sh [options] document prompt
#   See summarize-document.py -h for full options
#

set -euo pipefail

# Try to locate the Python script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="summarize-document.py"

# Look for the script in these locations
POSSIBLE_LOCATIONS=(
	"${SCRIPT_DIR}/${SCRIPT_NAME}"
	"${HOME}/Bin/${SCRIPT_NAME}"
	"${HOME}/bin/${SCRIPT_NAME}"
	"${HOME}/.local/bin/${SCRIPT_NAME}"
)

SCRIPT_PATH=""
for location in "${POSSIBLE_LOCATIONS[@]}"; do
	if [[ -f "$location" ]]; then
		SCRIPT_PATH="$location"
		break
	fi
done

if [[ -z "$SCRIPT_PATH" ]]; then
	echo "Error: Cannot find ${SCRIPT_NAME}" >&2
	echo "Looked in:" >&2
	for location in "${POSSIBLE_LOCATIONS[@]}"; do
		echo "  - $location" >&2
	done
	exit 1
fi

# Check for Python 3
if ! command -v python3 &>/dev/null; then
	echo "Error: python3 not found" >&2
	exit 1
fi

# Execute the Python script with all arguments
exec python3 "$SCRIPT_PATH" "$@"
