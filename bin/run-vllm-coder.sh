#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="${0##*/}"
DEFAULT_MODEL_CHOICE="qwen3.6-27b"
DEFAULT_VLLM_IMAGE="docker.io/vllm/vllm-openai:v0.19.0"
DEFAULT_VLLM_MIN_VERSION="0.19.0"

MODE="run"
MODEL_CHOICE="${MODEL_CHOICE:-}"
EXTRA_VLLM_ARGS=()
WIZARD_START=0
WIZARD_EXPORTS=()

usage() {
  cat <<EOF
Usage:
  ${SCRIPT_NAME} [model] [vllm-arg ...]
  ${SCRIPT_NAME} --wizard [-- vllm-arg ...]
  ${SCRIPT_NAME} --list-models
  ${SCRIPT_NAME} --help

Start a Dockerized vLLM OpenAI-compatible server for local coding and
reasoning models. The script detects NVIDIA GPUs, chooses sensible defaults for
the selected model preset, and appends any extra arguments to "vllm serve".

Examples:
  ${SCRIPT_NAME}
  ${SCRIPT_NAME} qwen-fp8
  ${SCRIPT_NAME} deepseek-small --swap-space 16
  ${SCRIPT_NAME} --wizard
  VLLM_MAX_MODEL_LEN=32768 VLLM_MAX_NUM_SEQS=1 ${SCRIPT_NAME} qwen

Script options:
  -h, --help       Show this help.
  --list-models    Print the supported model presets with their aliases.
  --wizard, setup  Detect GPUs and interactively suggest a launch command.
  --               Stop parsing script options; remaining args go to vLLM.

$(model_catalog)

Core environment:
  VLLM_IMAGE                 Container image.
                             Default: ${DEFAULT_VLLM_IMAGE}
  VLLM_MIN_VERSION           Minimum vLLM package version inside the container.
                             Default: ${DEFAULT_VLLM_MIN_VERSION}
  VLLM_UPGRADE               auto, force, or 0/false to disable container upgrade.
                             Default: auto
  VLLM_PREFETCH              Download/resume the model before serving.
                             Default: 1
  HF_CACHE_DIR               Host Hugging Face cache mount.
                             Default: ~/.cache/huggingface
  VLLM_CACHE_DIR             Host vLLM cache mount.
                             Default: ~/.cache/vllm
  HF_TOKEN                   Optional Hugging Face token passed to the container.
  HUGGING_FACE_HUB_TOKEN     Optional alternate Hugging Face token.

Network and container environment:
  VLLM_HOST                  Address vLLM binds inside the container.
                             Default: 0.0.0.0
  VLLM_HOST_PORT             Host port published to localhost.
                             Default: 8000
  VLLM_CONTAINER_PORT        Container port vLLM listens on.
                             Default: 8000

Model and serving environment:
  MODEL_CHOICE               Default model preset when no model argument is given.
                             Default: ${DEFAULT_MODEL_CHOICE}
  VLLM_MODEL                 Override the Hugging Face model id for a preset.
  VLLM_SERVED_MODEL_NAME     Optional name advertised by the OpenAI API.
  VLLM_DTYPE                 Override vLLM --dtype.
  VLLM_QUANTIZATION          Override vLLM --quantization.
  VLLM_REASONING_PARSER      Override vLLM --reasoning-parser.
  VLLM_TOOL_CALL_PARSER      Override vLLM --tool-call-parser.
  VLLM_ENABLE_TOOL_CALLS     Enable vLLM automatic tool choice.
  VLLM_LANGUAGE_MODEL_ONLY   Add --language-model-only.

Memory and throughput environment:
  VLLM_TENSOR_PARALLEL_SIZE  Tensor parallel shards. Default: detected GPU count.
  VLLM_GPU_MEMORY_UTILIZATION
                             Fraction of GPU memory vLLM may reserve.
  VLLM_MAX_MODEL_LEN         Context length.
  VLLM_KV_CACHE_DTYPE        KV cache dtype, usually fp8 for these presets.
  VLLM_MAX_NUM_SEQS          Maximum concurrent sequences.
  VLLM_MAX_NUM_BATCHED_TOKENS
                             Token budget per scheduler batch.
  VLLM_CPU_OFFLOAD_GB        CPU offload per GPU. Useful for large models.
  VLLM_OFFLOAD_GROUP_SIZE    vLLM prefetch/offload group size.
  VLLM_OFFLOAD_NUM_IN_GROUP  Number of layers to offload per group.
  VLLM_OFFLOAD_PREFETCH_STEP vLLM prefetch step for offloaded layers.
  VLLM_ENFORCE_EAGER         Add --enforce-eager. Auto-enabled with CPU offload.
  VLLM_ENABLE_PREFIX_CACHING Add --enable-prefix-caching.
  VLLM_SPECULATIVE_CONFIG    JSON or path for vLLM speculative decoding config.
  VLLM_DEFAULT_CHAT_TEMPLATE_KWARGS
                             JSON kwargs passed to the chat template.

The OpenAI-compatible endpoint is published at:
  http://localhost:\${VLLM_HOST_PORT:-8000}/v1
EOF
}

