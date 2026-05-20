#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: run-vllm-coder.sh [model] [vllm-arg ...]

Start a vLLM OpenAI-compatible server for coding models.

Models:
  qwen, qwen3.6, qwen3.6-27b, medium  Qwen/Qwen3.6-27B (default)
  qwen-fp8, fp8                        Qwen/Qwen3.6-27B-FP8
  deepseek-small, small                DeepSeek-R1-Distill-Qwen-7B AWQ
  deepseek-medium                      DeepSeek-R1-Distill-Qwen-14B AWQ
  deepseek-large, large                DeepSeek-R1-Distill-Qwen-32B AWQ
  qwq, large-alt                       Qwen/QwQ-32B-AWQ

Environment:
  VLLM_IMAGE                 Container image (default: docker.io/vllm/vllm-openai:v0.19.0)
  VLLM_MIN_VERSION           Minimum vLLM version for Qwen3.6 (default: 0.19.0)
  VLLM_UPGRADE               auto, force, or 0/false to disable (default: auto)
  VLLM_PREFETCH              Download/resume model before serving (default: 1)
  VLLM_MODEL                 Override the selected Hugging Face model id
  VLLM_HOST_PORT             Host port to publish (default: 8000)
  VLLM_MAX_MODEL_LEN         Context length (single-GPU Qwen default: 245760)
  VLLM_CPU_OFFLOAD_GB        UVA CPU offload per GPU (default: unset)
  VLLM_OFFLOAD_GROUP_SIZE    Prefetch offload group size (single-GPU Qwen default: 2)
  VLLM_OFFLOAD_NUM_IN_GROUP  Layers to offload per group (single-GPU Qwen default: 1)
  VLLM_ENFORCE_EAGER         Disable CUDA graphs (default: 1 only with CPU offload)
  VLLM_LANGUAGE_MODEL_ONLY   Use Qwen text-only mode (default: 1)
  HF_CACHE_DIR               Host Hugging Face cache (default: ~/.cache/huggingface)
  VLLM_CACHE_DIR             Host vLLM cache (default: ~/.cache/vllm)
EOF
}

is_true() {
  case "${1,,}" in
    1|true|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

add_optional_arg() {
  local name="$1"
  local value="$2"

  if [[ -n "$value" ]]; then
    VLLM_ARGS+=("$name" "$value")
  fi
}

add_optional_nonzero_arg() {
  local name="$1"
  local value="$2"

  if [[ -n "$value" && "$value" != "0" ]]; then
    VLLM_ARGS+=("$name" "$value")
  fi
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 0 && "$1" != -* ]]; then
  MODEL_CHOICE="$1"
  shift
else
  MODEL_CHOICE="${MODEL_CHOICE:-qwen3.6-27b}"
fi

EXTRA_VLLM_ARGS=("$@")

if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "nvidia-smi not found; cannot determine GPU count" >&2
  exit 1
fi

GPU_LIST="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || true)"
GPU_COUNT="$(awk 'NF {count++} END {print count+0}' <<<"$GPU_LIST")"
if [[ -z "$GPU_COUNT" || "$GPU_COUNT" -lt 1 ]]; then
  echo "No NVIDIA GPUs found by nvidia-smi" >&2
  exit 1
fi

VLLM_IMAGE="${VLLM_IMAGE:-docker.io/vllm/vllm-openai:v0.19.0}"
VLLM_MIN_VERSION="${VLLM_MIN_VERSION:-0.19.0}"
VLLM_UPGRADE="${VLLM_UPGRADE:-auto}"
VLLM_PREFETCH="${VLLM_PREFETCH:-1}"
HF_CACHE_DIR="${HF_CACHE_DIR:-${HOME}/.cache/huggingface}"
VLLM_CACHE_DIR="${VLLM_CACHE_DIR:-${HOME}/.cache/vllm}"
VLLM_HOST="${VLLM_HOST:-0.0.0.0}"
VLLM_HOST_PORT="${VLLM_HOST_PORT:-8000}"
VLLM_CONTAINER_PORT="${VLLM_CONTAINER_PORT:-8000}"
VLLM_TENSOR_PARALLEL_SIZE="${VLLM_TENSOR_PARALLEL_SIZE:-${GPU_COUNT}}"

