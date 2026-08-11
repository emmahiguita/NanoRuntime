#!/bin/bash
# benchmark_speculative.sh — Mide speedup real de speculative decoding
# =====================================================================
# Ejecuta baseline (target puro) y speculative (draft + target) usando
# el binario nanortime. El flag --draft-model activa speculative decoding.
#
# Requisitos:
#   - nanortime compilado con features completos (cargo build --release)
#   - Modelos GGUF en disco
#
# Uso local:   bash scripts/benchmark_speculative.sh
# Uso Android: bash scripts/benchmark_speculative.sh --device R58N21SVSPE
# =====================================================================
set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────
DEVICE=""
NANORTIME="./target/release/nanortime"
DRAFT_MODEL="./models/qwen2.5-1.5b-instruct-q4_k_m.gguf"
TARGET_MODEL="./models/deepseek-7b-q4_k_m.gguf"
MAX_TOKENS=50
TEMPERATURE=0.0
RESULTS_DIR="./data/research"
mkdir -p "$RESULTS_DIR"

# ── Parse args ──────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --device) DEVICE="$2"; shift 2 ;;
        --nanortime) NANORTIME="$2"; shift 2 ;;
        --draft) DRAFT_MODEL="$2"; shift 2 ;;
        --target) TARGET_MODEL="$2"; shift 2 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

PROMPT='<|im_start|>user\nWrite a function that checks if a number is prime in Python.<|im_end|>\n<|im_start|>assistant\n'
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULT_FILE="$RESULTS_DIR/speculative_benchmark_${TIMESTAMP}.json"

if [ -n "$DEVICE" ]; then
    CMD="adb -s $DEVICE shell"
    WORKDIR="/data/local/tmp"
else
    CMD="eval"
    WORKDIR="."
fi

# ── Verify models exist ─────────────────────────────────────────────
if [ -z "$DEVICE" ]; then
    if [ ! -f "$DRAFT_MODEL" ]; then
        echo "Draft model not found: $DRAFT_MODEL"
        echo "Download: wget https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf"
        exit 1
    fi
    if [ ! -f "$TARGET_MODEL" ]; then
        echo "Target model not found: $TARGET_MODEL"
        exit 1
    fi
fi

echo "============================================"
echo "  NANORUNTIME — SPECULATIVE DECODING BENCHMARK"
echo "  Timestamp: $TIMESTAMP"
echo "  Draft:  $(basename "$DRAFT_MODEL")"
echo "  Target: $(basename "$TARGET_MODEL")"
echo "  Max tokens: $MAX_TOKENS"
echo "  Temperature: $TEMPERATURE"
echo "============================================"
echo ""

# ── Fase 1: Baseline — target puro, sin draft ─────────────────────
echo "[1/3] Baseline (target only, no draft)..."
START_TS=$(date +%s.%N)

$CMD "$NANORTIME \
  --model $TARGET_MODEL \
  --max-tokens $MAX_TOKENS \
  --temperature $TEMPERATURE \
  --edge-only \
  --quiet \
  --prompt '$PROMPT'" > /tmp/spec_baseline.txt 2>&1

END_TS=$(date +%s.%N)
BASELINE_SECONDS=$(echo "$END_TS - $START_TS" | bc)
BASELINE_TOKENS=$(grep -oP 'tokens=\K\d+' /tmp/spec_baseline.txt 2>/dev/null | head -1 || echo "0")
BASELINE_TOKSEC=$(grep -oP 'tok_s=\K[\d.]+' /tmp/spec_baseline.txt 2>/dev/null | head -1 || echo "0")

echo "  Baseline: ${BASELINE_SECONDS}s, ${BASELINE_TOKENS} tokens, ${BASELINE_TOKSEC} tok/s"

# ── Fase 2: Speculative decoding con draft=2 ──────────────────────
echo "[2/3] Speculative decoding (draft K=2)..."
START_TS=$(date +%s.%N)

$CMD "$NANORTIME \
  --model $TARGET_MODEL \
  --draft-model $DRAFT_MODEL \
  --draft-tokens 2 \
  --max-tokens $MAX_TOKENS \
  --temperature $TEMPERATURE \
  --edge-only \
  --quiet \
  --prompt '$PROMPT'" > /tmp/spec_draft2.txt 2>&1

END_TS=$(date +%s.%N)
SPEC2_SECONDS=$(echo "$END_TS - $START_TS" | bc)
SPEC2_TOKENS=$(grep -oP 'tokens=\K\d+' /tmp/spec_draft2.txt 2>/dev/null | head -1 || echo "0")
SPEC2_TOKSEC=$(grep -oP 'tok_s=\K[\d.]+' /tmp/spec_draft2.txt 2>/dev/null | head -1 || echo "0")
SPEC2_ACCEPT=$(grep -oP 'accept_rate=\K[\d.]+' /tmp/spec_draft2.txt 2>/dev/null | head -1 || echo "0")

