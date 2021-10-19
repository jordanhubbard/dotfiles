#!/bin/sh

if [ "$1" = "-h" ]; then
	echo "$0: [-d] to run containerized or no args for bare metal"
	exit 1
fi

# Increase the JIT cache size for Ampere because otherwise EXPLODE
export CUDA_CACHE_MAXSIZE=2147483648
export CONTAINER=nvcr.io/nvidia/tensorflow:21.09-tf1-py3
export JUPYTER_CMD="jupyter notebook --no-browser --ip=0.0.0.0"
export DEFHOME=$HOME/Src/Notebooks

# Start the notebook server in my notebooks directory, if possible.
[ -d $DEFHOME ] || DEFHOME=$HOME

# If running containerized, some additional args need to be parsed.
if [ "$1" = "-d" ]; then
	shift
	if [ "$1" = "-r" ]; then
		USER=""
		R="--allow-root"
	else
		USER="-u $(id -u):$(id -g)"
		R=""
	fi

	docker run --gpus all $USER -v $DEFHOME:/workspace/Notebooks -it -p 8888:8888 --shm-size=1g --ulimit memlock=-1 --ulimit stack=67108864 ${CONTAINER} ${JUPYTER_CMD}
else
	# Simple bare-metal case here - just run the jupyter command
	cd $DEFHOME
	${JUPYTER_CMD}
fi
