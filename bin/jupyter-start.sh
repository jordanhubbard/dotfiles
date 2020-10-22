#!/bin/sh

if [ "$1" = "-h" ]; then
	echo "$0: [-d] to run containerized or bare metal"
	exit 1
fi

if [ "$1" = "-d" ]; then
	shift
	if [ "$1" = "-r" ]; then
		USER=""
		R="--allow-root"
	else
		USER="-u $(id -u):$(id -g)"
		R=""
	fi

	docker run --gpus all $USER -v /home/jkh/Src/Notebooks:/workspace/Notebooks -it -p 8888:8888 --shm-size=1g --ulimit memlock=-1 --ulimit stack=67108864 jkh-tf2
else
	jupyter notebook --no-browser --ip=0.0.0.0
fi
