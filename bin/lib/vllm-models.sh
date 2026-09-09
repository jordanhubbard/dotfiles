#!/usr/bin/env bash
#
# vllm-models.sh - model catalog and profile defaults for run-vllm-coder.sh
# Profile functions intentionally assign globals consumed by the caller.
# shellcheck disable=SC2034

model_catalog() {
  cat <<'EOF'
Model presets:
  nemotron-lightning
    Aliases: nemotron, lightning, medium, default
    Model:   nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-BF16
    Use for: Default mid-capability tier. MoE (30B total / 3B active params),
              BF16 weights broadly compatible with small GPUs since no
              quantization kernel is required; excellent free NVIDIA model.
    Defaults: bf16 runtime dtype, fp8 KV cache, tool calling, prefix caching,
              65536-131072 token context.

  qwen3.8-27b
    Aliases: qwen, qwen3.8, qwen3.6, qwen3.6-27b, high
    Model:   Qwen/Qwen3.8-27B
    Use for: High-capability tier. Strongest coding model in this catalog.
              bf16-only for now; no Qwen3.8 FP8 repo is known yet (use
              qwen-fp8 below if you specifically need the older FP8 weights).
    Defaults: bf16 weights, fp8 KV cache, Qwen reasoning/parser support,
              tool calling, prefix caching, 65536-262144 token context.

  qwen-bf16
    Aliases: bf16
    Model:   Qwen/Qwen3.8-27B
    Use for: Full bf16 Qwen3.8 weights when VRAM is ample or CPU offload is acceptable.
    Defaults: bf16 weights, fp8 KV cache, single-sequence CPU offload fallback,
              tool calling, prefix caching, 65536-262144 token context.

  qwen-fp8
    Aliases: fp8
    Model:   Qwen/Qwen3.6-27B-FP8
    Use for: Qwen3.6 FP8 weights (lower memory pressure). Pinned to 3.6 since
              no Qwen3.8-27B-FP8 repo is confirmed to exist yet.
    Defaults: bf16 runtime dtype, fp8 KV cache, tool calling, prefix caching,
              65536-262144 token context.

  deepseek-small
    Aliases: small, low
    Model:   casperhansen/deepseek-r1-distill-qwen-7b-awq
    Use for: Low-capability tier. Smaller GPUs, faster startup, or many
              concurrent requests.
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

set_default() {
  local name="$1"
  local value="$2"

  if [[ -z "${!name:-}" ]]; then
    printf -v "$name" "%s" "$value"
  fi
}

enable_eager_for_cpu_offload() {
  if [[ -z "$VLLM_ENFORCE_EAGER" && -n "$VLLM_CPU_OFFLOAD_GB" && "$VLLM_CPU_OFFLOAD_GB" != "0" ]]; then
    VLLM_ENFORCE_EAGER="1"
  fi
}

configure_qwen_defaults() {
  local profile_name="$1"
  local default_model="$2"
  local max_num_seqs="$3"

  MODEL_PROFILE_NAME="$profile_name"
  MODEL_ID="${VLLM_MODEL:-${default_model}}"
  set_default VLLM_DTYPE "bfloat16"
  set_default VLLM_GPU_MEMORY_UTILIZATION "0.92"

  if [[ -z "$VLLM_MAX_MODEL_LEN" ]]; then
    if [[ "$VLLM_TENSOR_PARALLEL_SIZE" -eq 1 ]]; then
      VLLM_MAX_MODEL_LEN="65536"
    else
      VLLM_MAX_MODEL_LEN="262144"
    fi
  fi

  set_default VLLM_KV_CACHE_DTYPE "fp8"
  set_default VLLM_MAX_NUM_SEQS "$max_num_seqs"
  set_default VLLM_MAX_NUM_BATCHED_TOKENS "8192"
  set_default VLLM_REASONING_PARSER "qwen3"
  set_default VLLM_TOOL_CALL_PARSER "qwen3_coder"
  set_default VLLM_ENABLE_TOOL_CALLS "1"
  set_default VLLM_LANGUAGE_MODEL_ONLY "1"
  set_default VLLM_ENABLE_PREFIX_CACHING "1"
  # Agentic clients may ignore an unfinished thinking block and see empty
  # content, so thinking remains opt-in through the environment override.
  set_default VLLM_DEFAULT_CHAT_TEMPLATE_KWARGS '{"enable_thinking": false}'
}

configure_qwen38_27b() {
  configure_qwen_defaults "Qwen3.8 27B bf16" "Qwen/Qwen3.8-27B" "4"
  enable_eager_for_cpu_offload
}

configure_qwen38_27b_bf16() {
  configure_qwen_defaults \
    "Qwen3.8 27B bf16 (CPU offload fallback)" "Qwen/Qwen3.8-27B" "1"

  if [[ "$VLLM_TENSOR_PARALLEL_SIZE" -eq 1 ]]; then
    set_default VLLM_OFFLOAD_GROUP_SIZE "2"
    set_default VLLM_OFFLOAD_NUM_IN_GROUP "1"
  fi
  enable_eager_for_cpu_offload
}

configure_qwen36_27b_fp8() {
  configure_qwen_defaults \
    "Qwen3.6 27B FP8 (no Qwen3.8 FP8 repo known yet)" \
    "Qwen/Qwen3.6-27B-FP8" "4"
}

configure_nemotron_lightning() {
  MODEL_PROFILE_NAME="NVIDIA Nemotron 3.5 Lightning 30B-A3B BF16"
  MODEL_ID="${VLLM_MODEL:-nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-BF16}"
  set_default VLLM_DTYPE "bfloat16"
  set_default VLLM_GPU_MEMORY_UTILIZATION "0.90"

  if [[ -z "$VLLM_MAX_MODEL_LEN" ]]; then
    if [[ "$VLLM_TENSOR_PARALLEL_SIZE" -eq 1 ]]; then
      VLLM_MAX_MODEL_LEN="65536"
    else
      VLLM_MAX_MODEL_LEN="131072"
    fi
  fi

  set_default VLLM_KV_CACHE_DTYPE "fp8"
  set_default VLLM_MAX_NUM_SEQS "4"
  set_default VLLM_MAX_NUM_BATCHED_TOKENS "8192"
  set_default VLLM_ENABLE_TOOL_CALLS "1"
  set_default VLLM_LANGUAGE_MODEL_ONLY "1"
  set_default VLLM_ENABLE_PREFIX_CACHING "1"
  enable_eager_for_cpu_offload
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
    nemotron-lightning|nemotron|lightning|default|medium)
      configure_nemotron_lightning
      ;;
    qwen|qwen3.8|qwen3.6|qwen3.8-27b|qwen3.6-27b|high)
      configure_qwen38_27b
      ;;
    qwen-bf16|bf16)
      configure_qwen38_27b_bf16
      ;;
    qwen-fp8|fp8)
      configure_qwen36_27b_fp8
      ;;
    deepseek-small|small|low)
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
