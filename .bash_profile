#!/usr/local/bin/bash

umask 022

# Suck in the .bashrc and all of its various shell functions.
. $HOME/.bashrc

# perform login-shell only intended initialization.
set-environment-vars