model_catalog() {
  cat <<'EOF'
Model presets:
  qwen3.6-27b
    Aliases: qwen, qwen3.6, default, medium
    Model:   Qwen/Qwen3.6-27B
    Use for: Highest-quality default coding model when VRAM is ample.
    Defaults: bf16 weights, fp8 KV cache, Qwen reasoning/parser support,
              tool calling, prefix caching, 245760-262144 token context.

  qwen-fp8
    Aliases: fp8
    Model:   Qwen/Qwen3.6-27B-FP8
    Use for: Qwen3.6 behavior with lower weight memory pressure.
    Defaults: bf16 runtime dtype, fp8 KV cache, tool calling, prefix caching,
              245760-262144 token context.

  deepseek-small
    Aliases: small
    Model:   casperhansen/deepseek-r1-distill-qwen-7b-awq
    Use for: Smaller GPUs, faster startup, or many concurrent requests.
    Defaults: AWQ Marlin, fp16, fp8 KV cache, 8192 token context.

  deepseek-medium
    Model:   casperhansen/deepseek-r1-distill-qwen-14b-awq
    Use for: Balanced single-GPU local reasoning.
    Defaults: AWQ Marlin, fp16, fp8 KV cache, 8192 token context.

  deepseek-large
    Aliases: large
    Model:   casperhansen/deepseek-r1-distill-qwen-32b-awq
    Use for: Better distilled reasoning on high-memory GPUs.
    Defaults: AWQ Marlin, fp16, fp8 KV cache, 8192 token context.

  qwq
    Aliases: large-alt
    Model:   Qwen/QwQ-32B-AWQ
    Use for: Alternate 32B AWQ reasoning profile.
    Defaults: AWQ Marlin, fp16, fp8 KV cache, 8192 token context.
EOF
}

die() {
  printf "error: %s\n" "$*" >&2
  exit 1
}

warn() {
  printf "warning: %s\n" "$*" >&2
}

is_true() {
  case "${1,,}" in
    1|true|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

set_default() {
  local name="$1"
  local value="$2"

  if [[ -z "${!name:-}" ]]; then
    printf -v "$name" "%s" "$value"
  fi
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

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf "%s" "$value"
}

validate_positive_integer() {
  local name="$1"
  local value="$2"

  if [[ ! "$value" =~ ^[0-9]+$ || "$value" -lt 1 ]]; then
    die "${name} must be a positive integer, got '${value}'"
  fi
}

prompt_default() {
  local prompt="$1"
  local default="$2"
  local answer=""

  if read -r -p "${prompt} [${default}]: " answer; then
    :
  fi

  printf "%s" "${answer:-$default}"
}

prompt_yes_no() {
  local prompt="$1"
  local default="$2"
  local answer=""
  local suffix

  case "${default,,}" in
    y|yes) suffix="Y/n" ;;
    *) suffix="y/N" ;;
  esac

  if read -r -p "${prompt} [${suffix}]: " answer; then
    :
  fi
  answer="${answer:-$default}"

  case "${answer,,}" in
    y|yes) return 0 ;;
    *) return 1 ;;
  esac
}

