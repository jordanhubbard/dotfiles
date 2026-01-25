#!/bin/bash
#
# .bashrc - Bash configuration file
#
# This file is sourced by interactive non-login shells.
# It sets up the environment, aliases, and functions for daily use.
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Set environment variable (csh-style convenience function)
setenv() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: setenv VAR [value]" >&2
        return 1
    fi
    local var=$1
    shift
    export "$var=$*"
}

# Source a file if it exists
# Usage: sourceif [-e] file [args]
#   -e: evaluate the output (for conda, etc.)
sourceif() {
    local eval_mode=0
    if [[ "$1" == "-e" ]]; then
        eval_mode=1
        shift
    fi
    
    local fname="$1"
    shift
    
    if [[ -f "$fname" ]]; then
        if [[ $eval_mode -eq 1 ]]; then
            eval "$("$fname" "$@")"
        else
            # shellcheck disable=SC1090
            source "$fname" "$@"
        fi
    fi
}

# Check if a command exists
has_command() {
    command -v "$1" &> /dev/null
}

# Check if OS matches
isOSNamed() {
    [[ "$(uname -s)" == "$1" ]]
}

# ============================================================================
# DOCKER FUNCTIONS
# ============================================================================

# Clean up Docker resources
dockercleanup() {
    echo "Cleaning up Docker resources..."
    docker image prune -f
    docker volume prune -f
    docker container prune -f
    echo "Docker cleanup complete"
}

# ============================================================================
# DOTFILES MANAGEMENT
# ============================================================================

# Edit a specific dotfile
dotedit() {
    local dotfiles_dir="${HOME}/Src/dotfiles"
    
    if [[ ! -d "$dotfiles_dir" ]]; then
        echo "Error: Dotfiles directory not found: $dotfiles_dir" >&2
        return 1
    fi
    dotsync
    TGT=dot$1

    pushd ${dotfiles_dir}
    if [ ! -f ${TGT} ]; then
	echo "${TGT} files does not exist.  Create manually in ${dotfiles_dir} first."
	return 1
    fi
    ${EDITOR-vi} ${TGT}
    git add .
    git commit
    git push
    dotsync
    popd
}

# Re-sync dotfiles from git
dotsync() {
    local dotfiles_dir="${HOME}/Src/dotfiles"
    
    if [[ ! -d "$dotfiles_dir" ]]; then
        echo "Error: Dotfiles directory not found: $dotfiles_dir" >&2
        return 1
    fi
    
    echo "Syncing dotfiles..."
    pushd "$dotfiles_dir" > /dev/null || return 1
    git pull && make install
    local status=$?
    popd > /dev/null || return 1
    return $status
}

# ============================================================================
# DNS & NETWORK UTILITIES
# ============================================================================

# Use the dns.toys DNS server to do various interesting things with DNS
# Usage: dy help - print all of the supported commands
dy() {
    if ! has_command dig; then
        echo "Error: dig command not found" >&2
        return 1
    fi
    dig +noall +answer +additional "$1" @dns.toys
}

# Check if a host is reachable
reachable() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: reachable host|ip" >&2
        return 1
    fi
    
    local host="$1"
    if ping -c 1 -W 1 "$host" > /dev/null 2>&1; then
        echo "$host is reachable"
        return 0
    else
        echo "$host is not reachable"
        return 1
    fi
}

# ============================================================================
# TIMEZONE & DATE FUNCTIONS
# ============================================================================

# Get date/time for a specific timezone
# Usage: zonedate london|paris|newyork|etc
zonedate() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: zonedate <timezone>" >&2
        echo "Example: zonedate london" >&2
        return 1
    fi
    
    local zone="$*"
    local found=0
    
    # Normalize input: remove spaces, make lowercase
    local norm_zone
    norm_zone=$(echo "$zone" | tr -d ' ' | tr '[:upper:]' '[:lower:]')

    # Auto-detect the real zoneinfo directory
    local zoneinfo_dir
    if [[ -d /usr/share/zoneinfo ]]; then
        zoneinfo_dir=$(realpath /usr/share/zoneinfo)
    else
        echo "Error: Zoneinfo directory not found" >&2
        return 2
    fi

    # Search recursively through zoneinfo for matching timezone
    while IFS= read -r tz; do
        # Remove zoneinfo_dir prefix
        local clean_tz="${tz#"$zoneinfo_dir/"}"
        
        # Normalize timezone: remove spaces, underscores, make lowercase
        local norm_clean_tz
        norm_clean_tz=$(echo "$clean_tz" | tr -d ' _' | tr '[:upper:]' '[:lower:]')
        
        # Also check the last component (e.g., 'Paris' in 'Europe/Paris')
        local last_component
        last_component=$(basename "$clean_tz")
        local norm_last_component
        norm_last_component=$(echo "$last_component" | tr -d ' _' | tr '[:upper:]' '[:lower:]')
        
        if [[ "$norm_clean_tz" == *"$norm_zone"* ]] || [[ "$norm_last_component" == "$norm_zone" ]]; then
            echo "Using timezone: $clean_tz"
            TZ="$clean_tz" date
            found=1
            break
        fi
    done < <(find "$zoneinfo_dir" -type f 2>/dev/null)

    # Handle case where timezone wasn't found
    if [[ $found -eq 0 ]]; then
        echo "Timezone '$zone' not found" >&2
        return 1
    fi
}

