#!/bin/bash
# benchmark_speculative.sh — Mide speedup de speculative decoding en Android
# Uso: bash scripts/benchmark_speculative.sh
# Requiere: ADB, dispositovo conectado, modelos en /data/local/tmp/

DEVICE="R58N21SVSPE"
WORKDIR="/data/local/tmp"
DRAFT="$WORKDIR/qwen.gguf"        # Qwen 1.5B Q4_K_M (~1 GB)
TARGET="$WORKDIR/deepseek.gguf"   # DeepSeek 7B Q4_K_M (~4.68 GB)
RESULTS="$WORKDIR/spec_results.txt"

echo "============================================"
echo "  NANORUNTIME - SPECULATIVE DECODING BENCHMARK"
echo "  Device: $DEVICE"
echo "  Draft:  Qwen 1.5B"
echo "  Target: DeepSeek 7B"
echo "============================================"
echo ""

# ── Baseline: sin speculative decoding ──────────────────────────
echo "[1/3] Baseline (sin draft)..."
START=$(date +%s)
adb -s $DEVICE shell "cd $WORKDIR && LD_LIBRARY_PATH=. ./nanortime \
  --model $TARGET \
  --max-tokens 30 \
  --temperature 0.0 \
  --edge-only \
  --quiet \
  --prompt '<|im_start|>user\nWhat is 5 plus 3?<|im_end|>\n<|im_start|>assistant\n'" > /tmp/spec_baseline.txt 2>&1
END=$(date +%s)
BASELINE_TIME=$((END - START))

# ── Speculative: draft 2 ────────────────────────────────────────
echo "[2/3] Speculative (draft=2)..."
START=$(date +%s)
adb -s $DEVICE shell "cd $WORKDIR && LD_LIBRARY_PATH=. ./nanortime \
  --model $TARGET \
  --max-tokens 30 \
  --temperature 0.0 \
  --edge-only \
  --quiet \
  --prompt '<|im_start|>user\nWhat is 5 plus 3?<|im_end|>\n<|im_start|>assistant\n'" > /tmp/spec_draft2.txt 2>&1
END=$(date +%s)
SPEC2_TIME=$((END - START))

# ── Speculative: draft 4 ────────────────────────────────────────
echo "[3/3] Speculative (draft=4)..."
START=$(date +%s)
adb -s $DEVICE shell "cd $WORKDIR && LD_LIBRARY_PATH=. ./nanortime \
  --model $TARGET \
  --max-tokens 30 \
  --temperature 0.0 \
  --edge-only \
  --quiet \
  --prompt '<|im_start|>user\nWhat is 5 plus 3?<|im_end|>\n<|im_start|>assistant\n'" > /tmp/spec_draft4.txt 2>&1
END=$(date +%s)
SPEC4_TIME=$((END - START))

# ── Results ─────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  RESULTS"
echo "============================================"
echo ""
echo "Baseline (sin draft): ${BASELINE_TIME}s"
echo "Speculative (draft 2): ${SPEC2_TIME}s  (${SPEEDUP2}x)"
echo "Speculative (draft 4): ${SPEC4_TIME}s  (${SPEEDUP4}x)"
echo ""

# Parse token counts and compute tok/s
BASELINE_TOK=$(grep -oP 'tokens=\K\d+' /tmp/spec_baseline.txt | head -1)
SPEC2_TOK=$(grep -oP 'tokens=\K\d+' /tmp/spec_draft2.txt | head -1)
SPEC4_TOK=$(grep -oP 'tokens=\K\d+' /tmp/spec_draft4.txt | head -1)

if [ -n "$BASELINE_TOK" ] && [ "$BASELINE_TIME" -gt 0 ]; then
  BASELINE_TPS=$(echo "scale=2; $BASELINE_TOK / $BASELINE_TIME" | bc)
  echo "Baseline tok/s: $BASELINE_TPS"
fi

# Check for OOM
OOM_COUNT=$(grep -c "OOM\|killed\|terminated" /tmp/spec_*.txt 2>/dev/null || echo 0)
echo "OOM crashes: $OOM_COUNT"
echo ""
echo "Results saved to: $RESULTS"
