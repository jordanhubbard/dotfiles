#!/bin/sh

if [ $# -lt 1 ]; then
	echo "Usage: $0 hostname"
	exit 1
fi
host=$1

tuples="megamind a8:a1:59:17:7a:54 fluffy f8:ff:c2:46:45:29 nvwaffle 3c:22:fb:e5:21:03"

_found=0
_mac=""
for x in $tuples; do
echo $x
	if [ "$host" == "$x" ]; then
		_found=1
		continue
	fi
	if [ $_found -eq 1 ]; then
		_mac=$x
		break
	fi
done

if [ "$_mac" ]; then
	wakeonlan $_mac
else
	echo "$host not found"
	exit 1
fi
exit 0