GPU_NAMES=()
GPU_MEMORY_MIBS=()
GPU_COUNT=0
GPU_MEMORY_MIB_MIN=0
GPU_MEMORY_MIB_TOTAL=0
GPU_MEMORY_GIB_MIN=0
GPU_MEMORY_GIB_TOTAL=0

detect_nvidia_gpus() {
  GPU_NAMES=()
  GPU_MEMORY_MIBS=()
  GPU_COUNT=0
  GPU_MEMORY_MIB_MIN=0
  GPU_MEMORY_MIB_TOTAL=0
  GPU_MEMORY_GIB_MIN=0
  GPU_MEMORY_GIB_TOTAL=0

  if ! command -v nvidia-smi >/dev/null 2>&1; then
    return 1
  fi

  local query_output=""
  query_output="$(nvidia-smi --query-gpu=index,name,memory.total --format=csv,noheader,nounits 2>/dev/null || true)"
  if [[ -z "$query_output" ]]; then
    return 1
  fi

  local gpu_index gpu_name gpu_memory_mib
  while IFS=',' read -r gpu_index gpu_name gpu_memory_mib; do
    gpu_name="$(trim "${gpu_name:-}")"
    gpu_memory_mib="$(trim "${gpu_memory_mib:-}")"

    if [[ -z "$gpu_name" || ! "$gpu_memory_mib" =~ ^[0-9]+$ ]]; then
      continue
    fi

    GPU_NAMES+=("$gpu_name")
    GPU_MEMORY_MIBS+=("$gpu_memory_mib")
    GPU_COUNT=$((GPU_COUNT + 1))
    GPU_MEMORY_MIB_TOTAL=$((GPU_MEMORY_MIB_TOTAL + gpu_memory_mib))
    if [[ "$GPU_MEMORY_MIB_MIN" -eq 0 || "$gpu_memory_mib" -lt "$GPU_MEMORY_MIB_MIN" ]]; then
      GPU_MEMORY_MIB_MIN="$gpu_memory_mib"
    fi
  done <<<"$query_output"

  if [[ "$GPU_COUNT" -lt 1 ]]; then
    return 1
  fi

  GPU_MEMORY_GIB_MIN=$(((GPU_MEMORY_MIB_MIN + 1023) / 1024))
  GPU_MEMORY_GIB_TOTAL=$(((GPU_MEMORY_MIB_TOTAL + 1023) / 1024))
  return 0
}

set_manual_gpu_inventory() {
  local count="$1"
  local memory_gib="$2"
  local name="${3:-Manual NVIDIA GPU}"

  validate_positive_integer "GPU count" "$count"
  validate_positive_integer "GPU memory" "$memory_gib"

  GPU_NAMES=()
  GPU_MEMORY_MIBS=()
  GPU_COUNT="$count"
  GPU_MEMORY_GIB_MIN="$memory_gib"
  GPU_MEMORY_GIB_TOTAL=$((count * memory_gib))
  GPU_MEMORY_MIB_MIN=$((memory_gib * 1024))
  GPU_MEMORY_MIB_TOTAL=$((count * memory_gib * 1024))

  local i
  for ((i = 0; i < count; i++)); do
    GPU_NAMES+=("$name")
    GPU_MEMORY_MIBS+=("$((memory_gib * 1024))")
  done
}

print_gpu_inventory() {
  local i memory_gib

  printf "Detected GPU inventory:\n"
  for i in "${!GPU_NAMES[@]}"; do
    memory_gib=$(((GPU_MEMORY_MIBS[$i] + 1023) / 1024))
    printf "  %d. %s (%d GiB)\n" "$((i + 1))" "${GPU_NAMES[$i]}" "$memory_gib"
  done
  printf "  Total VRAM: %d GiB; smallest GPU: %d GiB\n" \
    "$GPU_MEMORY_GIB_TOTAL" "$GPU_MEMORY_GIB_MIN"
}

