#!/usr/bin/env bash
#
# remote-common.sh - shared hostname and SSH connectivity helpers
#
# Keep this file compatible with the Bash 3.2 shipped by macOS.

: "${REMOTE_DEFAULT_USER:=jkh}"

# Expand a short hostname to an FQDN (append .local unless it already
# contains a dot).
remote_fqdn() {
	local host="$1"
	[[ "$host" == *.* ]] && printf '%s\n' "$host" || printf '%s.local\n' "$host"
}

# Resolve a bare hostname (or an explicit user@hostname) to user@fqdn.
# An explicit "user@" prefix on the hostname overrides both the default
# user and -r.
# Usage: remote_resolve_host [-r] hostname
remote_resolve_host() {
	local user="$REMOTE_DEFAULT_USER"
	if [[ "$1" == "-r" ]]; then
		user="root"
		shift
	fi
	local host="$1"
	if [[ "$host" == *"@"* ]]; then
		user="${host%%@*}"
		host="${host#*@}"
	fi
	printf '%s@%s\n' "$user" "$(remote_fqdn "$host")"
}

# Resolve an scp-style argument: bare-host:path or host:path.
# Local paths, plain flags, and specs that are already user@host:path are
# left untouched. Callers must only pass positional source/dest specs here.
# Usage: remote_resolve_spec [-r] spec
remote_resolve_spec() {
	local user="$REMOTE_DEFAULT_USER"
	if [[ "$1" == "-r" ]]; then
		user="root"
		shift
	fi
	local spec="$1"

	if [[ "$spec" == /* || "$spec" == ./* || "$spec" == ../* ]]; then
		printf '%s\n' "$spec"
		return 0
	fi

	if [[ "$spec" == *"@"* || "$spec" != *:* ]]; then
		printf '%s\n' "$spec"
		return 0
	fi

	local host="${spec%%:*}"
	local path="${spec#*:}"
	printf '%s@%s:%s\n' "$user" "$(remote_fqdn "$host")" "$path"
}

# Probe non-interactive SSH connectivity without prompting for credentials.
# Usage: remote_ssh_available target [port] [timeout_seconds]
remote_ssh_available() {
	local target="$1"
	local port="${2:-22}"
	local timeout_seconds="${3:-5}"

	ssh -p "$port" -o "ConnectTimeout=${timeout_seconds}" -o BatchMode=yes \
		"$target" true >/dev/null 2>&1
}
