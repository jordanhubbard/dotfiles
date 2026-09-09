#!/usr/bin/env bash

#
# install-hashicorp.sh - Install HashiCorp tools on Debian/Ubuntu systems
#
# This script installs HashiCorp tools (Nomad, Terraform, Vault, Consul, Packer)
# from the official HashiCorp APT repository.
#
# Usage: ./install-hashicorp.sh [tool1 tool2 ...]
#   If no tools specified, installs: nomad terraform vault consul packer
#
# Example:
#   ./install-hashicorp.sh terraform vault
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/shell-common.sh
source "${SCRIPT_DIR}/lib/shell-common.sh"

# Available HashiCorp tools
AVAILABLE_TOOLS="nomad terraform vault consul packer boundary waypoint"
DEFAULT_TOOLS="nomad terraform vault consul packer"

PRIVILEGE_CMD=()

# Check if running on a Debian/Ubuntu system
check_system() {
	if [[ ! -f /etc/debian_version ]]; then
		die "This script is designed for Debian/Ubuntu systems only."
	fi

	if [[ $EUID -ne 0 ]]; then
		require_command sudo "sudo is required when not running as root"
		PRIVILEGE_CMD=(sudo)
	fi
}

# Run a command directly as root or through sudo for an unprivileged caller.
as_root() {
	if [[ ${#PRIVILEGE_CMD[@]} -gt 0 ]]; then
		"${PRIVILEGE_CMD[@]}" "$@"
	else
		"$@"
	fi
}

# Install prerequisites
install_prerequisites() {
	info "Installing prerequisites..."
	as_root apt-get update || die "Failed to update package lists"
	as_root apt-get install -y gnupg software-properties-common curl lsb-release ||
		die "Failed to install prerequisites"
	require_commands curl gpg lsb_release
}

# Add HashiCorp repository
add_hashicorp_repo() {
	info "Adding HashiCorp GPG key and repository..."

	# Download and add GPG key (using the modern method)
	if ! curl -fsSL https://apt.releases.hashicorp.com/gpg |
		gpg --dearmor |
		as_root tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null; then
		die "Failed to add HashiCorp GPG key"
	fi

	# Add repository
	local codename
	codename=$(lsb_release -cs)

	echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $codename main" |
		as_root tee /etc/apt/sources.list.d/hashicorp.list >/dev/null ||
		die "Failed to add HashiCorp repository"

	# Update package lists
	info "Updating package lists..."
	as_root apt-get update || die "Failed to update package lists after adding repository"
}

# Install specified tools
install_tools() {
	local requested=("$@")
	local tools=()

	if [[ ${#requested[@]} -eq 0 ]]; then
		info "No tools specified, installing default set: $DEFAULT_TOOLS"
		read -ra requested <<<"$DEFAULT_TOOLS"
	fi

	# Validate tool names
	for tool in "${requested[@]}"; do
		case " $AVAILABLE_TOOLS " in
		*" $tool "*) ;;
		*)
			warn "Unknown tool '$tool', skipping. Available: $AVAILABLE_TOOLS"
			continue
			;;
		esac
		tools+=("$tool")
	done

	if [[ ${#tools[@]} -eq 0 ]]; then
		die "No valid HashiCorp tools selected"
	fi

	info "Installing HashiCorp tools: ${tools[*]}"

	# Install tools
	if ! as_root apt-get install -y "${tools[@]}"; then
		die "Failed to install some or all tools"
	fi

	info "Successfully installed: ${tools[*]}"

	# Show versions
	echo ""
	info "Installed versions:"
	for tool in "${tools[@]}"; do
		if command -v "$tool" &>/dev/null; then
			echo "  $tool: $($tool version 2>&1 | head -n1)"
		fi
	done
}

# Main execution
main() {
	info "HashiCorp Tools Installer"
	echo ""

	check_system
	require_command apt-get "apt-get is required on Debian/Ubuntu"
	install_prerequisites
	add_hashicorp_repo
	install_tools "$@"

	echo ""
	info "Installation complete!"
}

main "$@"
