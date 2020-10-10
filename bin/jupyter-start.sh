#!/bin/sh
docker run --gpus all -v /home/jkh/Src/Notebooks:/workspace/Notebooks -it -p 8888:8888 --shm-size=1g --ulimit memlock=-1 --ulimit stack=67108864 jupyter-tensorflow:jkh ./startup.sh
