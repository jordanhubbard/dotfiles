#!/usr/bin/env bash
#
# shell-common.sh - shared UI, validation, and dependency helpers
#
# This file is sourced by commands installed beside the lib/ directory. Keep
# it compatible with the Bash 3.2 shipped by macOS.

if [[ -n "${SHELL_COMMON_LOADED:-}" ]]; then
	return 0
fi
SHELL_COMMON_LOADED=1

SHELL_COLOR_FD="${SHELL_COLOR_FD:-2}"
if [[ -t "$SHELL_COLOR_FD" && -z "${NO_COLOR:-}" && "${TERM:-}" != "dumb" ]]; then
	SHELL_COLOR_RED=$'\033[0;31m'
	SHELL_COLOR_GREEN=$'\033[0;32m'
	SHELL_COLOR_YELLOW=$'\033[1;33m'
	SHELL_COLOR_BLUE=$'\033[0;34m'
	SHELL_COLOR_RESET=$'\033[0m'
else
	SHELL_COLOR_RED=""
	SHELL_COLOR_GREEN=""
	SHELL_COLOR_YELLOW=""
	SHELL_COLOR_BLUE=""
	SHELL_COLOR_RESET=""
fi

info() {
	printf '%s[INFO]%s %s\n' "$SHELL_COLOR_BLUE" "$SHELL_COLOR_RESET" "$*" >&2
}

warn() {
	printf '%s[WARN]%s %s\n' "$SHELL_COLOR_YELLOW" "$SHELL_COLOR_RESET" "$*" >&2
}

error() {
	printf '%s[ERROR]%s %s\n' "$SHELL_COLOR_RED" "$SHELL_COLOR_RESET" "$*" >&2
}

success() {
	printf '%s[SUCCESS]%s %s\n' "$SHELL_COLOR_GREEN" "$SHELL_COLOR_RESET" "$*" >&2
}

die() {
	error "$*"
	exit 1
}

require_command() {
	local command_name="$1"
	local message="${2:-Required command not found: ${command_name}}"

	command -v "$command_name" >/dev/null 2>&1 || die "$message"
}

require_commands() {
	local missing=()
	local command_name

	for command_name in "$@"; do
		if ! command -v "$command_name" >/dev/null 2>&1; then
			missing+=("$command_name")
		fi
	done

	if [[ ${#missing[@]} -gt 0 ]]; then
		die "Missing required commands: ${missing[*]}"
	fi
}

require_docker() {
	local missing_message="${1:-Docker not found}"
	local daemon_message="${2:-Docker daemon is not running}"

	require_command docker "$missing_message"
	docker info >/dev/null 2>&1 || die "$daemon_message"
}

validate_positive_integer() {
	local name="$1"
	local value="$2"

	[[ "$value" =~ ^[1-9][0-9]*$ ]] || die "Invalid ${name}: ${value}"
}

validate_port() {
	local value="$1"

	if [[ ! "$value" =~ ^[0-9]+$ ]] ||
	   ((10#$value < 1 || 10#$value > 65535)); then
		die "Invalid port number: ${value}"
	fi
}

shell_join() {
	local result=""
	local arg quoted_arg

	for arg in "$@"; do
		printf -v quoted_arg '%q' "$arg"
		result="${result}${result:+ }${quoted_arg}"
	done
	printf '%s\n' "$result"
}
