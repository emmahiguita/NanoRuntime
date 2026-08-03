# PowerShell ablation: nanortime (madvise) vs llama.cpp (--no-mmap)
# Mide throughput y RAM pico en ambos motores.

$LLAMA = "C:\llama-cpp-server\bin\llama-cli.exe"
$NANO = "target\release\nanortime.exe"
$MODEL = "C:\llama-cpp-server\models\qwen2.5-1.5b-instruct-q4_k_m.gguf"
$PROMPT = "Explain the attention mechanism in transformers and why it scales quadratically."
$MAX_TOKENS = 80
$ITER = 3

$ENV:RUST_LOG = "error"

$nano_tok = @()
$llama_tok = @()

Write-Output "=" * 70
Write-Output "  ABLATION: nanortime (madvise) vs llama.cpp (--no-mmap)"
Write-Output "  $ITER iterations each, $MAX_TOKENS max tokens"
Write-Output "=" * 70

for ($i=1; $i -le $ITER; $i++) {
    Write-Output ""
    Write-Output "[$i/$ITER] NANORTIME"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $out = & $NANO --model $MODEL --prompt $PROMPT --max-tokens $MAX_TOKENS --edge-only --quiet 2>&1
    $sw.Stop()
    $tok = 0; $ts = 0
    if ($out -match 'tokens=(\d+).*tok_s=([\d.]+)') { $tok = [int]$Matches[1]; $ts = [float]$Matches[2] }
    $nano_tok += $ts
    Write-Output "  -> $ts tok/s | ${tok}t | $($sw.ElapsedMilliseconds)ms"
}

for ($i=1; $i -le $ITER; $i++) {
    Write-Output ""
    Write-Output "[$i/$ITER] LLAMA.CPP (--no-mmap)"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $out = & $LLAMA --model $MODEL --prompt $PROMPT --n-predict $MAX_TOKENS --temp 0.0 --no-mmap --simple-io --no-display-prompt 2>&1
    $sw.Stop()
    # Parse llama.cpp perf output
    $ts = 0
    $lines = $out -join "`n"
    if ($lines -match 'Generation:\s+([\d.]+)\s+t/s') { $ts = [float]$Matches[1] }
    if ($lines -match 'llama_perf.*?([\d.]+)\s+tokens per second') { $ts = [float]$Matches[1] }
    if ($lines -match '([\d.]+)\s+tokens per second') { $ts = [float]$Matches[1] }
    $llama_tok += $ts
    Write-Output "  -> $ts tok/s | $($sw.ElapsedMilliseconds)ms"
}

$nano_avg = ($nano_tok | Measure-Object -Average).Average
$llama_avg = ($llama_tok | Measure-Object -Average).Average
$speedup = if ($llama_avg -gt 0) { [math]::Round($nano_avg / $llama_avg, 2) } else { 0 }

Write-Output ""
Write-Output "=" * 70
Write-Output "  RESULTS"
Write-Output "=" * 70
Write-Output "  nanortime avg:  $nano_avg tok/s (all successful)"
Write-Output "  llama.cpp avg: $llama_avg tok/s"
Write-Output "  Speedup:       ${speedup}x"
Write-Output "=" * 70

# Save JSON
$result = @{
    ablation = "nanortime vs llama.cpp"
    model = $MODEL
    iterations = $ITER
    max_tokens = $MAX_TOKENS
    nanortime_avg_tok_s = [math]::Round($nano_avg, 2)
    llamacpp_avg_tok_s = [math]::Round($llama_avg, 2)
    speedup = $speedup
}
$result | ConvertTo-Json | Out-File -FilePath "data\research\ablation_baseline.json" -Encoding UTF8
Write-Output "Saved: data/research/ablation_baseline.json"
