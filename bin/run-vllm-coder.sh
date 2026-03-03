#!/bin/sh

if [ $# -lt 1 ]; then
	MODEL_SIZE="medium"
else
	MODEL_SIZE="$*"
fi

echo "Using model size of ${MODEL_SIZE}"

case "${MODEL_SIZE}" in
# small: 30B MoE (3B active) FP8 - fits on RTX 5090 (32GB) or DGX Spark
small)
	docker run -it --gpus all -p 8000:8000 \
		--ipc=host --ulimit memlock=-1 --ulimit stack=67108864 \
		-v ~/.cache/huggingface:/root/.cache/huggingface \
		nvcr.io/nvidia/vllm:25.12.post1-py3 \
		vllm serve Qwen2.5-Coder-7B-Instruct \
			--dtype auto \
			--quantization awq \
			--max-model-len 8192 \
			--gpu-memory-utilization 0.60 \
			--max-num-seqs 8 \
			--max-num-batched-tokens 8192 \
			--swap-space 1 \
			--tensor-parallel-size $(nvidia-smi -L | wc -l) \
		2>&1 | tee run-vllm-coder.out
	;;

# medium: 123B dense FP8 - needs ~3x 48GB (A6000/L40S) or 2x 80GB (A100/H100)
# for 2x 48GB use mistralai/Devstral-2-123B-Instruct-2512-AWQ (4-bit) instead
medium)
	docker run -it --gpus all -p 8000:8000 \
		--ipc=host --ulimit memlock=-1 --ulimit stack=67108864 \
		-v ~/.cache/huggingface:/root/.cache/huggingface \
		nvcr.io/nvidia/vllm:25.12.post1-py3 \
		vllm serve Qwen2.5-Coder-14B-Instruct \
			--dtype auto \
			--quantization awq \
			--max-model-len 8192 \
			--gpu-memory-utilization 0.60 \
			--max-num-seqs 8 \
			--max-num-batched-tokens 8192 \
			--swap-space 1 \
			--tensor-parallel-size $(nvidia-smi -L | wc -l) \
		2>&1 | tee run-vllm-coder.out
	;;

# large: 230B MoE (10B active) FP8 - needs 4x H100/H200/H20 (80GB+) minimum
large)
	docker run -it --gpus all -p 8000:8000 \
		--ipc=host --ulimit memlock=-1 --ulimit stack=67108864 \
		-v ~/.cache/huggingface:/root/.cache/huggingface \
		nvcr.io/nvidia/vllm:25.12.post1-py3 \
		vllm serve MiniMaxAI/MiniMax-M2.5 \
		--tool-call-parser minimax_m2 \
		--tensor-parallel-size $(nvidia-smi -L | wc -l) \
		2>&1 | tee run-vllm-coder.out
	;;

*)
	echo "unknown model size ${MODEL_SIZE}"
	exit 1
	;;
esac
