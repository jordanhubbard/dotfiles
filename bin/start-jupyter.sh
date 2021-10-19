#!/bin/sh

if [ "$1" = "-h" ]; then
	echo "$0: [-d] to run containerized or bare metal"
	exit 1
fi

# Increase the JIT cache size for Ampere
export CUDA_CACHE_MAXSIZE=2147483648
export CONTAINER=nvcr.io/nvidia/tensorflow:21.09-tf1-py3

# Where we'd like to start the notebook server if possible.
DEFHOME=$HOME/Src/Notebooks
[ -d $DEFHOME ] || DEFHOME=$HOME

if [ "$1" = "-d" ]; then
	shift
	if [ "$1" = "-r" ]; then
		USER=""
		R="--allow-root"
	else
		USER="-u $(id -u):$(id -g)"
		R=""
	fi

	docker run --gpus all $USER -v $DEFHOME:/workspace/Notebooks -it -p 8888:8888 --shm-size=1g --ulimit memlock=-1 --ulimit stack=67108864 ${CONTAINER} jupyter notebook --no-browser --ip=0.0.0.0
else
	cd $DEFHOME
	jupyter notebook --no-browser --ip=0.0.0.0
fi