MODEL_ID=""
VLLM_QUANTIZATION="${VLLM_QUANTIZATION:-}"
VLLM_DTYPE="${VLLM_DTYPE:-}"
VLLM_GPU_MEMORY_UTILIZATION="${VLLM_GPU_MEMORY_UTILIZATION:-}"
VLLM_MAX_MODEL_LEN="${VLLM_MAX_MODEL_LEN:-}"
VLLM_KV_CACHE_DTYPE="${VLLM_KV_CACHE_DTYPE:-}"
VLLM_MAX_NUM_SEQS="${VLLM_MAX_NUM_SEQS:-}"
VLLM_MAX_NUM_BATCHED_TOKENS="${VLLM_MAX_NUM_BATCHED_TOKENS:-}"
VLLM_CPU_OFFLOAD_GB="${VLLM_CPU_OFFLOAD_GB:-}"
VLLM_OFFLOAD_GROUP_SIZE="${VLLM_OFFLOAD_GROUP_SIZE:-}"
VLLM_OFFLOAD_NUM_IN_GROUP="${VLLM_OFFLOAD_NUM_IN_GROUP:-}"
VLLM_OFFLOAD_PREFETCH_STEP="${VLLM_OFFLOAD_PREFETCH_STEP:-}"
VLLM_ENFORCE_EAGER="${VLLM_ENFORCE_EAGER:-}"
VLLM_REASONING_PARSER="${VLLM_REASONING_PARSER:-}"
VLLM_TOOL_CALL_PARSER="${VLLM_TOOL_CALL_PARSER:-}"
VLLM_ENABLE_TOOL_CALLS="${VLLM_ENABLE_TOOL_CALLS:-}"
VLLM_LANGUAGE_MODEL_ONLY="${VLLM_LANGUAGE_MODEL_ONLY:-}"
VLLM_ENABLE_PREFIX_CACHING="${VLLM_ENABLE_PREFIX_CACHING:-}"
VLLM_SERVED_MODEL_NAME="${VLLM_SERVED_MODEL_NAME:-}"
VLLM_SPECULATIVE_CONFIG="${VLLM_SPECULATIVE_CONFIG:-}"
VLLM_DEFAULT_CHAT_TEMPLATE_KWARGS="${VLLM_DEFAULT_CHAT_TEMPLATE_KWARGS:-}"