# Emit a UTC datestamp
date-stamp() {
    TZ=Etc/UTC date +"%Y-%m-%d %T UTC"
}

# ============================================================================
# SYSTEM BUILD FUNCTIONS
# ============================================================================

# Build the entire world for FreeBSD
makeworld() {
    if ! isOSNamed FreeBSD; then
        echo "Error: Only applicable to FreeBSD" >&2
        return 1
    fi
    
    local src_dir="/usr/src"
    if [[ ! -d "$src_dir" ]]; then
        echo "Error: Source directory not found: $src_dir" >&2
        return 1
    fi
    
    echo "Building FreeBSD world and kernel..."
    cd "$src_dir" || return 1
    git pull && sudo make -j8 world kernel DESTDIR=/ 2>&1 | tee make.out
}

# Build and install just the Linux kernel + modules
makelinux() {
    if ! isOSNamed Linux; then
        echo "Error: Only applicable to Linux" >&2
        return 1
    fi
    
    local jobs=8
    if [[ "$1" == "-j" && -n "$2" ]]; then
        jobs="$2"
    fi
    
    local linux_dir="${HOME}/Src/linux"
    if [[ ! -d "$linux_dir" ]]; then
        echo "Error: Linux source directory not found: $linux_dir" >&2
        return 1
    fi
    
    cd "$linux_dir" || return 1
    git pull || return 1
    
    # Note: clang kernel build temporarily disabled due to interop problems
    if false && has_command clang; then
        echo "Building with clang (LLVM=1)..."
        env CC=clang LLVM=1 make -j"${jobs}" && \
        sudo env CC=clang LLVM=1 make -j"${jobs}" modules_install && \
        sudo env CC=clang LLVM=1 make -j"${jobs}" install
    else
        echo "Building with gcc..."
        make -j"${jobs}" && \
        sudo make -j"${jobs}" modules_install && \
        sudo make -j"${jobs}" install
    fi
}

# ============================================================================
# FILE MANAGEMENT
# ============================================================================

# Entirely custom function for saving 3D models
save-model() {
    local down="${HOME}/Downloads"
    local models="${HOME}/Dropbox/STL-Models/_Unclassified"
    
    if [[ $# -lt 1 ]]; then
        echo "Usage: save-model <file.zip>" >&2
        return 1
    fi
    
    local name
    name="$(basename "$1" .zip)"
    
    if [[ "$name" == "$1" ]]; then
        echo "Error: Must specify a .zip file from the ${down} directory" >&2
        return 1
    fi
    
    mkdir -p "$models"
    
    if [[ ! -d "$models" ]]; then
        echo "Error: Cannot create models directory: $models" >&2
        return 1
    fi
    
    local zip_file="${down}/${name}.zip"
    if [[ ! -f "$zip_file" ]]; then
        echo "Error: File not found: $zip_file" >&2
        return 1
    fi
    
    pushd "$models" > /dev/null || return 1
    mkdir -p "$name" && \
    cd "$name" && \
    unzip "$zip_file" && \
    rm "$zip_file"
    local status=$?
    popd > /dev/null || return 1
    return $status
}

# Copy directory tree preserving permissions
copyto() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: copyto [-s] [srcdir] destdir" >&2
        return 1
    fi
    
    local use_sudo=""
    if [[ "$1" == "-s" ]]; then
        use_sudo="sudo"
        shift
    fi
    
    local src="."
    if [[ $# -ge 2 ]]; then
        src="$1"
        shift
    fi
    
    local dest="$1"
    
    if [[ ! -d "$src" ]]; then
        echo "Error: Source directory not found: $src" >&2
        return 1
    fi
    
    if [[ ! -d "$dest" ]]; then
        echo "Error: Destination directory not found: $dest" >&2
        return 1
    fi
    
    tar -cpBf - "$src" | $use_sudo tar -xpBvf - -C "$dest/"
}

# ============================================================================
# VIRTUALIZATION (KVM)
# ============================================================================

# List VMs
lsvm() {
    if ! has_command virsh; then
        echo "Error: virsh not found" >&2
        return 1
    fi
    virsh list --all
}

# Manage VMs remotely
managevm() {
    if ! has_command ssh; then
        echo "Error: ssh not found" >&2
        return 1
    fi
    local host="ubumeh4"
    [[ "$host" != *.* ]] && host="${host}.local"
    ssh -Y "$host" virt-manager
}

# ============================================================================
# KUBERNETES FUNCTIONS
# ============================================================================

# Kubernetes helper function
kubeit() {
    if ! has_command kubectl; then
        echo "Error: kubectl not found" >&2
        return 1
    fi
    
    local kubeconfig=""
    
    if [[ "$1" == "--remote" ]]; then
        kubeconfig="--kubeconfig ${HOME}/.kube/k8s-prod-hq.config"
        shift
    elif [[ "$1" == "--local" ]]; then
        kubeconfig=""
        shift
    fi
    
    local cmd
    case "$1" in
        ubuntu)
            cmd="run my-shell --attach=true -i --tty --image ubuntu -- bash"
            ;;
        token)
            cmd="describe secret -n kube-system kubernetes-dashboard"
            ;;
        dashboard)
            cmd="proxy"
            echo "Open http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/#!/node?namespace=default after proxy starts"
            ;;
        *)
            cmd="$*"
            ;;
    esac
    
    # shellcheck disable=SC2086
    kubectl $kubeconfig $cmd
}

