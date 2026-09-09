INSTALL ?= install
INSTALL_HOME ?= $(HOME)
BIN_DIR ?= $(INSTALL_HOME)/Bin

BIN_PROGRAMS := $(filter-out bin/Dockerfile bin/README.md bin/lib,$(wildcard bin/*))
BIN_ASSETS := bin/Dockerfile bin/README.md
BIN_LIBRARIES := $(wildcard bin/lib/*.sh)

.PHONY: all install

all:
	@echo "Use the install target to install various useful files to $(INSTALL_HOME)"

install:
	$(INSTALL) -d "$(INSTALL_HOME)"
	$(INSTALL) -m 0644 dot.bashrc "$(INSTALL_HOME)/.bashrc"
	$(INSTALL) -m 0644 dot.bash_profile "$(INSTALL_HOME)/.bash_profile"
	$(INSTALL) -m 0644 dot.profile "$(INSTALL_HOME)/.profile"
	$(INSTALL) -m 0644 dot.emacs "$(INSTALL_HOME)/.emacs"
	$(INSTALL) -d "$(BIN_DIR)" "$(BIN_DIR)/lib"
	$(INSTALL) -m 0755 $(BIN_PROGRAMS) "$(BIN_DIR)"
	$(INSTALL) -m 0644 $(BIN_ASSETS) "$(BIN_DIR)"
	$(INSTALL) -m 0644 $(BIN_LIBRARIES) "$(BIN_DIR)/lib"
