#!/bin/sh

barf()
{
	echo Usage: "$0 [-r] [-j n]"
	exit 1
}

LLVM_PROJ=$HOME/Src/llvm-project
[ ! -d "${LLVM_PROJ}" -a -d llvm-project ] && LLVM_PROJ=llvm-project

if [ ! -d "${LLVM_PROJ}" ]; then
	cd `dirname ${LLVM_PROJ}`
	echo "Checking out llvm project in `pwd`"
	git clone https://github.com/llvm/llvm-project.git || barf "Can't clone LLVM project"
	cd llvm-project || barf "Failed to check out llvm sources"
else
	cd `dirname ${LLVM_PROJ}/llvm-project` || barf "Can't find llvm-project directory"
	git pull
fi

_J=8
_RESUME=0
while getopts "j:hr" opt; do
	case $opt in
	h)
		barf;;
	j)
		_J=$OPTARG;;
	r)
		_RESUME=1;;
	esac
done

if [ $_RESUME -eq 1 ]; then
	echo "Resuming: Not cleaning first."
else
	rm -rf build
	mkdir build
fi
cd build

cmake -DLLVM_ENABLE_PROJECTS='clang;clang-tools-extra;libcxx;libcxxabi;libunwind;lldb;compiler-rt;lld;polly' ../llvm || barf "Cmake step failed"
make -j${_J} || barf "Unable to build llvm project sources"
sudo make install || barf "Installation failed"
