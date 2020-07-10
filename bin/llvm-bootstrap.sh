#!/bin/sh

barf()
{
	echo "$"
	exit 1
}

if [ ! -d llvm-project ]; then
	echo "Checking out llvm project"
	git clone https://github.com/llvm/llvm-project.git || barf "Can't clone LLVM project"
fi

cd llvm-project || barf "Can't find llvm-project directory?!"

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
