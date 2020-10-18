#!/usr/local/bin/bash

umask 022

# Suck in the .bashrc and all of its various shell functions.
. $HOME/.bashrc
[ -x /opt/local/bin/docker-machine ] && eval $(/opt/local/bin/docker-machine env)