initialize_runtime_defaults() {
  VLLM_IMAGE="${VLLM_IMAGE:-${DEFAULT_VLLM_IMAGE}}"
  VLLM_MIN_VERSION="${VLLM_MIN_VERSION:-${DEFAULT_VLLM_MIN_VERSION}}"
  VLLM_UPGRADE="${VLLM_UPGRADE:-auto}"
  VLLM_PREFETCH="${VLLM_PREFETCH:-1}"
  HF_CACHE_DIR="${HF_CACHE_DIR:-${HOME}/.cache/huggingface}"
  VLLM_CACHE_DIR="${VLLM_CACHE_DIR:-${HOME}/.cache/vllm}"
  VLLM_HOST="${VLLM_HOST:-0.0.0.0}"
  VLLM_HOST_PORT="${VLLM_HOST_PORT:-8000}"
  VLLM_CONTAINER_PORT="${VLLM_CONTAINER_PORT:-8000}"
  VLLM_TENSOR_PARALLEL_SIZE="${VLLM_TENSOR_PARALLEL_SIZE:-${GPU_COUNT}}"

  MODEL_ID=""
  MODEL_PROFILE_NAME=""
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

  validate_positive_integer "VLLM_TENSOR_PARALLEL_SIZE" "$VLLM_TENSOR_PARALLEL_SIZE"
  if [[ "$VLLM_TENSOR_PARALLEL_SIZE" -gt "$GPU_COUNT" ]]; then
    die "VLLM_TENSOR_PARALLEL_SIZE=${VLLM_TENSOR_PARALLEL_SIZE} exceeds detected GPU count ${GPU_COUNT}"
  fi
}

configure_qwen36_27b() {
  MODEL_PROFILE_NAME="Qwen3.6 27B"
  MODEL_ID="${VLLM_MODEL:-Qwen/Qwen3.6-27B}"
  set_default VLLM_DTYPE "bfloat16"
  set_default VLLM_GPU_MEMORY_UTILIZATION "0.92"

  if [[ -z "$VLLM_MAX_MODEL_LEN" ]]; then
    if [[ "$VLLM_TENSOR_PARALLEL_SIZE" -eq 1 ]]; then
      VLLM_MAX_MODEL_LEN="245760"
    else
      VLLM_MAX_MODEL_LEN="262144"
    fi
  fi

  set_default VLLM_KV_CACHE_DTYPE "fp8"
  if [[ "$VLLM_TENSOR_PARALLEL_SIZE" -eq 1 ]]; then
    set_default VLLM_OFFLOAD_GROUP_SIZE "2"
    set_default VLLM_OFFLOAD_NUM_IN_GROUP "1"
  fi

  if [[ -z "$VLLM_MAX_NUM_SEQS" ]]; then
    if [[ "$VLLM_TENSOR_PARALLEL_SIZE" -eq 1 ]]; then
      VLLM_MAX_NUM_SEQS="1"
    else
      VLLM_MAX_NUM_SEQS="4"
    fi
  fi

  set_default VLLM_MAX_NUM_BATCHED_TOKENS "8192"
  set_default VLLM_REASONING_PARSER "qwen3"
  set_default VLLM_TOOL_CALL_PARSER "qwen3_coder"
  set_default VLLM_ENABLE_TOOL_CALLS "1"
  set_default VLLM_LANGUAGE_MODEL_ONLY "1"
  set_default VLLM_ENABLE_PREFIX_CACHING "1"

  if [[ -z "$VLLM_ENFORCE_EAGER" && -n "$VLLM_CPU_OFFLOAD_GB" && "$VLLM_CPU_OFFLOAD_GB" != "0" ]]; then
    VLLM_ENFORCE_EAGER="1"
  fi
}

