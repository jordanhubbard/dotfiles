#!/bin/bash

setenv() {
    _SYM=$1; shift; export $_SYM="$*"
}

dockercleanup() {
    docker image prune
    docker volume prune
    docker container prune
}

# Re-sync dotfiles from git.
dotsync() {
    pushd $HOME/Src/dotfiles && git pull && make install && popd
}

# Use the dns.toys DNS server to do various interesting things with DNS.
# dy help - print all of the supported commands
dy() {
    dig +noall +answer +additional "$1" @dns.toys;
}

zonedate() {
    local zone="$*"
    local found=0
    
    # Normalize input: remove spaces, make lowercase
    local norm_zone
    norm_zone=$(echo "$zone" | tr -d ' ' | tr '[:upper:]' '[:lower:]')

    # Auto-detect the real zoneinfo directory
    local zoneinfo_dir
    zoneinfo_dir=$(realpath /usr/share/zoneinfo)
    if [[ ! -d $zoneinfo_dir ]]; then
        echo "Zoneinfo directory not found: $zoneinfo_dir"
        return 2
    fi

    # Search recursively through zoneinfo for matching timezone
    while IFS= read -r tz; do
        # Remove zoneinfo_dir prefix
        clean_tz=$(echo "$tz" | sed "s|$zoneinfo_dir/||")
        # Normalize timezone: remove spaces, underscores, make lowercase
        norm_clean_tz=$(echo "$clean_tz" | tr -d ' _' | tr '[:upper:]' '[:lower:]')
        # Also check the last component (e.g., 'Paris' in 'Europe/Paris')
        last_component=$(basename "$clean_tz")
        norm_last_component=$(echo "$last_component" | tr -d ' _' | tr '[:upper:]' '[:lower:]')
        if [[ "$norm_clean_tz" == *"$norm_zone"* ]] || [[ "$norm_last_component" == "$norm_zone" ]]; then
            echo "Using timezone: $clean_tz"
            TZ="$clean_tz" date
            found=1
            break
        fi
    done < <(find "$zoneinfo_dir" -type f)

    # Handle case where timezone wasn't found
    if [ $found -eq 0 ]; then
        echo "Timezone '$zone' not found"
        return 1
    fi
} 

# Tell me if the OS is $1
isOSNamed() {
    [ "`uname -s`" = "$1" ]
}

# Build the entire world for FreeBSD
makeworld() {
	if ! isOSNamed FreeBSD; then
		echo "Only applicable to FreeBSD"
		return
	fi
	cd /usr/src && git pull && sudo make -j8 world kernel DESTDIR=/ 2>&1 | tee make.out
}

# Build and install just the Linux kernel + modules
makelinux() {
	if ! isOSNamed Linux; then
		echo "Only applicable to Linux"
		return
	fi
	_JOBS=8
	if [ "$1" = "-j" ]; then
	     _JOBS=$2
	fi
	# clang kernel build temporarily disabled due to interop problems.
	if which clangXXX > /dev/null 2>&1; then
		cd $HOME/Src/linux && git pull && env CC=clang LLVM=1 make -j${_JOBS} && sudo env CC=clang LLVM=1 make -j${_JOBS} modules_install && sudo env CC=clang LLVM=1 make -j${_JOBS} install
	else
		cd $HOME/Src/linux && git pull && make -j${_JOBS} && sudo make -j${_JOBS} modules_install && sudo make -j${_JOBS} install
	fi
}

# Entirely custom function for saving 3D models
save-model() {
	_DOWN=$HOME/Downloads
	_MODELS=~/Dropbox/STL-Models/_Unclassified
	_NAME="`basename \"$1\" .zip`"
	if [ "${_NAME}" = "$1" ]; then
		echo "$0: Must specify a .zip file from the ${_DOWN} directory"			return
	fi
	mkdir -p "${_MODELS}"
	if [ ! -d "${_MODELS}/" ]; then
		echo "$0: No ${_MODELS} directory."
		return
	fi
	pushd "${_DOWN}"
	cd "${_MODELS}"
	mkdir -p "${_NAME}" && cd "${_NAME}" && unzip "${_DOWN}/${_NAME}.zip" && rm "${_DOWN}/${_NAME}.zip"
}

# KVM related functions
lsvm() {
    virsh list --all
}

managevm() {
    ssh -Y ubumeh4.local virt-manager
}

