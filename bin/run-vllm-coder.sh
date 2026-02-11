#!/bin/sh

if [ $# -lt 1 ]; then
	MODEL_SIZE="medium"
else
	MODEL_SIZE="$*"
fi

echo "Using model size of ${MODEL_SIZE}"

case "${MODEL_SIZE}" in
	# small: 15b - fits on a single DGX Spark or mid-range GPU gaming card.
	small)
	docker run -it --gpus all -p 8000:8000 \
		--ipc=host --ulimit memlock=-1 --ulimit stack=67108864 \
		-v ~/.cache/huggingface:/root/.cache/huggingface \
		nvcr.io/nvidia/vllm:25.12.post1-py3 \
		vllm serve bigcode/starcoder2-15b --trust-remote-code \
		2>&1 | tee run-vllm-coder.out
	;;

	# medium: 32B dense - needs 1x 80GB GPU (A100/H100) or 2x 48GB (A6000, L40S)
	medium)
	docker run -it --gpus all -p 8000:8000 \
		--ipc=host --ulimit memlock=-1 --ulimit stack=67108864 \
		-v ~/.cache/huggingface:/root/.cache/huggingface \
		nvcr.io/nvidia/vllm:25.12.post1-py3 \
		vllm serve Qwen/Qwen2.5-Coder-32B-Instruct \
		--trust-remote-code --tensor-parallel-size $(nvidia-smi -L | wc -l) \
		2>&1 | tee run-vllm-coder.out
	;;

	# large: 480B MoE (35B active) FP8 - needs 8x H100/H200/H20 (80GB+ each)
	large)
	docker run -it --gpus all -p 8000:8000 \
		--ipc=host --ulimit memlock=-1 --ulimit stack=67108864 \
		-v ~/.cache/huggingface:/root/.cache/huggingface \
		nvcr.io/nvidia/vllm:25.12.post1-py3 \
		vllm serve Qwen/Qwen3-Coder-480B-A35B-Instruct-FP8 \
		--trust-remote-code \
		--max-model-len 131072 \
		--enable-expert-parallel \
		--tensor-parallel-size $(nvidia-smi -L | wc -l) \
		2>&1 | tee run-vllm-coder.out
	;;

	*)
	echo "unknown model size ${MODEL_SIZE}"
	exit 1
	;;
esac
