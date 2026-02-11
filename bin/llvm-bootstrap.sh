#!/usr/bin/env bash

#
# llvm-bootstrap.sh - Build and install LLVM from source
#
# This script clones, builds, and installs LLVM and related projects
# (clang, clang-tools-extra, lldb, compiler-rt, lld, polly)
#
# Usage: llvm-bootstrap.sh [-r] [-j n] [-b branch] [-p projects] [-d dir]
#   -r         Resume previous build (don't clean build directory)
#   -j N       Number of parallel jobs (default: auto-detect)
#   -b BRANCH  Git branch/tag to checkout (default: main)
#   -p PROJS   Semicolon-separated list of projects (default: clang;clang-tools-extra;lldb;compiler-rt;lld;polly)
#   -d DIR     Directory for LLVM project (default: $HOME/Src/llvm-project)
#   -h         Show this help
#

set -euo pipefail

# Colors for output
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
	cat <<'EOF'
Usage: llvm-bootstrap.sh [-r] [-j n] [-b branch] [-p projects] [-d dir] [-h]

Build and install LLVM from source.

Options:
  -r         Resume previous build (don't clean build directory)
  -j N       Number of parallel jobs (default: auto-detect based on CPU cores)
  -b BRANCH  Git branch/tag to checkout (default: main branch)
  -p PROJS   Semicolon-separated LLVM projects to build
             (default: clang;clang-tools-extra;lldb;compiler-rt;lld;polly)
  -d DIR     Directory for LLVM project (default: $HOME/Src/llvm-project)
  -h         Show this help message

Examples:
  llvm-bootstrap.sh                           # Build with defaults
  llvm-bootstrap.sh -j 8 -b release/17.x      # Build release 17.x with 8 jobs
  llvm-bootstrap.sh -r                        # Resume interrupted build
  llvm-bootstrap.sh -p 'clang;lld'            # Build only clang and lld

EOF
	exit "${1:-0}"
}

# Detect number of CPU cores
detect_jobs() {
	local jobs=4
	if command -v nproc &>/dev/null; then
		jobs=$(nproc)
	elif command -v sysctl &>/dev/null; then
		jobs=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
	fi
	echo "$jobs"
}

# Default values
LLVM_PROJ="${HOME}/Src/llvm-project"
RESUME=0
BRANCH=""
JOBS=$(detect_jobs)
PROJECTS="clang;clang-tools-extra;lldb;compiler-rt;lld;polly"

# Parse options
while getopts "hrj:b:p:d:" opt; do
	case "$opt" in
	h)
		usage 0
		;;
	r)
		RESUME=1
		;;
	j)
		JOBS="$OPTARG"
		if ! [[ "$JOBS" =~ ^[0-9]+$ ]] || [[ "$JOBS" -lt 1 ]]; then
			die "Invalid number of jobs: $JOBS"
		fi
		;;
	b)
		BRANCH="$OPTARG"
		;;
	p)
		PROJECTS="$OPTARG"
		;;
	d)
		LLVM_PROJ="$OPTARG"
		;;
	*)
		usage 1
		;;
	esac
done

info "LLVM Bootstrap Build Script"
info "============================"
info "Target directory: $LLVM_PROJ"
info "Parallel jobs: $JOBS"
info "Projects: $PROJECTS"
[[ -n "$BRANCH" ]] && info "Branch: $BRANCH"
[[ $RESUME -eq 1 ]] && warn "Resume mode: existing build will be continued"
echo ""

# Check for required tools
for tool in git cmake make; do
	if ! command -v "$tool" &>/dev/null; then
		die "Required tool not found: $tool"
	fi
done

# Create parent directory if needed
PARENT_DIR=$(dirname "$LLVM_PROJ")
if [[ ! -d "$PARENT_DIR" ]]; then
	info "Creating parent directory: $PARENT_DIR"
	mkdir -p "$PARENT_DIR" || die "Failed to create directory: $PARENT_DIR"
