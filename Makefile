all:
	@echo "Use the install target to install various useful files to ${HOME}"

install:
	cp .bashrc .bash_profile ${HOME}/
	cp -r .emacs* ${HOME}/
	mkdir -p ${HOME}/Bin
	cp -p bin/* ${HOME/Bin