case "${MODEL_CHOICE,,}" in
  qwen|qwen3.6|qwen3.6-27b|default|medium)
    MODEL_ID="${VLLM_MODEL:-Qwen/Qwen3.6-27B}"
    VLLM_DTYPE="${VLLM_DTYPE:-bfloat16}"
    VLLM_GPU_MEMORY_UTILIZATION="${VLLM_GPU_MEMORY_UTILIZATION:-0.92}"
    if [[ -z "$VLLM_MAX_MODEL_LEN" ]]; then
      if [[ "$VLLM_TENSOR_PARALLEL_SIZE" -eq 1 ]]; then
        VLLM_MAX_MODEL_LEN="245760"
      else
        VLLM_MAX_MODEL_LEN="262144"
      fi
    fi
    VLLM_KV_CACHE_DTYPE="${VLLM_KV_CACHE_DTYPE:-fp8}"
    if [[ "$VLLM_TENSOR_PARALLEL_SIZE" -eq 1 ]]; then
      VLLM_OFFLOAD_GROUP_SIZE="${VLLM_OFFLOAD_GROUP_SIZE:-2}"
      VLLM_OFFLOAD_NUM_IN_GROUP="${VLLM_OFFLOAD_NUM_IN_GROUP:-1}"
    fi
    if [[ -z "$VLLM_MAX_NUM_SEQS" ]]; then
      if [[ "$VLLM_TENSOR_PARALLEL_SIZE" -eq 1 ]]; then
        VLLM_MAX_NUM_SEQS="1"
      else
        VLLM_MAX_NUM_SEQS="4"
      fi
    fi
    VLLM_MAX_NUM_BATCHED_TOKENS="${VLLM_MAX_NUM_BATCHED_TOKENS:-8192}"
    VLLM_REASONING_PARSER="${VLLM_REASONING_PARSER:-qwen3}"
    VLLM_TOOL_CALL_PARSER="${VLLM_TOOL_CALL_PARSER:-qwen3_coder}"
    VLLM_ENABLE_TOOL_CALLS="${VLLM_ENABLE_TOOL_CALLS:-1}"
    VLLM_LANGUAGE_MODEL_ONLY="${VLLM_LANGUAGE_MODEL_ONLY:-1}"
    VLLM_ENABLE_PREFIX_CACHING="${VLLM_ENABLE_PREFIX_CACHING:-1}"
    if [[ -z "$VLLM_ENFORCE_EAGER" && -n "$VLLM_CPU_OFFLOAD_GB" && "$VLLM_CPU_OFFLOAD_GB" != "0" ]]; then
      VLLM_ENFORCE_EAGER="1"
    fi
    ;;

  qwen-fp8|fp8)
    MODEL_ID="${VLLM_MODEL:-Qwen/Qwen3.6-27B-FP8}"
    VLLM_DTYPE="${VLLM_DTYPE:-bfloat16}"
    VLLM_GPU_MEMORY_UTILIZATION="${VLLM_GPU_MEMORY_UTILIZATION:-0.92}"
    if [[ -z "$VLLM_MAX_MODEL_LEN" ]]; then
      if [[ "$VLLM_TENSOR_PARALLEL_SIZE" -eq 1 ]]; then
        VLLM_MAX_MODEL_LEN="245760"
      else
        VLLM_MAX_MODEL_LEN="262144"
      fi
    fi
    VLLM_KV_CACHE_DTYPE="${VLLM_KV_CACHE_DTYPE:-fp8}"
    VLLM_MAX_NUM_SEQS="${VLLM_MAX_NUM_SEQS:-4}"
    VLLM_MAX_NUM_BATCHED_TOKENS="${VLLM_MAX_NUM_BATCHED_TOKENS:-8192}"
    VLLM_REASONING_PARSER="${VLLM_REASONING_PARSER:-qwen3}"
    VLLM_TOOL_CALL_PARSER="${VLLM_TOOL_CALL_PARSER:-qwen3_coder}"
    VLLM_ENABLE_TOOL_CALLS="${VLLM_ENABLE_TOOL_CALLS:-1}"
    VLLM_LANGUAGE_MODEL_ONLY="${VLLM_LANGUAGE_MODEL_ONLY:-1}"
    VLLM_ENABLE_PREFIX_CACHING="${VLLM_ENABLE_PREFIX_CACHING:-1}"
    ;;

  deepseek-small|small)
    MODEL_ID="${VLLM_MODEL:-casperhansen/deepseek-r1-distill-qwen-7b-awq}"
    VLLM_DTYPE="${VLLM_DTYPE:-float16}"
    VLLM_QUANTIZATION="${VLLM_QUANTIZATION:-awq_marlin}"
    VLLM_GPU_MEMORY_UTILIZATION="${VLLM_GPU_MEMORY_UTILIZATION:-0.90}"
    VLLM_MAX_MODEL_LEN="${VLLM_MAX_MODEL_LEN:-8192}"
    VLLM_KV_CACHE_DTYPE="${VLLM_KV_CACHE_DTYPE:-fp8}"
    VLLM_MAX_NUM_SEQS="${VLLM_MAX_NUM_SEQS:-32}"
    VLLM_MAX_NUM_BATCHED_TOKENS="${VLLM_MAX_NUM_BATCHED_TOKENS:-32768}"
    VLLM_REASONING_PARSER="${VLLM_REASONING_PARSER:-deepseek_r1}"
    ;;

  deepseek-medium)
    MODEL_ID="${VLLM_MODEL:-casperhansen/deepseek-r1-distill-qwen-14b-awq}"
    VLLM_DTYPE="${VLLM_DTYPE:-float16}"
    VLLM_QUANTIZATION="${VLLM_QUANTIZATION:-awq_marlin}"
    VLLM_GPU_MEMORY_UTILIZATION="${VLLM_GPU_MEMORY_UTILIZATION:-0.90}"
    VLLM_MAX_MODEL_LEN="${VLLM_MAX_MODEL_LEN:-8192}"
    VLLM_KV_CACHE_DTYPE="${VLLM_KV_CACHE_DTYPE:-fp8}"
    VLLM_MAX_NUM_SEQS="${VLLM_MAX_NUM_SEQS:-32}"
    VLLM_MAX_NUM_BATCHED_TOKENS="${VLLM_MAX_NUM_BATCHED_TOKENS:-32768}"
    VLLM_REASONING_PARSER="${VLLM_REASONING_PARSER:-deepseek_r1}"
    ;;

  deepseek-large|large)
    MODEL_ID="${VLLM_MODEL:-casperhansen/deepseek-r1-distill-qwen-32b-awq}"
    VLLM_DTYPE="${VLLM_DTYPE:-float16}"
    VLLM_QUANTIZATION="${VLLM_QUANTIZATION:-awq_marlin}"
    VLLM_GPU_MEMORY_UTILIZATION="${VLLM_GPU_MEMORY_UTILIZATION:-0.90}"
    VLLM_MAX_MODEL_LEN="${VLLM_MAX_MODEL_LEN:-8192}"
    VLLM_KV_CACHE_DTYPE="${VLLM_KV_CACHE_DTYPE:-fp8}"
    VLLM_MAX_NUM_SEQS="${VLLM_MAX_NUM_SEQS:-32}"
    VLLM_MAX_NUM_BATCHED_TOKENS="${VLLM_MAX_NUM_BATCHED_TOKENS:-32768}"
    VLLM_REASONING_PARSER="${VLLM_REASONING_PARSER:-deepseek_r1}"
    ;;

  qwq|large-alt)
    MODEL_ID="${VLLM_MODEL:-Qwen/QwQ-32B-AWQ}"
    VLLM_DTYPE="${VLLM_DTYPE:-float16}"
    VLLM_QUANTIZATION="${VLLM_QUANTIZATION:-awq_marlin}"
    VLLM_GPU_MEMORY_UTILIZATION="${VLLM_GPU_MEMORY_UTILIZATION:-0.90}"
    VLLM_MAX_MODEL_LEN="${VLLM_MAX_MODEL_LEN:-8192}"
    VLLM_KV_CACHE_DTYPE="${VLLM_KV_CACHE_DTYPE:-fp8}"
    VLLM_MAX_NUM_SEQS="${VLLM_MAX_NUM_SEQS:-32}"
    VLLM_MAX_NUM_BATCHED_TOKENS="${VLLM_MAX_NUM_BATCHED_TOKENS:-32768}"
    VLLM_REASONING_PARSER="${VLLM_REASONING_PARSER:-deepseek_r1}"
    ;;

  *)
    echo "unknown model '${MODEL_CHOICE}'. Try --help for valid choices." >&2
    exit 1
    ;;
