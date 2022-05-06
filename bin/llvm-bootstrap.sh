#!/bin/sh

usage()
{
	[ $# -gt 0 ] && echo $*
	echo Usage: "$0 [-r] [-j n] [-b branch]"
	exit 1
}

_LLVM_PROJ=$HOME/Src/llvm-project
_RESUME=0
_BRANCH=""
_JOBS=4

while getopts hrj:b: flag; do
    case "${flag}" in
	h) usage
	   ;;

	r) _RESUME=1
	   ;;

	j) _JOBS=${OPTARG}
	   ;;

	b) _BRANCH="-b ${OPTARG}"
	   ;;

	*) usage
	   ;;
    esac
done

[ ! -d "${_LLVM_PROJ}" -a -d llvm-project ] && _LLVM_PROJ=llvm-project

if [ ! -d "${_LLVM_PROJ}" ]; then
	cd `dirname ${_LLVM_PROJ}`
	echo "Checking out llvm project in `pwd` ${_BRANCH}"
	git clone ${_BRANCH} https://github.com/llvm/llvm-project.git || usage "Can't clone LLVM project"
	cd llvm-project || usage "Failed to check out llvm sources"
else
	cd `dirname ${_LLVM_PROJ}/llvm-project` || usage "Can't find llvm-project directory"
	git pull
fi

if [ $_RESUME -eq 1 ]; then
	echo "Resuming: Not cleaning first."
else
	rm -rf build
	mkdir build
fi
cd build

if [ -x /usr/local/bin/clang ]; then
        export CC=clang
        export CXX=clang++
fi

cmake -DLLVM_ENABLE_PROJECTS='clang;clang-tools-extra;libcxx;libcxxabi;libunwind;lldb;compiler-rt;lld;polly' ../llvm || usage "Cmake step failed"
make -j${_JOBS} || usage "Unable to build llvm project sources"
sudo make install || usage "Installation failed"