configure_qwen36_27b_fp8() {
  MODEL_PROFILE_NAME="Qwen3.6 27B FP8"
  MODEL_ID="${VLLM_MODEL:-Qwen/Qwen3.6-27B-FP8}"
  set_default VLLM_DTYPE "bfloat16"
  set_default VLLM_GPU_MEMORY_UTILIZATION "0.92"

  if [[ -z "$VLLM_MAX_MODEL_LEN" ]]; then
    if [[ "$VLLM_TENSOR_PARALLEL_SIZE" -eq 1 ]]; then
      VLLM_MAX_MODEL_LEN="245760"
    else
      VLLM_MAX_MODEL_LEN="262144"
    fi
  fi

  set_default VLLM_KV_CACHE_DTYPE "fp8"
  set_default VLLM_MAX_NUM_SEQS "4"
  set_default VLLM_MAX_NUM_BATCHED_TOKENS "8192"
  set_default VLLM_REASONING_PARSER "qwen3"
  set_default VLLM_TOOL_CALL_PARSER "qwen3_coder"
  set_default VLLM_ENABLE_TOOL_CALLS "1"
  set_default VLLM_LANGUAGE_MODEL_ONLY "1"
  set_default VLLM_ENABLE_PREFIX_CACHING "1"
}

configure_awq_reasoner() {
  local profile_name="$1"
  local default_model="$2"

  MODEL_PROFILE_NAME="$profile_name"
  MODEL_ID="${VLLM_MODEL:-${default_model}}"
  set_default VLLM_DTYPE "float16"
  set_default VLLM_QUANTIZATION "awq_marlin"
  set_default VLLM_GPU_MEMORY_UTILIZATION "0.90"
  set_default VLLM_MAX_MODEL_LEN "8192"
  set_default VLLM_KV_CACHE_DTYPE "fp8"
  set_default VLLM_MAX_NUM_SEQS "32"
  set_default VLLM_MAX_NUM_BATCHED_TOKENS "32768"
  set_default VLLM_REASONING_PARSER "deepseek_r1"
}

select_model_profile() {
  case "${MODEL_CHOICE,,}" in
    qwen|qwen3.6|qwen3.6-27b|default|medium)
      configure_qwen36_27b
      ;;
    qwen-fp8|fp8)
      configure_qwen36_27b_fp8
      ;;
    deepseek-small|small)
      configure_awq_reasoner "DeepSeek R1 Distill Qwen 7B AWQ" \
        "casperhansen/deepseek-r1-distill-qwen-7b-awq"
      ;;
    deepseek-medium)
      configure_awq_reasoner "DeepSeek R1 Distill Qwen 14B AWQ" \
        "casperhansen/deepseek-r1-distill-qwen-14b-awq"
      ;;
    deepseek-large|large)
      configure_awq_reasoner "DeepSeek R1 Distill Qwen 32B AWQ" \
        "casperhansen/deepseek-r1-distill-qwen-32b-awq"
      ;;
    qwq|large-alt)
      configure_awq_reasoner "QwQ 32B AWQ" "Qwen/QwQ-32B-AWQ"
      ;;
    *)
      printf "unknown model '%s'\n\n" "$MODEL_CHOICE" >&2
      model_catalog >&2
      exit 1
      ;;
  esac
}

build_common_docker_args() {
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

  if [[ -n "${HF_TOKEN:-}" ]]; then
    COMMON_DOCKER_ARGS+=(--env "HF_TOKEN=${HF_TOKEN}")
  fi
  if [[ -n "${HUGGING_FACE_HUB_TOKEN:-}" ]]; then
    COMMON_DOCKER_ARGS+=(--env "HUGGING_FACE_HUB_TOKEN=${HUGGING_FACE_HUB_TOKEN}")
  fi
}

build_vllm_args() {
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
}

print_launch_summary() {
  printf "Using preset: %s (%s)\n" "$MODEL_CHOICE" "$MODEL_PROFILE_NAME"
  printf "Using model: %s\n" "$MODEL_ID"
  printf "Using image: %s\n" "$VLLM_IMAGE"
  printf "Tensor parallel size: %s of %s detected GPU(s)\n" \
    "$VLLM_TENSOR_PARALLEL_SIZE" "$GPU_COUNT"
  printf "Context length: %s tokens; max sequences: %s\n" \
    "$VLLM_MAX_MODEL_LEN" "$VLLM_MAX_NUM_SEQS"
  printf "Endpoint: http://localhost:%s/v1\n" "$VLLM_HOST_PORT"
}

