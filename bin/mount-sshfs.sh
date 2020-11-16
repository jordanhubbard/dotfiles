#!/bin/sh

# This script only works for the file structure on my mars pro/mars2pro
# 3d printers, but yay.

[ $# -lt 1 ] && echo "Usage: $0 hostname" && exit 1
HOST=$1

mkdir -p /Users/jkh/${HOST}
sshfs -p 22 root@${HOST}.local:/dos/ /Users/jkh/${HOST} -oauto_cache,reconnect,defer_permissions,noappledouble,negative_vncache,volname=${HOST}
