#!/usr/bin/env bash

#
# start-jupyter.sh - Start Jupyter Notebook (bare-metal or containerized)
#
# This script starts a Jupyter Notebook server either directly on the host
# or inside a Docker container with GPU support.
#
# Usage: start-jupyter.sh [-d] [-r] [-c container] [-p port] [-n dir]
#   -d            Run in Docker container (default: bare-metal)
#   -r            Allow root in container (for Docker mode)
#   -c CONTAINER  Docker container image (default: nvcr.io/nvidia/tensorflow:21.09-tf1-py3)
#   -p PORT       Port number (default: 8888)
#   -n DIR        Notebooks directory (default: ~/Src/Notebooks)
#   -h            Show this help
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
    cat << 'EOF'
Usage: start-jupyter.sh [-d] [-r] [-c container] [-p port] [-n dir] [-h]

Start Jupyter Notebook server (bare-metal or containerized).

Options:
  -d            Run in Docker container with GPU support (default: bare-metal)
  -r            Allow root in container (only with -d)
  -c CONTAINER  Docker container image
                (default: nvcr.io/nvidia/tensorflow:21.09-tf1-py3)
  -p PORT       Port number (default: 8888)
  -n DIR        Notebooks directory (default: ~/Src/Notebooks or ~)
  -h            Show this help message

Examples:
  start-jupyter.sh                        # Bare-metal mode
  start-jupyter.sh -d                     # Docker mode with GPU
  start-jupyter.sh -d -r                  # Docker mode as root
  start-jupyter.sh -p 9999                # Use port 9999
  start-jupyter.sh -n ~/MyNotebooks       # Custom directory

Notes:
  - Docker mode requires nvidia-docker and GPU support
  - Increases CUDA JIT cache size for better performance
  - Binds to 0.0.0.0 for network access

EOF
    exit "${1:-0}"
}

# Default values
USE_DOCKER=0
ALLOW_ROOT=0
CONTAINER="nvcr.io/nvidia/tensorflow:21.09-tf1-py3"
PORT="8888"
NOTEBOOKS_DIR="${HOME}/Src/Notebooks"

# Parse options
while getopts "drc:p:n:h" opt; do
    case "$opt" in
        d)
            USE_DOCKER=1
            ;;
        r)
            ALLOW_ROOT=1
            ;;
        c)
            CONTAINER="$OPTARG"
            ;;
        p)
            PORT="$OPTARG"
            if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [[ "$PORT" -lt 1 ]] || [[ "$PORT" -gt 65535 ]]; then
                die "Invalid port number: $PORT"
            fi
            ;;
        n)
            NOTEBOOKS_DIR="$OPTARG"
            ;;
        h)
            usage 0
            ;;
        *)
            usage 1
            ;;
    esac
done

# Check for allow-root outside Docker mode
if [[ $ALLOW_ROOT -eq 1 && $USE_DOCKER -eq 0 ]]; then
    die "The -r flag only applies to Docker mode (-d)"
fi

# Fallback to home directory if notebooks dir doesn't exist
if [[ ! -d "$NOTEBOOKS_DIR" ]]; then
    warn "Notebooks directory not found: $NOTEBOOKS_DIR"
    NOTEBOOKS_DIR="$HOME"
    info "Using home directory instead: $NOTEBOOKS_DIR"
fi

# Expand path
NOTEBOOKS_DIR=$(cd "$NOTEBOOKS_DIR" && pwd)

info "Jupyter Notebook Launcher"
info "========================="
info "Mode: $([ $USE_DOCKER -eq 1 ] && echo "Docker" || echo "Bare-metal")"
info "Directory: $NOTEBOOKS_DIR"
info "Port: $PORT"
[[ $USE_DOCKER -eq 1 ]] && info "Container: $CONTAINER"
echo ""

# Increase CUDA JIT cache size for better performance on Ampere GPUs
export CUDA_CACHE_MAXSIZE=2147483648

# Build Jupyter command
JUPYTER_CMD="jupyter notebook --no-browser --ip=0.0.0.0 --port=${PORT}"

if [[ $USE_DOCKER -eq 1 ]]; then
    # Docker mode
    
    # Check for Docker
    if ! command -v docker &> /dev/null; then
        die "Docker not found. Install from: https://www.docker.com/products/docker-desktop"
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        die "Docker daemon is not running"
    fi
    
    # Check for nvidia-docker support
    if ! docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi &> /dev/null; then
        warn "GPU support test failed - continuing anyway, but GPU may not be available"
    fi
    
    # Set up user parameters
    USER_PARAM=()
    ROOT_FLAG=""
    
    if [[ $ALLOW_ROOT -eq 1 ]]; then
        warn "Running as root inside container"
        ROOT_FLAG="--allow-root"
    else
        USER_PARAM=("-u" "$(id -u):$(id -g)")
        info "Running as user $(id -u):$(id -g) inside container"
    fi
    
    info "Starting Jupyter in Docker container..."
    info "Container will mount: $NOTEBOOKS_DIR -> /workspace/Notebooks"
    warn "Press Ctrl+C to stop the server"
    echo ""
    
    # Run Docker container
    docker run --rm \
        --gpus all \
        "${USER_PARAM[@]}" \
        -v "${NOTEBOOKS_DIR}:/workspace/Notebooks" \
        -it \
        -p "${PORT}:${PORT}" \
        --shm-size=1g \
        --ulimit memlock=-1 \
        --ulimit stack=67108864 \
        "$CONTAINER" \
        $JUPYTER_CMD $ROOT_FLAG
        
else
    # Bare-metal mode
    
    # Check for jupyter
    if ! command -v jupyter &> /dev/null; then
        die "Jupyter not found. Install with: pip install jupyter"
    fi
    
    info "Starting Jupyter on bare metal..."
    warn "Press Ctrl+C to stop the server"
    echo ""
    
    # Change to notebooks directory and run
    cd "$NOTEBOOKS_DIR" || die "Cannot access directory: $NOTEBOOKS_DIR"
    
    # Run Jupyter
    $JUPYTER_CMD
fi