esac

COMMON_DOCKER_ARGS=(
  --rm --gpus all
  --entrypoint bash
  -p "${VLLM_HOST_PORT}:${VLLM_CONTAINER_PORT}"
  --ipc=host
  --ulimit memlock=-1
  --ulimit stack=67108864
  -v "${HF_CACHE_DIR}:/root/.cache/huggingface"
  -v "${VLLM_CACHE_DIR}:/root/.cache/vllm"
  --env "VLLM_MIN_VERSION=${VLLM_MIN_VERSION}"
  --env "VLLM_UPGRADE=${VLLM_UPGRADE}"
  --env "VLLM_PREFETCH=${VLLM_PREFETCH}"
  --env "RUN_VLLM_CODER_MODEL_ID=${MODEL_ID}"
)

mkdir -p "${HF_CACHE_DIR}" "${VLLM_CACHE_DIR}"

if [[ -n "${HF_TOKEN:-}" ]]; then
  COMMON_DOCKER_ARGS+=(--env "HF_TOKEN=${HF_TOKEN}")
fi
if [[ -n "${HUGGING_FACE_HUB_TOKEN:-}" ]]; then
  COMMON_DOCKER_ARGS+=(--env "HUGGING_FACE_HUB_TOKEN=${HUGGING_FACE_HUB_TOKEN}")
fi

VLLM_ARGS=(
  vllm serve "${MODEL_ID}"
  --host "${VLLM_HOST}"
  --port "${VLLM_CONTAINER_PORT}"
  --dtype "${VLLM_DTYPE}"
  --gpu-memory-utilization "${VLLM_GPU_MEMORY_UTILIZATION}"
  --max-model-len "${VLLM_MAX_MODEL_LEN}"
  --kv-cache-dtype "${VLLM_KV_CACHE_DTYPE}"
  --max-num-seqs "${VLLM_MAX_NUM_SEQS}"
  --max-num-batched-tokens "${VLLM_MAX_NUM_BATCHED_TOKENS}"
  --tensor-parallel-size "${VLLM_TENSOR_PARALLEL_SIZE}"
)