add_wizard_export() {
  local name="$1"
  local value="$2"
  WIZARD_EXPORTS+=("${name}=${value}")
}

choose_wizard_model() {
  local goal="$1"
  local gpu_count="$2"
  local per_gpu_gib="$3"
  local selected_total_gib=$((gpu_count * per_gpu_gib))

  WIZARD_MODEL_CHOICE="deepseek-small"
  WIZARD_REASON="fallback for constrained GPUs"

  case "$goal" in
    fast)
      if [[ "$per_gpu_gib" -ge 24 ]]; then
        WIZARD_MODEL_CHOICE="deepseek-medium"
        WIZARD_REASON="balanced speed with enough VRAM for the 14B AWQ preset"
      else
        WIZARD_MODEL_CHOICE="deepseek-small"
        WIZARD_REASON="best fit for lower-memory GPUs and fast startup"
      fi
      ;;
    balanced)
      if [[ "$selected_total_gib" -ge 48 && "$per_gpu_gib" -ge 24 ]]; then
        WIZARD_MODEL_CHOICE="qwen-fp8"
        WIZARD_REASON="Qwen3.6 quality with lower weight memory pressure"
      elif [[ "$per_gpu_gib" -ge 24 ]]; then
        WIZARD_MODEL_CHOICE="deepseek-medium"
        WIZARD_REASON="good single-GPU balance for local reasoning"
      else
        WIZARD_MODEL_CHOICE="deepseek-small"
        WIZARD_REASON="conservative option for available VRAM"
      fi
      ;;
    quality)
      if [[ "$selected_total_gib" -ge 80 || "$per_gpu_gib" -ge 64 ]]; then
        WIZARD_MODEL_CHOICE="qwen3.6-27b"
        WIZARD_REASON="highest-quality preset and enough aggregate VRAM"
      elif [[ "$selected_total_gib" -ge 48 && "$per_gpu_gib" -ge 24 ]]; then
        WIZARD_MODEL_CHOICE="qwen-fp8"
        WIZARD_REASON="largest Qwen preset likely to fit this hardware"
      elif [[ "$per_gpu_gib" -ge 40 ]]; then
        WIZARD_MODEL_CHOICE="deepseek-large"
        WIZARD_REASON="32B AWQ reasoning preset for high-memory single GPU"
      elif [[ "$per_gpu_gib" -ge 24 ]]; then
        WIZARD_MODEL_CHOICE="deepseek-medium"
        WIZARD_REASON="14B AWQ is safer than a 27B preset on this VRAM"
      else
        WIZARD_MODEL_CHOICE="deepseek-small"
        WIZARD_REASON="best supported preset for constrained memory"
      fi
      ;;
  esac
}

apply_wizard_context_exports() {
  local context="$1"
  local model_choice="$2"

  case "$context" in
    standard)
      add_wizard_export "VLLM_MAX_MODEL_LEN" "8192"
      ;;
    long)
      case "$model_choice" in
        qwen*|fp8)
          add_wizard_export "VLLM_MAX_MODEL_LEN" "32768"
          ;;
        *)
          add_wizard_export "VLLM_MAX_MODEL_LEN" "16384"
          ;;
      esac
      ;;
    preset)
      ;;
  esac
}