set-environment-vars() {
    setenv PATH /sbin:/usr/sbin:/bin:/usr/bin:/usr/games:$HOME/Bin
    setenv MANPATH /usr/share/man
    setenv INFOPATH /usr/share/info
    setenv ERL_AFLAGS "-kernel shell_history enabled"
    setenv EDITOR vi
    setenv ELIXIR_EDITOR emacs
    setenv _NVMINIT /opt/local/share/nvm/init-nvm.sh
    setenv HISTCONTROL ignoredups:erasedups
    setenv HOMEBREW_PREFIX "/opt/homebrew"
    setenv HOMEBREW_CELLAR "/opt/homebrew/Cellar"
    setenv HOMEBREW_REPOSITORY "/opt/homebrew"
    
    # All path setting magic goes here.
    [ -z "$GOPATH" ] && export GOPATH="$HOME/gocode"
    [ -f "${_NVMINIT}" ] && source ${_NVMINIT}
    COOLDIRS="$HOME/.local $HOME/anaconda3 /opt/local /snap /opt/X11 /usr/local/cuda /usr/local ${HOMEBREW_PREFIX} $GOPATH $HOME/.cargo"

    if which python > /dev/null; then
	COOLDIRS="`python -m site --user-base` $COOLDIRS"
    fi

    for i in ${COOLDIRS}; do
        [ -d $i/sbin/ ] && PATH=$i/sbin:$PATH
        [ -d $i/bin/ ] && PATH=$i/bin:$PATH
        [ -d $i/lib/ ] && LD_LIBRARY_PATH=$i/lib:$LD_LIBRARY_PATH
        [ -d $i/man/ ] && MANPATH=$i/man:$MANPATH
        [ -d $i/share/man/ ] && MANPATH=$i/share/man:$MANPATH
        [ -d $i/info/ ] && INFOPATH=$i/info:$INFOPATH
    done
    PATH=$PATH:.
    
    if which python > /dev/null; then
        _PYTHON_SITE=`python -m site --user-base`
        [ -d ${_PYTHON_SITE}/bin/ ] && PATH="${_PYTHON_SITE}/bin:$PATH"
    fi

}

set-aliases() {
    alias fetch='curl -C - -O $*'
    alias jsc='/System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Resources/jsc'
    
    # Now do general convenience stuff.
    alias pu=pushd
    alias po=popd
    alias rehash='hash -r'
}

sourceif() {
    _EVAL=0
    [ "$1" = "-e" ] && _EVAL=1 && shift
    _FNAME="$1" && shift
    if [ -f "${_FNAME}" ]; then
	if [ "${_EVAL}" -eq 1 ]; then
		eval "$(${_FNAME} $*)"
	else
		. ${_FNAME} $*
	fi
    fi
}

