#!/bin/sh

if [ $# -lt 1 ]; then
	MODEL_SIZE="medium"
else
	MODEL_SIZE="$*"
fi

echo "Using model size of ${MODEL_SIZE}"

case "${MODEL_SIZE}" in
	small)
	docker run -it --gpus all -p 8000:8000   --ipc=host --ulimit memlock=-1 --ulimit stack=67108864   -v ~/.cache/huggingface:/root/.cache/huggingface   nvcr.io/nvidia/vllm:25.12.post1-py3   vllm serve nvidia/NVIDIA-Nemotron-3-Nano-30B-A3B-FP8     --trust-remote-code 2>&1 | tee run-vllm-coder.out
	;;

	medium)
	docker run -it --gpus all -p 8000:8000 \
    --ipc=host --ulimit memlock=-1 --ulimit stack=67108864 \
    -v ~/.cache/huggingface:/root/.cache/huggingface \
    nvcr.io/nvidia/vllm:25.12.post1-py3 \
    vllm serve Qwen/Qwen2.5-Coder-32B-Instruct \
      --trust-remote-code \
      --tensor-parallel-size $(nvidia-smi -L | wc -l) \
    2>&1 | tee run-vllm-coder.out
	;;

	large)
	echo "large not supported yet"
	exit 1
	;;

	*)
	echo "unknown model size ${MODEL_SIZE}"
	exit 1
	;;
esac

