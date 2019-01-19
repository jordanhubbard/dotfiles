all:
	@echo "Use the install target to install .bash* and .emacs* files to $HOME"
	exit 0

install:
	cp .bashrc .bash_profile $HOME/
	cp -r .emacs* $HOME/