reachable() {
    [ $# -lt 1 ] && echo "Usage: reachable host|ip" && return 1
    ping -c 1 -i 1 -t 1 "$1" > /dev/null 2>&1 && return 0
    return 2
}

enable-xrdp() {
    sudo apt install xrdp ufw
    sudo systemctl enable --now xrdp
    sudo ufw allow from any to any port 3389 proto tcp
}

# Docker / Kubernetes things

kubeit() {
    if [ $1 = "--remote" ]; then
	_KUBECONFIG="--kubeconfig $HOME/.kube/k8s-prod-hq.config"
	shift
    elif [ $1 = "--local" ]; then
	_KUBECONFIG=""
	shift
    fi
    if [ $1 = "ubuntu" ]; then
	_CMD="run my-shell --attach=true  -i --tty --image ubuntu -- bash"
    elif [ $1 = "token" ]; then
	_CMD="describe secret -n kube-system kubernetes-dashboard"
    elif [ $1 = "dashboard" ]; then
	_CMD="proxy"
	echo "Open http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/#!/node?namespace=default after proxy starts"
    else
	_CMD=$*
    fi
    kubectl ${_KUBECONFIG} ${_CMD}
}

# general purpose things.
mkcd()	{
    mkdir -p $1; cd $1
}

psm()	{
    ps ax | more
}

psg()	{
    ps ax|grep $*
}

lst() {
    ls -lt $* |more
}

vc() {
    [ $# -lt 1 ] && echo "Usage: s hostname" && return
    open vnc://$1.local
}

sm() {
    SSH_CMD=mosh s $*
}

s() {
    [ $# -lt 1 ] && echo "Usage: s hostname [-r] [-ssh-args]" && return
    _HOST=$1; shift
    if [ "$1" = "-r" ]; then
	_USER="root"
	shift
    else
	_USER="jkh"
    fi
    ${SSH_CMD-ssh} $* ${_USER}@${_HOST}.local
}

pipit() {
    pip install  -U --user --use-feature=2020-resolver $*
}

aptgrep ()
{
	if [ $# -gt 0 ]; then
		dpkg --get-selections | awk '{print $1}' | egrep $*;
	else
		dpkg --get-selections | awk '{print $1}';
	fi
}

aptupdate() {
	sudo apt update && sudo apt upgrade $*
	sudo depmod
	sudo apt autoremove
}

aptfixup() {
	sudo apt-get update --fix-missing
	sudo apt-get install -f
	sudo apt autoremove
}

remote-tmux() {
    _host=$1; shift
    ssh ${_host} tmux new-session -d sh "$*"
}

portupdate() {
    if [ -d $HOME/Src/macports-ports/ ]; then
	pushd $HOME/Src/macports-ports/
	git pull && portindex
	popd
	if [ -d $HOME/Src/macports-base/ ]; then
	    pushd $HOME/Src/macports-base
	    git pull && make all && sudo make install
	    popd
	fi
    fi
    sudo port $* selfupdate
    sudo port $* upgrade outdated
    sudo port $* reclaim
}

# Shortcut for git clone that adds the flags I always forget about.
gitcl() {
	git clone --recurse-submodules $*
}

findsym() {
    if echo $1 | grep -q -e - ; then
	grepargs=$1
	shift
    else
	grepargs=""
    fi
    if [ $# -lt 2 ]; then
	DIR=.
    else
	DIR=$1
        shift
    fi
    find "$DIR" -type f -a ! -path '*/.git/*' -print0 | xargs -0 grep -e $grepargs "$1"
}

findfile() {
    matchargs="$1"
    shift

    if [ $# -lt 2 ]; then
        DIR=.
    else
        DIR=$1
        shift
    fi
    find "$DIR" -name "${matchargs}" -a ! -path '*/.git/*' -print
}

open() {
    if [ "$OSTYPE" = "linux-gnu" ]; then
	xdg-open "$*"
    elif echo $OSTYPE | grep -q darwin; then
	/usr/bin/open "$*"
    else
	echo "open not supported on this platform."
    fi
}


copyto() {
    [ $# -lt 1 ] && echo "Usage: copyto [-s] [srcdir] destdir" && return 1
    if [ "$1" = "-s" ]; then
	_SUDO=sudo
	shift
    else
	_SUDO=""
    fi
    if [ $# -lt 2 ]; then
	_S=.
    else
	_S=$1
	shift
    fi
    _T=$1
    tar -cpBf - ${_S} | ${_SUDO} tar -xpBvf - -C ${_T}/
}

# Assorted goofy shit.

title() {
    use-boring-prompt
    echo "]0;$*[31m"
}

use-fancy-prompt() {
    if [ "$TERM" != "cons25" ]; then
	PS1="\[]0;\h:\w[31m\]\u@\h->\[[m\] "
    else
        PS1="\u@\h-> "
    fi
}

use-boring-prompt() {
    PS1="\u@\h-> "
}

cc-rabid() {
    cc 	-W -Wall -ansi -pedantic -Wbad-function-cast -Wcast-align \
	-Wcast-qual -Wchar-subscripts -Wconversion -Winline \
	-Wmissing-prototypes -Wnested-externs -Wpointer-arith \
	-Wredundant-decls -Wshadow -Wstrict-prototypes \
	-Wwrite-strings $*
}

# emit a datestamp
date-stamp() {
    TZ=Etc/UTC date +"%Y-%m-%d %T UTC"
}

find-receipt() {
    for i in /Library/Receipts/*.pkg; do
	[ -f "$i/Contents/Archive.bom" ] && lsbom -f -d -l "$i/Contents/Archive.bom" | grep -q $1 && echo $1 is in $i
    done
}

# If these files exist, source them.
sourceif "${HOME}/.cargo/env"
sourceif "${HOME}/.asdf/asdf.sh"
sourceif -e "${HOME}/opt/anaconda3/bin/conda" shell.bash hook
sourceif -e "${HOME}/anaconda3/bin/conda" shell.bash hook

shopt -s histappend
set-environment-vars
set-aliases

setenv OLLAMA_HOST http://localhost:11434
setenv OLLAMA_API_BASE ${OLLAMA_HOST}

[ "${TERM}" = "dumb" ] || use-fancy-prompt    
