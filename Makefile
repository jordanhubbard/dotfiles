all:
	@echo "Use the install target to install various useful files to ${HOME}"

install:
	cp dot.bashrc ${HOME}/.bashrc
	cp dot.bash_profile ${HOME}/.bash_profile
	cp dot.emacs ${HOME}/.emacs
	mkdir -p ${HOME}/Bin
	cp -p bin/* ${HOME}/Bin
