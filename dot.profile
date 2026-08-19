# .profile - environment for EVERY shell, including non-interactive ones.
#
# Why this file exists
# --------------------
# `ssh host 'command'` runs a non-interactive shell. dot.bashrc begins with
#
#     [[ $- != *i* ]] && return
#
# so everything it sets -- PATH included -- is invisible to a remote command.
# The observable symptom is a bare PATH:
#
#     $ ssh puck 'echo $PATH'
#     /usr/bin:/bin:/usr/sbin:/sbin
#
# which is why `ssh host 'make install'` failed with "Python 3.11+ is required"
# on a host where python3, uv and git are all installed and on an interactive
# PATH. Every remote automation hits this.
#
# Splitting the two concerns fixes it: ENVIRONMENT (PATH, exports) lives here
# and is read by every shell; INTERACTIVE setup (aliases, prompt, completion,
# functions) stays in .bashrc after its guard.
#
# Read from two places, deliberately:
#   - dot.bash_profile, for login shells (`ssh host 'bash -lc ...'`, terminals).
#     bash reads only the FIRST of ~/.bash_profile, ~/.bash_login, ~/.profile
#     and stops, so a ~/.bash_profile that does not source this file means this
#     file is never read at all.
#   - the top of dot.bashrc, ABOVE the interactive guard. Linux bash sources
#     ~/.bashrc for `ssh host cmd`; macOS bash does not, so on macOS a remote
#     command still needs `bash -lc`.
#
# Keep this file POSIX sh, and keep it SILENT. It is sourced by scp, rsync and
# sftp sessions, and any output to stdout breaks those protocols.

# Sourced from both .bash_profile and .bashrc, and .bashrc is itself sourced
# from .bash_profile -- so without this, PATH gains a duplicate entry on every
# nested shell.
[ -n "${SHELLENV_DONE:-}" ] && return 0
SHELLENV_DONE=1
export SHELLENV_DONE

# Move a directory to the FRONT of PATH, removing any existing occurrence.
#
# Promoting, not merely adding, is the point. An earlier version skipped a
# directory that was already on PATH anywhere -- which left /opt/homebrew/bin
# where macOS put it, at the END, after /usr/bin. `command -v python3` then
# resolved to /usr/bin/python3 (3.9) instead of homebrew's 3.14, and
# `make install` still failed its "Python 3.11+ is required" check on a host
# with 3.14 installed. Present is not the same as precedent.
#
# Pure shell, no subshells: this runs on every login, and a sed per entry is a
# fork per entry. Empty fields are dropped on the way through, which also
# clears the stray leading ":" (an empty entry means the current directory)
# that some inherited PATHs carry.
_prepend_path() {
    [ -d "$1" ] || return 0
    _pp_dir=$1
    _pp_new=$_pp_dir
    _pp_oifs=$IFS
    IFS=:
    for _pp_entry in $PATH; do
        [ -z "$_pp_entry" ] && continue
        [ "$_pp_entry" = "$_pp_dir" ] && continue
        _pp_new="$_pp_new:$_pp_entry"
    done
    IFS=$_pp_oifs
    PATH=$_pp_new
    unset _pp_dir _pp_new _pp_oifs _pp_entry
}

# Deliberately smaller than dot.bashrc's `cooldirs`: this is what UNATTENDED
# tooling needs (uv, cargo, brew, the helpers in ~/Bin). The interactive shell
# adds the rest -- ghcup, cabal, X11, CUDA, MANPATH/INFOPATH -- because a
# remote command has no use for them and every entry costs a stat per lookup.
#
# Note the absence of ".": .bashrc appends the working directory for
# interactive convenience. A non-interactive shell running someone else's
# checkout must not.
_prepend_path "/snap/bin"
_prepend_path "/usr/local/sbin"
_prepend_path "/usr/local/bin"
_prepend_path "${HOMEBREW_PREFIX:-/opt/homebrew}/sbin"
_prepend_path "${HOMEBREW_PREFIX:-/opt/homebrew}/bin"
_prepend_path "${HOME}/.npm-global/bin"
_prepend_path "${HOME}/.opencode/bin"
_prepend_path "${HOME}/.cargo/bin"
_prepend_path "${HOME}/.local/bin"
_prepend_path "${HOME}/bin"
_prepend_path "${HOME}/Bin"

unset -f _prepend_path
export PATH

# Nix, when the daemon profile is installed. Guarded because most fleet nodes
# do not have it.
if [ -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi
