#!/usr/bin/env bash
# =============================================================
# benchmark_memory.sh — Benchmark REAL de RAM: NanoRuntime vs llama.cpp
# =============================================================
# Lanza ambos procesos reales, monitorea su RSS con `ps` cada 500ms,
# y genera un reporte JSON + tabla comparativa.
#
# Uso:
#   chmod +x scripts/benchmark_memory.sh
#   ./scripts/benchmark_memory.sh <ruta_modelo.gguf> [context_size]
#
# Ejemplo:
#   ./scripts/benchmark_memory.sh models/deepseek-7b-q4_k_m.gguf 4096
#
# Requisitos:
#   - cargo en el PATH (Rust toolchain)
#   - Modelo GGUF en la ruta especificada
#   - (Opcional) llama-cli compilado y en el PATH para el baseline

set -euo pipefail

# --- Argumentos ---
MODEL_PATH="${1:?ERROR: Debes pasar la ruta al modelo GGUF. Ej: ./benchmark_memory.sh models/qwen.gguf}"
CONTEXT_SIZE="${2:-4096}"
PROMPT="Explain the attention mechanism in transformers in detail."
MAX_TOKENS=150

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPORT_DIR="$REPO_ROOT/benchmark_results/$(date +%Y%m%d_%H%M%S)"
NANO_BIN="$REPO_ROOT/target/release/nanortime"

mkdir -p "$REPORT_DIR"

# =============================================================
# Validaciones
# =============================================================
if [ ! -f "$MODEL_PATH" ]; then
    echo "❌ El modelo '$MODEL_PATH' no existe."
    exit 1
fi

MODEL_SIZE_MB=$(du -m "$MODEL_PATH" | cut -f1)
echo "============================================================"
echo "📊 BENCHMARK DE MEMORIA — NanoRuntime vs llama.cpp"
echo "============================================================"
echo "Modelo       : $MODEL_PATH (${MODEL_SIZE_MB} MB)"
echo "Contexto     : $CONTEXT_SIZE tokens"
echo "Max tokens   : $MAX_TOKENS"
echo "Reporte en   : $REPORT_DIR"
echo "============================================================"
echo ""

# =============================================================
# monitor_rss <PID> <log_csv>
# Escribe "timestamp_s,rss_kb" cada 500ms hasta que el proceso muere.
# =============================================================
monitor_rss() {
    local PID=$1
    local LOG=$2
    echo "timestamp_s,rss_kb" > "$LOG"
    while kill -0 "$PID" 2>/dev/null; do
        local RSS
        RSS=$(ps -p "$PID" -o rss= 2>/dev/null | xargs || true)
        if [[ -n "$RSS" && "$RSS" -gt 0 ]]; then
            echo "$(date +%s),$RSS" >> "$LOG"
        fi
        sleep 0.5
    done
}

# =============================================================
# peak_rss_mb <log_csv>  -> imprime peak en MB con 1 decimal
# =============================================================
peak_rss_mb() {
    local LOG=$1
    local PEAK
    PEAK=$(tail -n +2 "$LOG" | cut -d',' -f2 | sort -nr | head -n1)
    if [[ -z "$PEAK" || "$PEAK" -eq 0 ]]; then
        echo "N/A"
    else
        awk "BEGIN {printf \"%.1f\", $PEAK / 1024}"
    fi
}

# =============================================================
# 1. BASELINE: llama-cli  (--no-mmap = carga completa en RAM)
# =============================================================
LLAMA_PEAK_MB="N/A"
LLAMA_TPS="N/A"
LLAMA_ELAPSED="N/A"
LOG_LLAMA="$REPORT_DIR/llama_rss.csv"

LLAMA_BIN=""
if command -v llama-cli &>/dev/null; then
    LLAMA_BIN="llama-cli"
elif [ -f "$REPO_ROOT/llama-cli" ]; then
    LLAMA_BIN="$REPO_ROOT/llama-cli"
fi

if [ -n "$LLAMA_BIN" ]; then
    echo "🔵 [BASELINE] llama-cli --no-mmap ..."
    TIME_START=$(date +%s%N)

    "$LLAMA_BIN" \
        -m "$MODEL_PATH" \
        -c "$CONTEXT_SIZE" \
        -n "$MAX_TOKENS" \
        -ngl 0 \
        --no-mmap \
        -p "$PROMPT" \
        > "$REPORT_DIR/llama_output.txt" 2>&1 &
    LLAMA_PID=$!

    monitor_rss "$LLAMA_PID" "$LOG_LLAMA"
    wait "$LLAMA_PID" || true

    TIME_END=$(date +%s%N)
    LLAMA_ELAPSED=$(( (TIME_END - TIME_START) / 1000000000 ))
    LLAMA_PEAK_MB=$(peak_rss_mb "$LOG_LLAMA")

    # Intentar extraer TPS del output de llama-cli
    LLAMA_TPS=$(grep -oP '[0-9.]+ tok/s' "$REPORT_DIR/llama_output.txt" | tail -n1 || echo "N/A")
    echo "   Peak RSS : ${LLAMA_PEAK_MB} MB"
    echo "   Tiempo   : ${LLAMA_ELAPSED}s"
    echo "   TPS      : $LLAMA_TPS"
else
    echo "⚠️  llama-cli no encontrado en PATH ni en $REPO_ROOT."
    echo "   Compila llama.cpp y coloca llama-cli en el PATH para obtener el baseline."
    echo "" > "$LOG_LLAMA"
fi

echo ""

# =============================================================
# 2. NANORTIME: compilar en release y ejecutar
# =============================================================
echo "🟢 [NANORTIME] Compilando en release..."
cargo build --release -p nanortime-cli \
    --manifest-path "$REPO_ROOT/Cargo.toml" \
    2>&1 | grep -E "^(error|warning\[|   Compiling|   Finished)" || true

if [ ! -f "$NANO_BIN" ]; then
    echo "❌ Binario no encontrado: $NANO_BIN"
    exit 1
fi
echo "   Binario: $NANO_BIN"

# Manifest temporal: apunta al modelo dado, edge-only, sin cloud
MANIFEST_TMP="$REPORT_DIR/manifest_bench.json"
cat > "$MANIFEST_TMP" <<MANIFEST
{
  "version": "1.0",
  "local_model": {
    "path": "$MODEL_PATH",
    "context_size": $CONTEXT_SIZE,
    "gpu_layers": 0,
    "use_mmap": true,
    "threads": 4,
    "batch_size": 512
  },
  "hybrid_routing": {
    "enabled": false,
    "confidence_threshold": 1.0,
    "privacy_filter": false,
    "edge_only": true
  },
  "tiers": {
    "tier1": { "provider": "local", "enabled": true },
    "tier2": { "provider": "local_server", "endpoint": "http://127.0.0.1:11434", "enabled": false },
    "tier3": { "provider": "anthropic", "model": "claude-sonnet-4-20250514", "api_key_env": "NANO_API_KEY", "enabled": false, "max_tokens": 1024, "temperature": 0.7 }
  },
  "memory": {
    "vector_db_path": "data/vectors.lance",
    "embedding_model": "",
    "auto_index_paths": [],
    "max_context_docs": 0,
    "min_similarity": 0.99
  },
  "tools": { "directory": "tools/", "auto_discover": false },
  "logging": { "level": "warn", "file": "" },
  "generation": {
    "max_tokens": $MAX_TOKENS,
    "temperature": 0.0,
    "top_p": 1.0,
    "repeat_penalty": 1.1,
    "stop_sequences": ["</s>", "<|im_end|>"]
  }
}
MANIFEST

echo "🟢 [NANORTIME] Ejecutando (use_mmap=true, edge_only=true)..."
LOG_NANO="$REPORT_DIR/nanortime_rss.csv"
TIME_START=$(date +%s%N)

"$NANO_BIN" \
    --config "$MANIFEST_TMP" \
    --prompt "$PROMPT" \
    --max-tokens "$MAX_TOKENS" \
    --edge-only \
    --quiet \
    > "$REPORT_DIR/nanortime_output.txt" 2>&1 &
NANO_PID=$!

monitor_rss "$NANO_PID" "$LOG_NANO"
wait "$NANO_PID" || true

TIME_END=$(date +%s%N)
NANO_ELAPSED=$(( (TIME_END - TIME_START) / 1000000000 ))
NANO_PEAK_MB=$(peak_rss_mb "$LOG_NANO")

# Intentar extraer TPS del output
NANO_TPS=$(grep -oP '[0-9.]+ tok/s' "$REPORT_DIR/nanortime_output.txt" | tail -n1 || echo "N/A")
echo "   Peak RSS : ${NANO_PEAK_MB} MB"
echo "   Tiempo   : ${NANO_ELAPSED}s"
echo "   TPS      : $NANO_TPS"

echo ""

# =============================================================
# 3. CÁLCULOS
# =============================================================
RATIO_RAM="N/A"
SAVINGS_PCT="N/A"

if [[ "$NANO_PEAK_MB" != "N/A" && "$NANO_PEAK_MB" != "0.0" ]]; then
    RATIO_RAM=$(awk "BEGIN {printf \"%.2f\", $NANO_PEAK_MB / $MODEL_SIZE_MB}")
fi

if [[ "$LLAMA_PEAK_MB" != "N/A" && "$NANO_PEAK_MB" != "N/A" ]]; then
    SAVINGS_PCT=$(awk "BEGIN {printf \"%.1f\", 100 * ($LLAMA_PEAK_MB - $NANO_PEAK_MB) / $LLAMA_PEAK_MB}")
fi

# =============================================================
# 4. TABLA FINAL
# =============================================================
echo "============================================================"
echo "🏆 RESULTADOS"
echo "============================================================"
printf "%-28s | %-18s | %-18s\n" "Métrica" "llama.cpp (baseline)" "NanoRuntime"
printf "%-28s | %-18s | %-18s\n" "----------------------------" "------------------" "------------------"
printf "%-28s | %-18s | %-18s\n" "Tamaño archivo (MB)"    "${MODEL_SIZE_MB}"      "${MODEL_SIZE_MB}"
printf "%-28s | %-18s | %-18s\n" "Peak RSS (MB)"           "${LLAMA_PEAK_MB}"     "${NANO_PEAK_MB}"
printf "%-28s | %-18s | %-18s\n" "Ratio archivo→RAM"       "N/A"                  "${RATIO_RAM}x"
printf "%-28s | %-18s | %-18s\n" "Ahorro RAM (%)"          "—"                    "${SAVINGS_PCT}%"
printf "%-28s | %-18s | %-18s\n" "Tokens/s"                "${LLAMA_TPS}"         "${NANO_TPS}"
printf "%-28s | %-18s | %-18s\n" "Tiempo total (s)"        "${LLAMA_ELAPSED}"     "${NANO_ELAPSED}"
echo "============================================================"

# =============================================================
# 5. JSON
# =============================================================
cat > "$REPORT_DIR/benchmark_summary.json" <<JSON
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "model": {
    "path": "$MODEL_PATH",
    "size_mb": $MODEL_SIZE_MB
  },
  "config": {
    "context_size": $CONTEXT_SIZE,
    "max_tokens": $MAX_TOKENS
  },
  "llama_cpp_baseline": {
    "peak_rss_mb": "$LLAMA_PEAK_MB",
    "tokens_per_second": "$LLAMA_TPS",
    "elapsed_s": "$LLAMA_ELAPSED"
  },
  "nanortime": {
    "peak_rss_mb": "$NANO_PEAK_MB",
    "tokens_per_second": "$NANO_TPS",
    "elapsed_s": "$NANO_ELAPSED",
    "ratio_file_to_ram": "$RATIO_RAM",
    "ram_savings_pct": "$SAVINGS_PCT"
  }
}
JSON

echo ""
echo "📁 Archivos guardados:"
echo "   $REPORT_DIR/benchmark_summary.json"
echo "   $REPORT_DIR/llama_rss.csv"
echo "   $REPORT_DIR/nanortime_rss.csv"
echo "   $REPORT_DIR/llama_output.txt"
echo "   $REPORT_DIR/nanortime_output.txt"
