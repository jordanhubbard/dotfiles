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

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Available HashiCorp tools
AVAILABLE_TOOLS="nomad terraform vault consul packer boundary waypoint"
DEFAULT_TOOLS="nomad terraform vault consul packer"

# Function to print colored output
info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

die() {
    error "$*"
    exit 1
}

# Check if running on a Debian/Ubuntu system
check_system() {
    if [[ ! -f /etc/debian_version ]]; then
        die "This script is designed for Debian/Ubuntu systems only."
    fi
    
    if [[ $EUID -eq 0 ]]; then
        warn "Running as root is not recommended. Script will use sudo when needed."
    fi
}

# Check for required commands
check_prerequisites() {
    local missing=()
    
    for cmd in curl gpg lsb_release apt-get sudo; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Missing required commands: ${missing[*]}"
    fi
}

# Install prerequisites
install_prerequisites() {
    info "Installing prerequisites..."
    sudo apt-get update || die "Failed to update package lists"
    sudo apt-get install -y gnupg software-properties-common curl \
        || die "Failed to install prerequisites"
}

# Add HashiCorp repository
add_hashicorp_repo() {
    info "Adding HashiCorp GPG key and repository..."
    
    # Download and add GPG key (using the modern method)
    if ! curl -fsSL https://apt.releases.hashicorp.com/gpg | \
         gpg --dearmor | \
         sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null; then
        die "Failed to add HashiCorp GPG key"
    fi
    
    # Add repository
    local codename
    codename=$(lsb_release -cs)
    
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $codename main" | \
        sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null || \
        die "Failed to add HashiCorp repository"
    
    # Update package lists
    info "Updating package lists..."
    sudo apt-get update || die "Failed to update package lists after adding repository"
}

# Install specified tools
install_tools() {
    local tools=("$@")
    
    if [[ ${#tools[@]} -eq 0 ]]; then
        info "No tools specified, installing default set: $DEFAULT_TOOLS"
        read -ra tools <<< "$DEFAULT_TOOLS"
    fi
    
    # Validate tool names
    for tool in "${tools[@]}"; do
        if [[ ! " $AVAILABLE_TOOLS " =~ " $tool " ]]; then
            warn "Unknown tool '$tool', skipping. Available: $AVAILABLE_TOOLS"
            continue
        fi
    done
    
    info "Installing HashiCorp tools: ${tools[*]}"
    
    # Install tools
    # shellcheck disable=SC2068
    if ! sudo apt-get install -y ${tools[@]}; then
        die "Failed to install some or all tools"
    fi
    
    info "Successfully installed: ${tools[*]}"
    
    # Show versions
    echo ""
    info "Installed versions:"
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            echo "  $tool: $($tool version 2>&1 | head -n1)"
        fi
    done
}

# Main execution
main() {
    info "HashiCorp Tools Installer"
    echo ""
    
    check_system
    check_prerequisites
    install_prerequisites
    add_hashicorp_repo
    install_tools "$@"
    
    echo ""
    info "Installation complete!"
}

main "$@"
