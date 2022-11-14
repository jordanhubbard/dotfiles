#!/bin/sh

# Change existing symlinks to point to a new location

DRY_RUN=n
if [ $# -lt 3 -o "$1" == "-h" ]; then
	echo "Usage: $0 from-str to-str file [ .. file]"
	echo
	echo "Example: $0 /usr/local /opt/local /mnt/app-links/*"
	exit 0
fi

if [ "$1" = "-d" ]; then
	DRY_RUN=y
	shift
fi

from="$1"
to="$2"
shift 2

for file in $*; do
	if [ -L "${file}" ]; then
		if lval=$(readlink "${file}"); then
			target=$(echo "${lval}" | sed "s@${from}@${to}@")
			if [ "${DRY_RUN}" = "y" ]; then
				echo "${file} -> ${target}"
			else
				rm -f "${file}"
				ln -s "${target}" "${file}"
			fi
		fi
	fi
done
