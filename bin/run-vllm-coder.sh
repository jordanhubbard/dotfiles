#!/bin/sh
set -eu

MODEL_SIZE="${1:-medium}"
echo "Using model size of ${MODEL_SIZE}"

GPU_COUNT="$(nvidia-smi -L | wc -l | tr -d ' ')"
VLLM_IMAGE="${VLLM_IMAGE:-nvcr.io/nvidia/vllm:25.12.post1-py3}"
VLLM_HOST_PORT="${VLLM_HOST_PORT:-8000}"
VLLM_TENSOR_PARALLEL_SIZE="${VLLM_TENSOR_PARALLEL_SIZE:-${GPU_COUNT}}"
VLLM_DTYPE="${VLLM_DTYPE:-float16}"
VLLM_QUANTIZATION="${VLLM_QUANTIZATION:-awq_marlin}"
VLLM_GPU_MEMORY_UTILIZATION="${VLLM_GPU_MEMORY_UTILIZATION:-0.90}"
VLLM_MAX_MODEL_LEN="${VLLM_MAX_MODEL_LEN:-8192}"
VLLM_KV_CACHE_DTYPE="${VLLM_KV_CACHE_DTYPE:-fp8}"
VLLM_MAX_NUM_SEQS="${VLLM_MAX_NUM_SEQS:-32}"
VLLM_MAX_NUM_BATCHED_TOKENS="${VLLM_MAX_NUM_BATCHED_TOKENS:-32768}"
VLLM_SWAP_SPACE="${VLLM_SWAP_SPACE:-0}"

COMMON_DOCKER_ARGS="
  --rm -it --gpus all -p ${VLLM_HOST_PORT}:8000
  --ipc=host --ulimit memlock=-1 --ulimit stack=67108864
  -v $HOME/.cache/huggingface:/root/.cache/huggingface
"

# Performance-oriented defaults for AWQ coding models.
COMMON_VLLM_ARGS="
  --dtype ${VLLM_DTYPE}
  --gpu-memory-utilization ${VLLM_GPU_MEMORY_UTILIZATION}
  --max-model-len ${VLLM_MAX_MODEL_LEN}
  --kv-cache-dtype ${VLLM_KV_CACHE_DTYPE}
  --max-num-seqs ${VLLM_MAX_NUM_SEQS}
  --max-num-batched-tokens ${VLLM_MAX_NUM_BATCHED_TOKENS}
  --swap-space ${VLLM_SWAP_SPACE}
  --tensor-parallel-size ${VLLM_TENSOR_PARALLEL_SIZE}
  --reasoning-parser deepseek_r1
"

run_model() {
  docker run ${COMMON_DOCKER_ARGS} "${VLLM_IMAGE}" \
    vllm serve "$1" \
      --quantization "${VLLM_QUANTIZATION}" \
      ${COMMON_VLLM_ARGS} \
    2>&1 | tee run-vllm-coder.out
}

case "${MODEL_SIZE}" in
small)
  run_model casperhansen/deepseek-r1-distill-qwen-7b-awq
  ;;

medium)
  run_model casperhansen/deepseek-r1-distill-qwen-14b-awq
  ;;

large)
  run_model casperhansen/deepseek-r1-distill-qwen-32b-awq
  ;;

qwq|large-alt)
  run_model Qwen/QwQ-32B-AWQ
  ;;

*)
  echo "unknown model size ${MODEL_SIZE}; expected small, medium, large, or qwq" >&2
  exit 1
  ;;
esac
