#!/usr/bin/env bash
# NanoAI Benchmark Pipeline — Android
# Uso: ./benchmark.sh <model_remote_path> [output_dir]

set -euo pipefail

MODEL_PATH="${1:-/data/local/tmp/deepseek.gguf}"
OUTPUT_DIR="${2:-./benchmark_results}"
DEVICE="${ADB_SERIAL:-}"
ADB="adb${DEVICE:+ -s $DEVICE}"
TS=$(date +%Y%m%d_%H%M%S)
REPORT="$OUTPUT_DIR/bench_$TS"
mkdir -p "$REPORT"

echo "=== NanoAI Benchmark Pipeline v1.0 ===" | tee "$REPORT/log.txt"

step() { echo ""; echo "[$1/10] $2" | tee -a "$REPORT/log.txt"; }

step 1 "Verificando dispositivo..."
$ADB devices | tee -a "$REPORT/log.txt"
ANDROID_VER=$($ADB shell "getprop ro.build.version.release" | tr -d '\r')
HW=$($ADB shell "getprop ro.product.model" | tr -d '\r')
echo "  $HW · Android $ANDROID_VER"

step 2 "Espacio en disco..."
$ADB shell "df -h /data/local/tmp" | tee "$REPORT/disk_space.txt"

step 3 "Temperatura inicial..."
$ADB shell "cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -10" | tee "$REPORT/temp_initial.txt"

step 4 "RAM inicial..."
$ADB shell "cat /proc/meminfo" | tee "$REPORT/meminfo_initial.txt"
RAM_TOTAL=$($ADB shell "grep MemTotal /proc/meminfo | awk '{print \$2}'" | tr -d '\r')

step 5 "Batería..."
$ADB shell "dumpsys battery | grep -E 'level|temperature|voltage|status'" | tee "$REPORT/battery.txt"
BATTERY=$($ADB shell "dumpsys battery | grep level" | awk '{print $2}' | tr -d '\r')
echo "  Batería: ${BATTERY}%"
[ "$BATTERY" -lt 30 ] && echo "  ⚠️  Batería baja. Recomendado >= 50%"

step 6 "Verificando modelo..."
$ADB shell "ls -la '$MODEL_PATH'" | tee "$REPORT/model_stat.txt"
MODEL_SIZE=$($ADB shell "stat -c%s '$MODEL_PATH'" | tr -d '\r')
echo "  Tamaño: $(( MODEL_SIZE / 1024 / 1024 )) MB"

step 7 "Benchmark UFS (escritura/lectura)..."
$ADB shell "dd if=/dev/zero of=/data/local/tmp/nano_bench bs=64M count=4 oflag=direct 2>&1" | tee "$REPORT/ufs_write.txt"
$ADB shell "dd if=/data/local/tmp/nano_bench of=/dev/null bs=64M 2>&1" | tee "$REPORT/ufs_read.txt"
$ADB shell "rm -f /data/local/tmp/nano_bench"

step 8 "Ejecutando modelo..."
T0=$(date +%s%N)
RESULT=$($ADB shell "
export LD_LIBRARY_PATH=/data/local/tmp:\$LD_LIBRARY_PATH
/data/local/tmp/nanortime \\
    --model '$MODEL_PATH' \\
    --prompt 'Explain the attention mechanism in transformers.' \\
    --max-tokens 200 \\
    --temperature 0.0 2>&1" || echo "RUNTIME_ERROR")
T1=$(date +%s%N)
ELAPSED_MS=$(( (T1 - T0) / 1000000 ))
echo "$RESULT" | tee "$REPORT/output.txt"
TPS=$(echo "$RESULT" | grep -oP '[0-9.]+ tok/s' | head -1 || echo "N/A")
echo "  Elapsed: ${ELAPSED_MS}ms · TPS: $TPS"

step 9 "Estado post-benchmark..."
$ADB shell "cat /proc/meminfo" | tee "$REPORT/meminfo_final.txt"
$ADB shell "cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -10" | tee "$REPORT/temp_final.txt"
RAM_FREE=$($ADB shell "grep MemAvailable /proc/meminfo | awk '{print \$2}'" | tr -d '\r')
TEMP_MAX=$(cat "$REPORT/temp_final.txt" 2>/dev/null | sort -n | tail -1 || echo "0")

step 10 "Generando reporte..."
cat > "$REPORT/benchmark.json" << EOF
{
  "timestamp": "$TS",
  "device": {
    "model": "$HW",
    "android": "$ANDROID_VER",
    "ram_total_kb": $RAM_TOTAL,
    "ram_available_final_kb": $RAM_FREE,
    "battery_pct": $BATTERY,
    "max_temp_millidegree": ${TEMP_MAX:-0}
  },
  "model": {
    "path": "$MODEL_PATH",
    "size_bytes": $MODEL_SIZE
  },
  "results": {
    "elapsed_ms": $ELAPSED_MS,
    "tokens_per_second": "$TPS",
    "status": "$(echo "$RESULT" | grep -qi error && echo ERROR || echo OK)"
  }
}
EOF

echo "timestamp,device,android,ram_kb,battery,elapsed_ms,tps" > "$REPORT/benchmark.csv"
echo "$TS,$HW,$ANDROID_VER,$RAM_TOTAL,$BATTERY,$ELAPSED_MS,$TPS" >> "$REPORT/benchmark.csv"

echo ""
echo "✅ Benchmark completado."
echo "   JSON : $REPORT/benchmark.json"
echo "   CSV  : $REPORT/benchmark.csv"
echo ""
cat "$REPORT/benchmark.json"
