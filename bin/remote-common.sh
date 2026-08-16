#!/usr/bin/env bash
#
# remote-common.sh - shared host-resolution helpers for s, sc, sm
#
# Not meant to be run directly; sourced by the scripts above so that ssh,
# scp, and mosh all expand short/.local hostnames and the default remote
# user the same way.
#

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
# left untouched, so ssh and scp can share one notion of "a host". Callers
# must only pass positional source/dest specs here, never scp's own option
# flags or option values - see sc, which separates those out first.
# Usage: remote_resolve_spec [-r] spec
remote_resolve_spec() {
	local user="$REMOTE_DEFAULT_USER"
	if [[ "$1" == "-r" ]]; then
		user="root"
		shift
	fi
	local spec="$1"

	# A path starting with /, ./, or ../ is unambiguously local, even if it
	# contains a colon (matches scp's own local/remote disambiguation).
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