print_wizard_alternatives() {
  local gpu_count="$1"
  local per_gpu_gib="$2"
  local selected_total_gib=$((gpu_count * per_gpu_gib))

  printf "  Viable presets for this hardware tier:\n"
  printf "    deepseek-small  - safest fit and fastest startup\n"
  if [[ "$per_gpu_gib" -ge 24 ]]; then
    printf "    deepseek-medium - stronger AWQ reasoning on a single 24 GiB+ GPU\n"
  fi
  if [[ "$per_gpu_gib" -ge 40 ]]; then
    printf "    deepseek-large  - 32B AWQ reasoning for high-memory GPUs\n"
    printf "    qwq             - alternate 32B AWQ reasoning profile\n"
  fi
  if [[ "$selected_total_gib" -ge 48 && "$per_gpu_gib" -ge 24 ]]; then
    printf "    qwen-fp8        - Qwen3.6 27B with lower weight memory pressure\n"
  fi
  if [[ "$selected_total_gib" -ge 80 || "$per_gpu_gib" -ge 64 ]]; then
    printf "    qwen3.6-27b     - full default Qwen3.6 27B preset\n"
  fi
}

print_wizard_command() {
  local script_path="$SCRIPT_NAME"
  if [[ "$0" == */* ]]; then
    script_path="$0"
  fi

  printf "Recommended command:\n  "
  local assignment
  for assignment in "${WIZARD_EXPORTS[@]}"; do
    printf "%q " "$assignment"
  done
  printf "%q %q" "$script_path" "$WIZARD_MODEL_CHOICE"
  local arg
  for arg in "${EXTRA_VLLM_ARGS[@]}"; do
    printf " %q" "$arg"
  done
  printf "\n"
}

run_setup_wizard() {
  printf "vLLM coder setup wizard\n\n"

  local can_start=0
  if detect_nvidia_gpus; then
    can_start=1
    print_gpu_inventory
  else
    warn "nvidia-smi was not found or did not return NVIDIA GPUs."
    warn "This script can only launch vLLM with Docker's NVIDIA GPU runtime."
    local manual_count manual_memory
    manual_count="$(prompt_default "Number of NVIDIA GPUs to plan for" "1")"
    manual_memory="$(prompt_default "VRAM per GPU in GiB" "24")"
    set_manual_gpu_inventory "$manual_count" "$manual_memory"
  fi

  printf "\n"
  local gpu_default="$GPU_COUNT"
  local gpu_use
  if [[ "$GPU_COUNT" -gt 1 ]]; then
    gpu_use="$(prompt_default "GPUs to use for tensor parallelism (1-${GPU_COUNT})" "$gpu_default")"
    validate_positive_integer "GPU selection" "$gpu_use"
    if [[ "$gpu_use" -gt "$GPU_COUNT" ]]; then
      die "GPU selection ${gpu_use} exceeds detected GPU count ${GPU_COUNT}"
    fi
  else
    gpu_use="1"
  fi

  printf "\nWorkload preference:\n"
  printf "  1. quality  - prefer the strongest model that is likely to fit\n"
  printf "  2. balanced - prefer a practical memory/quality tradeoff\n"
  printf "  3. fast     - prefer faster startup and higher concurrency\n"

  local goal_answer goal
  goal_answer="$(prompt_default "Select workload" "2")"
  case "$goal_answer" in
    1|quality) goal="quality" ;;
    2|balanced) goal="balanced" ;;
    3|fast) goal="fast" ;;
    *) die "unknown workload selection '${goal_answer}'" ;;
  esac

  printf "\nContext preference:\n"
  printf "  1. standard - 8192 tokens, most predictable fit\n"
  printf "  2. long     - longer context with lower concurrency\n"
  printf "  3. preset   - use the selected preset's built-in default\n"

  local context_answer context
  context_answer="$(prompt_default "Select context" "1")"
  case "$context_answer" in
    1|standard) context="standard" ;;
    2|long) context="long" ;;
    3|preset) context="preset" ;;
    *) die "unknown context selection '${context_answer}'" ;;
  esac

  WIZARD_EXPORTS=()
  add_wizard_export "VLLM_TENSOR_PARALLEL_SIZE" "$gpu_use"
  choose_wizard_model "$goal" "$gpu_use" "$GPU_MEMORY_GIB_MIN"
  apply_wizard_context_exports "$context" "$WIZARD_MODEL_CHOICE"

  if [[ "$WIZARD_MODEL_CHOICE" == qwen* && "$gpu_use" -eq 1 && "$GPU_MEMORY_GIB_MIN" -lt 64 ]]; then
    add_wizard_export "VLLM_MAX_NUM_SEQS" "1"
    if [[ "$GPU_MEMORY_GIB_MIN" -ge 40 && "$WIZARD_MODEL_CHOICE" == "qwen3.6-27b" ]]; then
      add_wizard_export "VLLM_CPU_OFFLOAD_GB" "16"
    fi
  fi

  if [[ "$GPU_MEMORY_GIB_MIN" -lt 12 ]]; then
    add_wizard_export "VLLM_GPU_MEMORY_UTILIZATION" "0.85"
    add_wizard_export "VLLM_MAX_NUM_SEQS" "4"
  fi

  printf "\nRecommendation:\n"
  printf "  Preset: %s\n" "$WIZARD_MODEL_CHOICE"
  printf "  Reason: %s\n" "$WIZARD_REASON"
  printf "  GPUs:   %s tensor-parallel shard(s), planned against %s GiB per GPU\n" \
    "$gpu_use" "$GPU_MEMORY_GIB_MIN"
  print_wizard_alternatives "$gpu_use" "$GPU_MEMORY_GIB_MIN"
  if [[ "${#WIZARD_EXPORTS[@]}" -gt 0 ]]; then
    printf "  Environment:\n"
    local assignment
    for assignment in "${WIZARD_EXPORTS[@]}"; do
      printf "    %s\n" "$assignment"
    done
  fi
  printf "\n"
  print_wizard_command
  printf "\n"

  if [[ "$can_start" != "1" ]]; then
    printf "Start skipped because nvidia-smi did not detect runnable NVIDIA GPUs on this host.\n"
    WIZARD_START=0
    return
  fi

  if prompt_yes_no "Start vLLM with this recommendation now" "n"; then
    local assignment
    for assignment in "${WIZARD_EXPORTS[@]}"; do
      export "$assignment"
    done
    MODEL_CHOICE="$WIZARD_MODEL_CHOICE"
    WIZARD_START=1
  else
    WIZARD_START=0
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      --list-models|list-models)
        model_catalog
        exit 0
        ;;
      --wizard|wizard|setup)
        MODE="wizard"
        shift
        ;;
      --)
        shift
        break
        ;;
      -*)
        break
        ;;
      *)
        break
        ;;
    esac
  done

  if [[ "$MODE" == "wizard" ]]; then
    if [[ "${1:-}" == "--" ]]; then
      shift
    fi
    EXTRA_VLLM_ARGS=("$@")
    return
  fi

  if [[ $# -gt 0 && "$1" != -* ]]; then
    MODEL_CHOICE="$1"
    shift
  else
    MODEL_CHOICE="${MODEL_CHOICE:-${DEFAULT_MODEL_CHOICE}}"
  fi

  if [[ "${1:-}" == "--" ]]; then
    shift
  fi
  EXTRA_VLLM_ARGS=("$@")
}

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

main() {
  parse_args "$@"

  if [[ "$MODE" == "wizard" ]]; then
    run_setup_wizard
    if [[ "$WIZARD_START" != "1" ]]; then
      exit 0
    fi
  fi

  if ! detect_nvidia_gpus; then
    die "nvidia-smi not found or no NVIDIA GPUs were detected"
  fi

  if ! command -v docker >/dev/null 2>&1; then
    die "docker was not found; install Docker with NVIDIA GPU support"
  fi

  initialize_runtime_defaults
  select_model_profile
  build_common_docker_args
  build_vllm_args

  mkdir -p "${HF_CACHE_DIR}" "${VLLM_CACHE_DIR}"
  print_launch_summary

  docker run "${COMMON_DOCKER_ARGS[@]}" "${VLLM_IMAGE}" \
    -lc "${VLLM_BOOTSTRAP}" bash "${VLLM_ARGS[@]}" \
    2>&1 | tee run-vllm-coder.out
}

main "$@"
