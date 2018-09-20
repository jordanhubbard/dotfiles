#!/bin/bash
#
# Version: 1.5.2
# This version is the goodest one.
# Changelog:
# 2018/08/14: Made portupdate also accept optional flags (like -v)
# 2018/08/19: Reversed order of PATHs to put optional components ahead of system
# 2018/08/19: Made mkcd properly mkdir -p
# 2018/08/20: Change default .history variables.
# 2018/09/20: Make port selfupdate unconditional to account for rsync'd sources
# 2018/09/20: Add cargo to path, fix MANPATH settings.

setenv() {
	_SYM=$1; shift; export $_SYM="$*"
}

set-environment-vars() {
	setenv XKEYSYMDB /usr/X11/lib/X11/XKeysymDB
	setenv XNLSPATH /usr/X11/lib/X11/nls
	setenv XAPPLRESDIR /usr/X11/lib/X11/app-defaults
	setenv BLOCKSIZE 1024
	setenv RSYNC_RSH ssh
	setenv PATH /sbin:/usr/sbin:/bin:/usr/bin:$HOME/Bin
	setenv MANPATH /usr/share/man
	setenv INFOPATH /usr/share/info
	export ERL_AFLAGS="-kernel shell_history enabled"
	export HISTCONTROL=ignoredups:erasedups

	COOLDIRS="/usr/local /opt/X11 /opt/local $HOME/.cargo"

	for i in ${COOLDIRS}; do
        	if [ -d $i/sbin ]; then PATH=$i/sbin:$PATH; fi
        	if [ -d $i/bin ]; then PATH=$i/bin:$PATH; fi
        	if [ -d $i/man ]; then MANPATH=$i/man:$MANPATH; fi
        	if [ -d $i/share/man ]; then MANPATH=$i/share/man:$MANPATH; fi
        	if [ -d $i/info ]; then INFOPATH=:$i/info:$INFOPATH; fi
	done

	PATH=$PATH:.

	alias fetch='curl -C - -O $*'
	alias jsc='/System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Resources/jsc'
	setenv SVN_EDITOR vi

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

aptupdate() {
	sudo apt update && sudo apt upgrade
	sudo depmod
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

# Diff two plists                                                               
diffplist() {
	[ $# -lt 2 ] && echo "Usage: diffplist plist1 plist2" && return 1
	diff -u --label "$1" <(plutil -convert xml1 -o - "$1") --label "$2" <(plutil -convert xml1 -o - "$2")
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

repeat()	{
	[ $# -lt 2 ] && echo "Usage: repeat count command ..." && return 1
	cnt=$1 ;
	shift ;
	i=0 ;
	while [ $i -lt $cnt ]; do
		$* ;
		i=$((i + 1)) ;
	done
}

# Assorted goofy shit.

title() {
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
use-fancy-prompt    