add_optional_arg --quantization "${VLLM_QUANTIZATION}"
add_optional_arg --reasoning-parser "${VLLM_REASONING_PARSER}"
add_optional_nonzero_arg --cpu-offload-gb "${VLLM_CPU_OFFLOAD_GB}"
add_optional_nonzero_arg --offload-group-size "${VLLM_OFFLOAD_GROUP_SIZE}"
add_optional_nonzero_arg --offload-num-in-group "${VLLM_OFFLOAD_NUM_IN_GROUP}"
add_optional_nonzero_arg --offload-prefetch-step "${VLLM_OFFLOAD_PREFETCH_STEP}"
add_optional_arg --served-model-name "${VLLM_SERVED_MODEL_NAME}"
add_optional_arg --speculative-config "${VLLM_SPECULATIVE_CONFIG}"
add_optional_arg --default-chat-template-kwargs "${VLLM_DEFAULT_CHAT_TEMPLATE_KWARGS}"

if is_true "${VLLM_ENFORCE_EAGER:-0}"; then
  VLLM_ARGS+=(--enforce-eager)
fi

if is_true "${VLLM_ENABLE_TOOL_CALLS:-0}"; then
  VLLM_ARGS+=(--enable-auto-tool-choice)
  add_optional_arg --tool-call-parser "${VLLM_TOOL_CALL_PARSER}"
fi

if is_true "${VLLM_LANGUAGE_MODEL_ONLY:-0}"; then
  VLLM_ARGS+=(--language-model-only)
fi

if is_true "${VLLM_ENABLE_PREFIX_CACHING:-0}"; then
  VLLM_ARGS+=(--enable-prefix-caching)
fi

VLLM_ARGS+=("${EXTRA_VLLM_ARGS[@]}")

printf "Using model %s\n" "${MODEL_ID}"
printf "Using image %s\n" "${VLLM_IMAGE}"
printf "Tensor parallel size: %s\n" "${VLLM_TENSOR_PARALLEL_SIZE}"

VLLM_BOOTSTRAP='
set -euo pipefail

need_upgrade=0
case "${VLLM_UPGRADE,,}" in
  0|false|no|off)
    ;;
  force)
    need_upgrade=1
    ;;
  auto|1|true|yes|on)
    if ! python3 - "${VLLM_MIN_VERSION}" <<PY
import importlib.metadata
import re
import sys

minimum = sys.argv[1]

def normalize(version):
    parts = re.findall(r"\d+", version.split("+", 1)[0])
    parts = (parts + ["0", "0", "0"])[:3]
    return tuple(int(part) for part in parts)

try:
    current = importlib.metadata.version("vllm")
except importlib.metadata.PackageNotFoundError:
    print("vLLM is not installed in the container")
    sys.exit(1)

print(f"Container vLLM version: {current}")
if normalize(current) < normalize(minimum):
    print(f"vLLM {current} is below required {minimum}")
    sys.exit(1)
PY
    then
      need_upgrade=1
    fi
    ;;
  *)
    echo "Invalid VLLM_UPGRADE=${VLLM_UPGRADE}; expected auto, force, or false" >&2
    exit 2
    ;;
esac

if [[ "$need_upgrade" == "1" ]]; then
  echo "Upgrading vLLM to >=${VLLM_MIN_VERSION} inside the container..."
  if command -v uv >/dev/null 2>&1; then
    uv pip install --system --upgrade "vllm>=${VLLM_MIN_VERSION}" --torch-backend=auto
  else
    python3 -m pip install --upgrade "vllm>=${VLLM_MIN_VERSION}"
  fi
fi

case "${VLLM_PREFETCH,,}" in
  0|false|no|off)
    ;;
  1|true|yes|on)
    echo "Prefetching ${RUN_VLLM_CODER_MODEL_ID} into the Hugging Face cache..."
    export HF_HUB_ENABLE_HF_TRANSFER="${HF_HUB_ENABLE_HF_TRANSFER:-1}"
    if command -v hf >/dev/null 2>&1; then
      hf download "${RUN_VLLM_CODER_MODEL_ID}"
    else
      huggingface-cli download "${RUN_VLLM_CODER_MODEL_ID}"
    fi
    ;;
  *)
    echo "Invalid VLLM_PREFETCH=${VLLM_PREFETCH}; expected true or false" >&2
    exit 2
    ;;
esac

unset VLLM_MIN_VERSION VLLM_UPGRADE VLLM_PREFETCH RUN_VLLM_CODER_MODEL_ID
exec "$@"
'

docker run "${COMMON_DOCKER_ARGS[@]}" "${VLLM_IMAGE}" \
  -lc "${VLLM_BOOTSTRAP}" bash "${VLLM_ARGS[@]}" \
  2>&1 | tee run-vllm-coder.out
