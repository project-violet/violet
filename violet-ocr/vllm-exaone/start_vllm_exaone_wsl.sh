#!/usr/bin/env bash
set -euo pipefail

VENV="${VLLM_VENV:-/root/vllm-venv}"
LOG="${VLLM_LOG:-/tmp/vllm-exaone.log}"
PID="${VLLM_PID:-/tmp/vllm-exaone.pid}"
MODEL="${VLLM_MODEL:-LGAI-EXAONE/EXAONE-3.5-7.8B-Instruct-AWQ}"
SERVED_MODEL="${VLLM_SERVED_MODEL:-exaone3.5:7.8b-awq}"
PORT="${VLLM_PORT:-8001}"

source "$VENV/bin/activate"
export VLLM_USE_FLASHINFER_SAMPLER="${VLLM_USE_FLASHINFER_SAMPLER:-0}"

if [[ "${1:-start}" == "stop" ]]; then
  if [[ -f "$PID" ]]; then
    kill "$(cat "$PID")" 2>/dev/null || true
    rm -f "$PID"
  fi
  echo "stopped"
  exit 0
fi

nohup "$VENV/bin/vllm" serve "$MODEL" \
  --trust-remote-code \
  --host 0.0.0.0 \
  --port "$PORT" \
  --gpu-memory-utilization 0.88 \
  --max-model-len 4096 \
  --served-model-name "$SERVED_MODEL" \
  > "$LOG" 2>&1 < /dev/null &

echo "$!" > "$PID"
echo "started pid=$(cat "$PID") log=$LOG"