# ============================================================================
# PACKAGE MANAGEMENT
# ============================================================================

# APT functions (Debian/Ubuntu)
aptgrep() {
    if ! has_command dpkg; then
        echo "Error: dpkg not found (not a Debian/Ubuntu system?)" >&2
        return 1
    fi
    
    if [[ $# -gt 0 ]]; then
        dpkg --get-selections | awk '{print $1}' | grep -E "$*"
    else
        dpkg --get-selections | awk '{print $1}'
    fi
}

aptupdate() {
    if ! has_command apt; then
        echo "Error: apt not found (not a Debian/Ubuntu system?)" >&2
        return 1
    fi
    
    sudo apt update && \
    sudo apt upgrade "$@" && \
    sudo depmod && \
    sudo apt autoremove
}

aptfixup() {
    if ! has_command apt-get; then
        echo "Error: apt-get not found (not a Debian/Ubuntu system?)" >&2
        return 1
    fi
    
    sudo apt-get update --fix-missing && \
    sudo apt-get install -f && \
    sudo apt autoremove
}

# MacPorts functions (macOS)
portupdate() {
    if ! has_command port; then
        echo "Error: port not found (MacPorts not installed?)" >&2
        return 1
    fi
    
    # Update local ports tree if it exists
    if [[ -d "${HOME}/Src/macports-ports/" ]]; then
        pushd "${HOME}/Src/macports-ports/" > /dev/null || return 1
        git pull && portindex
        popd > /dev/null || return 1
        
        if [[ -d "${HOME}/Src/macports-base/" ]]; then
            pushd "${HOME}/Src/macports-base" > /dev/null || return 1
            git pull && make all && sudo make install
            popd > /dev/null || return 1
        fi
    fi
    
    sudo port "$@" selfupdate && \
    sudo port "$@" upgrade outdated && \
    sudo port "$@" reclaim
}

# Python pip helper
pipit() {
    if ! has_command pip; then
        echo "Error: pip not found" >&2
        return 1
    fi
    pip install -U --user "$@"
}

# ============================================================================
# DEVELOPMENT TOOLS
# ============================================================================

# Git clone with submodules
gitcl() {
    if ! has_command git; then
        echo "Error: git not found" >&2
        return 1
    fi
    git clone --recurse-submodules "$@"
}

# Get a repo all the way back to upstream
gitreset() {
    set -e

    git fetch --all --prune

    # Prefer: upstream of current branch (if we have one)
    if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
        target='@{u}'
    else
        # Otherwise: pick a sensible default ref without checking out the branch
        if git show-ref --verify --quiet refs/remotes/origin/main; then
            target='refs/remotes/origin/main'
        elif git show-ref --verify --quiet refs/remotes/upstream/main; then
            target='refs/remotes/upstream/main'
        else
            echo "gitreset: can't find origin/main or upstream/main"
            return 1
        fi
    fi

    # Reset index + working tree to the target commit (no need to own the branch)
    git reset --hard "$target"
    git clean -fdx
}

# Find symbol in files
findsym() {
    local grepargs=""
    if echo "$1" | grep -q -e '-'; then
        grepargs="$1"
        shift
    fi
    
    local dir="."
    if [[ $# -ge 2 ]]; then
        dir="$1"
        shift
    fi
    
    if [[ $# -lt 1 ]]; then
        echo "Usage: findsym [-grep-args] [dir] pattern" >&2
        return 1
    fi
    
    # shellcheck disable=SC2086
    find "$dir" -type f -a ! -path '*/.git/*' -print0 | \
        xargs -0 grep $grepargs "$1"
}

# Find files by name
findfile() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: findfile pattern [dir]" >&2
        return 1
    fi
    
    local matchargs="$1"
    shift
    
    local dir="."
    if [[ $# -ge 1 ]]; then
        dir="$1"
        shift
    fi
    
    find "$dir" -name "$matchargs" -a ! -path '*/.git/*' -print
}

# Rabid C compiler warnings
cc-rabid() {
    cc -W -Wall -ansi -pedantic -Wbad-function-cast -Wcast-align \
        -Wcast-qual -Wchar-subscripts -Wconversion -Winline \
        -Wmissing-prototypes -Wnested-externs -Wpointer-arith \
        -Redundant-decls -Wshadow -Wstrict-prototypes \
        -Wwrite-strings "$@"
}

# ============================================================================
# CONVENIENCE FUNCTIONS
# ============================================================================

# Make directory and cd into it
mkcd() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: mkcd directory" >&2
        return 1
    fi
    mkdir -p "$1" && cd "$1" || return 1
}

# Process listing helpers
psm() {
    ps ax | more
}

psg() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: psg pattern" >&2
        return 1
    fi
    ps ax | grep "$*"
}

# List with time sort
lst() {
    ls -lt "$@" | more
}

# VNC connection helper
vc() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: vc hostname" >&2
        return 1
    fi
    local host="$1"
    [[ "$host" != *.* ]] && host="${host}.local"
    open "vnc://${host}"
}

# SSH helpers
sm() {
    SSH_CMD=mosh s "$@"
}

s() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: s hostname [-r] [ssh-args]" >&2
        return 1
    fi
    
    local host="$1"
    shift
    
    local user="jkh"
    if [[ "$1" == "-r" ]]; then
        user="root"
        shift
    fi
    
    [[ "$host" != *.* ]] && host="${host}.local"
    ${SSH_CMD:-ssh} "$@" "${user}@${host}"
}

# Remote tmux session
remote-tmux() {
    if [[ $# -lt 2 ]]; then
        echo "Usage: remote-tmux host command" >&2
        return 1
    fi
    
    local host="$1"
    shift
    ssh "$host" tmux new-session -d sh "$*"
}

# Cross-platform open command
open() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if has_command xdg-open; then
            xdg-open "$@"
        else
            echo "Error: xdg-open not found" >&2
            return 1
        fi
    elif [[ "$OSTYPE" == darwin* ]]; then
        /usr/bin/open "$@"
    else
        echo "Error: open not supported on this platform" >&2
        return 1
    fi
}

# Find macOS package receipt
find-receipt() {
    if ! isOSNamed Darwin; then
        echo "Error: Only applicable to macOS" >&2
        return 1
    fi
    
    if [[ $# -lt 1 ]]; then
        echo "Usage: find-receipt pattern" >&2
        return 1
    fi
    
    for i in /Library/Receipts/*.pkg; do
        if [[ -f "$i/Contents/Archive.bom" ]]; then
            if lsbom -f -d -l "$i/Contents/Archive.bom" | grep -q "$1"; then
                echo "$1 is in $i"
            fi
        fi
    done
}

# Enable XRDP on Linux
enable-xrdp() {
    if ! isOSNamed Linux; then
        echo "Error: Only applicable to Linux" >&2
        return 1
    fi
    
    sudo apt install xrdp ufw && \
    sudo systemctl enable --now xrdp && \
    sudo ufw allow from any to any port 3389 proto tcp
}

# ============================================================================
# PROMPT CONFIGURATION
# ============================================================================

# Set window title
title() {
    use-boring-prompt
    echo -ne "\033]0;$*\007"
}

# Fancy prompt with colors
use-fancy-prompt() {
    if [[ "$TERM" != "cons25" && "$TERM" != "dumb" ]]; then
        PS1='\[\033]0;\h:\w\007\]\u@\h-> \[\033[0m\]'
    else
        PS1='\u@\h-> '
    fi
}

# Simple prompt
use-boring-prompt() {
    PS1='\u@\h-> '
}

# ============================================================================
# ENVIRONMENT SETUP
# ============================================================================

set-environment-vars() {
    # Basic paths
    setenv PATH "/sbin:/usr/sbin:/bin:/usr/bin:${HOME}/Bin:${HOME}/.local/bin"
    setenv MANPATH "/usr/share/man"
    setenv INFOPATH "/usr/share/info"
    
    # Tool configurations
    setenv ERL_AFLAGS "-kernel shell_history enabled"
    setenv EDITOR vi
    setenv ELIXIR_EDITOR emacs
    setenv HISTCONTROL "ignoredups:erasedups"
    
    # Homebrew (macOS)
    if [[ -d "/opt/homebrew" ]]; then
        setenv HOMEBREW_PREFIX "/opt/homebrew"
        setenv HOMEBREW_CELLAR "/opt/homebrew/Cellar"
        setenv HOMEBREW_REPOSITORY "/opt/homebrew"
    fi
    
    # Go
    [[ -z "$GOPATH" ]] && export GOPATH="${HOME}/gocode"
    
    # NVM
    local nvm_init="/opt/local/share/nvm/init-nvm.sh"
    [[ -f "$nvm_init" ]] && source "$nvm_init"
    
    # Directories to search for binaries, libraries, and man pages
    local cooldirs=(
        "${HOME}/.local"
        "${HOME}/.cabal"
        "${HOME}/.ghcup"
        "${HOME}/.cargo"
        "/opt/local"
        "/snap"
        "/opt/X11"
        "/usr/local/cuda"
        "/usr/local"
        "${HOMEBREW_PREFIX:-}"
        "${GOPATH}"
    )
    
    # Add Python user base if available
    if has_command python; then
        local python_site
        python_site=$(python -m site --user-base 2>/dev/null)
        [[ -n "$python_site" ]] && cooldirs=("$python_site" "${cooldirs[@]}")
    fi
    
    # Build paths from cooldirs
    for dir in "${cooldirs[@]}"; do
        [[ -z "$dir" || ! -d "$dir" ]] && continue
        
        [[ -d "$dir/sbin" ]] && PATH="$dir/sbin:$PATH"
        [[ -d "$dir/bin" ]] && PATH="$dir/bin:$PATH"
        [[ -d "$dir/lib" ]] && LD_LIBRARY_PATH="$dir/lib:${LD_LIBRARY_PATH:-}"
        [[ -d "$dir/man" ]] && MANPATH="$dir/man:$MANPATH"
        [[ -d "$dir/share/man" ]] && MANPATH="$dir/share/man:$MANPATH"
        [[ -d "$dir/info" ]] && INFOPATH="$dir/info:$INFOPATH"
    done
    
    # Add current directory to PATH (be careful with this!)
    PATH="$PATH:."
    
    # Export library path if set
    [[ -n "${LD_LIBRARY_PATH:-}" ]] && export LD_LIBRARY_PATH
    
    # Ollama configuration
    setenv OLLAMA_HOST "http://localhost:11434"
    setenv OLLAMA_API_BASE "${OLLAMA_HOST}"
}

# ============================================================================
# ALIASES
# ============================================================================

set-aliases() {
    # Download with resume support
    alias fetch='curl -C - -O'
    
    # macOS JavaScriptCore
    if [[ -f "/System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Resources/jsc" ]]; then
        alias jsc='/System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Resources/jsc'
    fi
    
    # Directory navigation
    alias pu='pushd'
    alias po='popd'
    
    # Bash rehash
    alias rehash='hash -r'
    
    # Grep with color
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
}

# ============================================================================
# INITIALIZATION
# ============================================================================

# Source external configurations
sourceif "${HOME}/.cargo/env"
sourceif "${HOME}/.asdf/asdf.sh"
sourceif -e "${HOME}/opt/anaconda3/bin/conda" shell.bash hook
sourceif -e "${HOME}/anaconda3/bin/conda" shell.bash hook

# Shell options
shopt -s histappend          # Append to history file
shopt -s checkwinsize        # Update LINES and COLUMNS after each command
shopt -s cmdhist             # Save multi-line commands as one history entry
shopt -s histappend          # Append to history, don't overwrite

# History configuration
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoredups:erasedups

# AI tool configuration
BAISH_OPENAI_BASE_URL=http://sparky.local
BAISH_MODEL=nvidia/NVIDIA-Nemotron-3-Nano-30B-A3B-FP8

# Apply settings
set-environment-vars
set-aliases

# Set prompt
[[ "$TERM" == "dumb" ]] || use-fancy-prompt

# ============================================================================
# LOCAL OVERRIDES
# ============================================================================

# Source local bashrc if it exists (for machine-specific settings)
sourceif "${HOME}/.bashrc.local"