fi

# Clone or update repository
if [[ ! -d "$LLVM_PROJ" ]]; then
	# Check if we're in llvm-project directory
	if [[ -d "llvm-project/.git" ]]; then
		LLVM_PROJ="llvm-project"
		info "Found llvm-project in current directory"
	else
		info "Cloning LLVM project repository..."
		cd "$PARENT_DIR" || die "Cannot change to directory: $PARENT_DIR"

		CLONE_CMD="git clone --depth=1"
		[[ -n "$BRANCH" ]] && CLONE_CMD="$CLONE_CMD -b $BRANCH"
		CLONE_CMD="$CLONE_CMD https://github.com/llvm/llvm-project.git"

		info "Running: $CLONE_CMD"
		if ! $CLONE_CMD; then
			die "Failed to clone LLVM project"
		fi
		LLVM_PROJ="$PARENT_DIR/llvm-project"
	fi
else
	info "Using existing LLVM project at: $LLVM_PROJ"
	cd "$LLVM_PROJ" || die "Cannot change to LLVM project directory"

	if [[ $RESUME -eq 0 ]]; then
		info "Updating repository..."
		git pull || warn "Failed to update repository (continuing anyway)"
	fi
fi

# Navigate to project root
cd "$LLVM_PROJ" || die "Cannot access LLVM project directory: $LLVM_PROJ"

# Handle build directory
BUILD_DIR="$LLVM_PROJ/build"
if [[ $RESUME -eq 1 ]]; then
	if [[ ! -d "$BUILD_DIR" ]]; then
		die "Resume mode requested but no build directory exists"
	fi
	info "Resuming build in: $BUILD_DIR"
else
	if [[ -d "$BUILD_DIR" ]]; then
		warn "Removing existing build directory"
		rm -rf "$BUILD_DIR" || die "Failed to remove build directory"
	fi
	info "Creating build directory"
	mkdir -p "$BUILD_DIR" || die "Failed to create build directory"
fi

cd "$BUILD_DIR" || die "Cannot access build directory"

# Configure compiler
if command -v clang &>/dev/null; then
	export CC=clang
	export CXX=clang++
	info "Using clang compiler"
elif command -v gcc &>/dev/null; then
	export CC=gcc
	export CXX=g++
	info "Using gcc compiler"
else
	die "No suitable C/C++ compiler found"
fi

# Run CMake configuration
if [[ $RESUME -eq 0 || ! -f "CMakeCache.txt" ]]; then
	info "Running CMake configuration..."
	info "Build type: Release"
	info "Enabled projects: $PROJECTS"

	if ! cmake \
		-DCMAKE_BUILD_TYPE=Release \
		-DLLVM_ENABLE_PROJECTS="$PROJECTS" \
		-DCMAKE_INSTALL_PREFIX=/usr/local \
		../llvm; then
		die "CMake configuration failed"
	fi
	success "CMake configuration completed"
else
	info "Using existing CMake configuration"
fi

# Build
info "Building LLVM with $JOBS parallel jobs..."
info "This may take a long time (30+ minutes to several hours)"
START_TIME=$(date +%s)

if ! make -j"$JOBS"; then
	END_TIME=$(date +%s)
	ELAPSED=$((END_TIME - START_TIME))
	error "Build failed after $((ELAPSED / 60)) minutes"
	warn "You can resume the build with: $0 -r"
	exit 1
fi

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
success "Build completed in $((ELAPSED / 60)) minutes"

# Install
info "Installing LLVM (requires sudo)..."
if ! sudo make install; then
	die "Installation failed"
fi

success "LLVM installation completed successfully!"
success "Installed to: /usr/local"
echo ""
info "You may want to add /usr/local/bin to your PATH if not already present"

# Show installed version
if command -v clang &>/dev/null; then
	echo ""
	info "Installed clang version:"
	clang --version | head -n1
fi