echo "  Speculative K=2: ${SPEC2_SECONDS}s, ${SPEC2_TOKENS} tokens, ${SPEC2_TOKSEC} tok/s, accept=${SPEC2_ACCEPT}"

# ── Fase 3: Speculative decoding con draft=4 ──────────────────────
echo "[3/3] Speculative decoding (draft K=4)..."
START_TS=$(date +%s.%N)

$CMD "$NANORTIME \
  --model $TARGET_MODEL \
  --draft-model $DRAFT_MODEL \
  --draft-tokens 4 \
  --max-tokens $MAX_TOKENS \
  --temperature $TEMPERATURE \
  --edge-only \
  --quiet \
  --prompt '$PROMPT'" > /tmp/spec_draft4.txt 2>&1

END_TS=$(date +%s.%N)
SPEC4_SECONDS=$(echo "$END_TS - $START_TS" | bc)
SPEC4_TOKENS=$(grep -oP 'tokens=\K\d+' /tmp/spec_draft4.txt 2>/dev/null | head -1 || echo "0")
SPEC4_TOKSEC=$(grep -oP 'tok_s=\K[\d.]+' /tmp/spec_draft4.txt 2>/dev/null | head -1 || echo "0")
SPEC4_ACCEPT=$(grep -oP 'accept_rate=\K[\d.]+' /tmp/spec_draft4.txt 2>/dev/null | head -1 || echo "0")

echo "  Speculative K=4: ${SPEC4_SECONDS}s, ${SPEC4_TOKENS} tokens, ${SPEC4_TOKSEC} tok/s, accept=${SPEC4_ACCEPT}"

# ── Compute speedups ───────────────────────────────────────────────
SPEEDUP2="N/A"
SPEEDUP4="N/A"
if [ "$(echo "$BASELINE_SECONDS > 0" | bc -l)" -eq 1 ] && [ "$(echo "$SPEC2_SECONDS > 0" | bc -l)" -eq 1 ]; then
    SPEEDUP2=$(echo "scale=2; $BASELINE_SECONDS / $SPEC2_SECONDS" | bc)
fi
if [ "$(echo "$BASELINE_SECONDS > 0" | bc -l)" -eq 1 ] && [ "$(echo "$SPEC4_SECONDS > 0" | bc -l)" -eq 1 ]; then
    SPEEDUP4=$(echo "scale=2; $BASELINE_SECONDS / $SPEC4_SECONDS" | bc)
fi

# ── OOM detection ──────────────────────────────────────────────────
OOM_COUNT=$(grep -ci "OOM\|killed\|terminated" /tmp/spec_*.txt 2>/dev/null || echo 0)

# ── Results ────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  RESULTS"
echo "============================================"
echo ""
echo "Baseline (sin draft):  ${BASELINE_SECONDS}s | ${BASELINE_TOKSEC} tok/s"
echo "Speculative (draft 2): ${SPEC2_SECONDS}s | ${SPEC2_TOKSEC} tok/s | speedup: ${SPEEDUP2}x | accept: ${SPEC2_ACCEPT}"
echo "Speculative (draft 4): ${SPEC4_SECONDS}s | ${SPEC4_TOKSEC} tok/s | speedup: ${SPEEDUP4}x | accept: ${SPEC4_ACCEPT}"
echo "OOM crashes: $OOM_COUNT"
echo ""

# ── Save JSON results ──────────────────────────────────────────────
cat > "$RESULT_FILE" <<JSONEOF
{
  "timestamp": "$TIMESTAMP",
  "device": "${DEVICE:-local}",
  "draft_model": "$(basename "$DRAFT_MODEL")",
  "target_model": "$(basename "$TARGET_MODEL")",
  "max_tokens": $MAX_TOKENS,
  "temperature": $TEMPERATURE,
  "baseline": {
    "seconds": $BASELINE_SECONDS,
    "tokens": $BASELINE_TOKENS,
    "tok_s": $BASELINE_TOKSEC
  },
  "speculative_k2": {
    "seconds": $SPEC2_SECONDS,
    "tokens": $SPEC2_TOKENS,
    "tok_s": $SPEC2_TOKSEC,
    "accept_rate": $SPEC2_ACCEPT,
    "speedup": "$SPEEDUP2"
  },
  "speculative_k4": {
    "seconds": $SPEC4_SECONDS,
    "tokens": $SPEC4_TOKENS,
    "tok_s": $SPEC4_TOKSEC,
    "accept_rate": $SPEC4_ACCEPT,
    "speedup": "$SPEEDUP4"
  },
  "oom_crashes": $OOM_COUNT
}
JSONEOF

echo "Results saved to: $RESULT_FILE"

# ── Also run Rust unit tests for speculative decoder ─────────────────
echo ""
echo "Running Rust speculative decoder unit tests..."
cargo test --package nanortime-core --lib speculative_decoder::tests -- --nocapture 2>&1 || true

echo ""
echo "Benchmark complete."
