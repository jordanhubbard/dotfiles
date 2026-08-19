umask 022

# bash reads only the FIRST of ~/.bash_profile, ~/.bash_login and ~/.profile,
# then stops. Because this file exists, ~/.profile was never read -- so the
# PATH entries it sets (~/.local/bin for uv, ~/.cargo/bin, homebrew) were
# missing from every login shell. Source it explicitly.
#
# Environment first, so .bashrc below can rely on the tools being findable.
[ -r "$HOME/.profile" ] && . "$HOME/.profile"

# Suck in the .bashrc and all of its various shell functions.
[ -r "$HOME/.bashrc" ] && . "$HOME/.bashrc"
