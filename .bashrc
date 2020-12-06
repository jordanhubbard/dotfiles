#!/bin/bash
#
# Version: 1.5.3
# This version is the goodest one.
# Changelog:
# 2018/08/14: Made portupdate also accept optional flags (like -v)
# 2018/08/19: Reversed order of PATHs to put optional components ahead of system
# 2018/08/19: Made mkcd properly mkdir -p
# 2018/08/20: Change default .history variables.
# 2018/09/20: Make port selfupdate unconditional to account for rsync'd sources
# 2018/09/20: Add cargo to path, fix MANPATH settings.
# 2018/10/20: Moved to github - See github changelog for information past here

setenv() {
	_SYM=$1; shift; export $_SYM="$*"
}


dockercleanthefuckup() {
	docker image prune
	docker volume prune
	docker container prune
}

set-environment-vars() {
	setenv PATH /sbin:/usr/sbin:/bin:/usr/bin:/usr/games:$HOME/Bin
	setenv MANPATH /usr/share/man
	setenv INFOPATH /usr/share/info
	setenv ERL_AFLAGS "-kernel shell_history enabled"
	setenv EDITOR vi
	setenv ELIXIR_EDITOR emacs
	setenv HISTCONTROL ignoredups:erasedups

	# All path setting magic goes here.
	[ -z "$GOPATH" ] && export GOPATH="$HOME/gocode"
	COOLDIRS="$HOME/.local $HOME/anaconda3 /opt/local /snap /opt/X11 /usr/local/cuda /usr/local $GOPATH $HOME/.cargo"
	
	for i in ${COOLDIRS}; do
        	if [ -d $i/sbin ]; then PATH=$PATH:$i/sbin; fi
        	if [ -d $i/bin ]; then PATH=$PATH:$i/bin; fi
        	if [ -d $i/lib ]; then LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$i/man; fi
        	if [ -d $i/man ]; then MANPATH=$MANPATH:$i/man; fi
        	if [ -d $i/share/man ]; then MANPATH=$MANPATH:$i/share/man; fi
        	if [ -d $i/info ]; then INFOPATH=$INFOPATH:$i/info; fi
	done
	PATH=$PATH:.

	alias fetch='curl -C - -O $*'
	alias jsc='/System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Resources/jsc'

	# Now do general convenience stuff.
	alias pu=pushd
	alias po=popd
	alias rehash='hash -r'
	set history=32
}

reachable() {
	[ $# -lt 1 ] && echo "Usage: reachable host|ip" && return 1
	ping -c 1 -i 1 -t 1 "$1" > /dev/null 2>&1 && return 0
	return 2
}

sprungeit() {
	[ $# -lt 1 ] && echo "Usage: sprungit file | text" && return 1
	if [ -f $1 ]; then
		cat $1 | curl -F 'sprunge=<-' http://sprunge.us
	else
		echo "$*" | curl -F 'sprunge=<-' http://sprunge.us
	fi
}

# Docker / Kubernetes things

kubeit() {
	if [ $1 == "--remote" ]; then
		_KUBECONFIG="--kubeconfig $HOME/.kube/k8s-prod-hq.config"
		shift
	elif [ $1 == "--local" ]; then
		_KUBECONFIG=""
		shift
	fi
	if [ $1 == "ubuntu" ]; then
		_CMD="run my-shell --attach=true  -i --tty --image ubuntu -- bash"
	elif [ $1 == "token" ]; then
		_CMD="describe secret -n kube-system kubernetes-dashboard"
	elif [ $1 == "dashboard" ]; then
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

s() {
	[ $# -lt 1 ] && echo "Usage: s hostname [-r] [-ssh-args]" && return
	_HOST=$1; shift
	if [ "$1" = "-r" ]; then
		_USER="root"
		shift
        else
		_USER="jkh"
	fi
	ssh $* ${_USER}@${_HOST}.local
}

pipit() {
	pip install  -U --user --use-feature=2020-resolver $*
}

aptupdate() {
	sudo apt update && sudo apt upgrade
	sudo depmod
}

remote-tmux() {
	_host=$1; shift
	ssh ${_host} tmux new-session -d sh "$*"
}

portupdate() {
	if [ -d $HOME/Src/macports-ports ]; then
		pushd $HOME/Src/macports-ports
		git pull && portindex
		popd
		if [ -d $HOME/Src/macports-base ]; then
			pushd $HOME/Src/macports-base
			git pull && make all && sudo make install
			popd
		fi
	fi
	sudo port $* selfupdate
	sudo port $* upgrade outdated
	sudo port $* reclaim
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
    find "$DIR" -type f -a ! -path '*/.git/*' -print0 | xargs -0 grep $grepargs "$1"
}

open() {
    if [ $OSTYPE == "linux-gnu" ]; then
	xdg-open "$*"
    elif echo $OSTYPE | grep -q darwin; then
	/usr/bin/open "$*"
    else
	echo "open not supported on this platform."
    fi
}

repeat() {
	[ $# -lt 2 ] && echo "Usage: repeat count command ..." && return 1
	cnt=$1 ;
	shift ;
	i=0 ;
	while [ $i -lt $cnt ]; do
		$* ;
		i=$((i + 1)) ;
	done
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

sync-dotfiles() {
   [ $# -lt 1 ] && echo "Usage: sync-dotfiles hostname" && return 1
   _TGTS="";
   for i in .bashrc .bash_profile .emacs .fvwmrc .mh_profile .signature .xinitrc .xsession .xsession-real .xmodmap .Xdefaults; do
	if [ -f $HOME/$i ]; then
		_TGTS="${_TGTS} $HOME/$i";
	fi
   done
   scp -p ${_TGTS} $1:
}

cc-rabid() {
	cc 	-W -Wall -ansi -pedantic -Wbad-function-cast -Wcast-align \
		-Wcast-qual -Wchar-subscripts -Wconversion -Winline \
		-Wmissing-prototypes -Wnested-externs -Wpointer-arith \
		-Wredundant-decls -Wshadow -Wstrict-prototypes \
		-Wwrite-strings $*
}

md5verify() {
        if [ $# -lt 1 ]; then echo "Usage: md5verify md5-file."; return 1; fi
        if [ ! -f $1 ]; then echo "Error: $1 is not a file."; return 1; fi

        cat $1 | sed -e 's/(/ /' -e 's/)/ /' | awk '{print "if [ " "\"" "`md5 "$2 "`\" != " "\"" $1 " (" $2 ") " $3 " " $4 "\"" " ]; then echo \"" $2 " mismatch\"; fi" }' | sh
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

shopt -s histappend
[ "${TERM}" == "dumb" ] || use-fancy-prompt    
set-environment-vars
