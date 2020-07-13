#!/bin/sh

barf()
{
	echo Usage: "$0 [-r] [-j n]"
	exit 1
}

LLVM_PROJ=$HOME/Src/llvm-project
[ ! -d "${LLVM_PROJ}" -a -d llvm-project ] && LLVM_PROJ=llvm-project

if [ "$1" = "-h" ]; then
	barf
fi

if [ ! -d "${LLVM_PROJ}" ]; then
	cd `dirname ${LLVM_PROJ}`
	echo "Checking out llvm project in `pwd`"
	git clone https://github.com/llvm/llvm-project.git || barf "Can't clone LLVM project"
fi

cd ${LLVM_PROJ} || barf "Can't find llvm-project directory?!"

if [ "$1" = "-j" ]; then
	shift;
	_J=$1
else
	_J=8
fi

if [ "$1" = "-r" ]; then
	echo "Resuming: Not cleaning first."
	shift
else
	rm -rf build
	mkdir build
fi
cd build

cmake -DLLVM_ENABLE_PROJECTS='clang;clang-tools-extra;libcxx;libcxxabi;libunwind;lldb;compiler-rt;lld;polly' ../llvm || barf "Cmake step failed"
make -j${_J} || barf "Unable to build llvm project sources"
sudo make install || barf "Installation failed"
exit 0
