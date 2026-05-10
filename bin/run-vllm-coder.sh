#!/bin/sh
set -eu

MODEL_SIZE="${1:-medium}"
echo "Using model size of ${MODEL_SIZE}"

GPU_COUNT="$(nvidia-smi -L | wc -l | tr -d ' ')"

COMMON_DOCKER_ARGS="
  --rm -it --gpus all -p 8000:8000
  --ipc=host --ulimit memlock=-1 --ulimit stack=67108864
  -v $HOME/.cache/huggingface:/root/.cache/huggingface
"

# Memory-safety defaults for unified-memory boxes
COMMON_VLLM_ARGS="
  --dtype float16
  --gpu-memory-utilization 0.60
  --max-model-len 8192
  --kv-cache-dtype fp8
  --max-num-seqs 8
  --max-num-batched-tokens 8192
  --swap-space 0
  --tensor-parallel-size ${GPU_COUNT}
  --reasoning-parser deepseek_r1
"

case "${MODEL_SIZE}" in
small)
  docker run ${COMMON_DOCKER_ARGS} nvcr.io/nvidia/vllm:25.12.post1-py3 \
    vllm serve casperhansen/deepseek-r1-distill-qwen-7b-awq \
      --quantization awq \
      ${COMMON_VLLM_ARGS} \
    2>&1 | tee run-vllm-coder.out
  ;;

medium)
  docker run ${COMMON_DOCKER_ARGS} nvcr.io/nvidia/vllm:25.12.post1-py3 \
    vllm serve casperhansen/deepseek-r1-distill-qwen-14b-awq \
      --quantization awq \
      ${COMMON_VLLM_ARGS} \
    2>&1 | tee run-vllm-coder.out
  ;;

large)
  docker run ${COMMON_DOCKER_ARGS} nvcr.io/nvidia/vllm:25.12.post1-py3 \
    vllm serve casperhansen/deepseek-r1-distill-qwen-32b-awq \
      --quantization awq \
      ${COMMON_VLLM_ARGS} \
    2>&1 | tee run-vllm-coder.out
  ;;

qwq|large-alt)
  docker run ${COMMON_DOCKER_ARGS} nvcr.io/nvidia/vllm:25.12.post1-py3 \
    vllm serve Qwen/QwQ-32B-AWQ \
      --quantization awq \
      ${COMMON_VLLM_ARGS} \
    2>&1 | tee run-vllm-coder.out
  ;;

*)
  echo "unknown model size ${MODEL_SIZE}; expected small, medium, large, or qwq" >&2
  exit 1
  ;;
esac
