#!/bin/sh

enable-xrdp() {
	sudo apt install xrdp
	sudo systemctl enable --now xrdp
	sudo ufw allow from any to any port 3389 proto tcp
}

OS=`uname -s`

if [ "$OS" == "Linux" ]; then
	echo "source this file to enable various useful shell functions on ubuntu; they may or may not work on other distros."
	return 0
else
	echo "These shell functions are not likely to be useful on anything other than Ubuntu Linux"
	return 1
fi
