# Benchmark final V1 — 4 regímenes con los modelos disponibles (sin descargas).
#
# Mismo patrón robusto del sweep G6: launch despegado (nohup + timeout en
# device + log local) y poll con adb cortos. NO correr durante el sweep.
#
# Filas del benchmark (plan Fase 3):
#   1.5B auto  → FAST     (baseline residente, rápido)
#   9B  W=32   → OOM      (full resident: naive approach muere)
#   9B  W*     → stable   (NanoRuntime: vivo y útil — W* sale del sweep G6)
#   27B auto   → EXTREME  (alive pero no interactivo — can_run ≠ should_run)
#
# Uso:
#   .\v1_benchmark.ps1 -Wstar 4 -Model27 Qwen3.8-27B-Q4_K_M.gguf
#   .\v1_benchmark.ps1 -Wstar 4 -Model27 Qwen3.8-27B-Q4_K_M.gguf -Only 27B

param(
    [int]$Wstar = 4,
    [string]$Model15 = "qwen2.5-1.5b-instruct-q4_k_m.gguf",
    [string]$Model9 = "qwen9b.gguf",
    [string]$Model27 = "Qwen3.8-27B-Q4_K_M.gguf",
    [string]$Prompt = "Cuanto es 7 por 8?",
    [int]$NTokens = 16,
    [int]$TimeoutSec = 900,
    [string]$Only = "",
    [string]$Output = "v1_benchmark.csv"
)

$ErrorActionPreference = "Continue"
$Adb = "C:\Users\emman\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$DevLog = "/data/local/tmp/v1_bench.log"

function Get-Device {
    $out = & $Adb devices 2>$null
    return ($out -match "\s+device\s*$")
}

function Adb-Short {
    param([string]$Cmd)
    for ($i = 0; $i -lt 3; $i++) {
        $r = & $Adb shell $Cmd 2>$null
        if ($LASTEXITCODE -eq 0) { return $r }
        Start-Sleep -Milliseconds 800
    }
    return $null
}

# Configs: label, model, window ("auto" | número), repeat, expect
$Configs = @(
    @{ Label = "1.5B_FAST";     Model = $Model15; W = "auto"; Repeat = 2; Expect = "FAST" }
    @{ Label = "9B_FULL";       Model = $Model9;  W = 32;     Repeat = 1; Expect = "OOM" }
    @{ Label = "9B_WSTAR";      Model = $Model9;  W = $Wstar; Repeat = 3; Expect = "STABLE" }
    @{ Label = "27B_EXTREME";   Model = $Model27; W = "auto"; Repeat = 1; Expect = "ALIVE_EXTREME" }
)

if (-not (Get-Device)) { throw "Dispositivo no conectado" }

$header = "label,model,window,rep,success,tok_s,fault_rate,pss_mb,ttft_ms,thrash,expect"
Write-Output $header
$header | Out-File -FilePath $Output -Encoding utf8

foreach ($cfg in $Configs) {
    if ($Only -and $cfg.Label -ne $Only) { continue }
    $label = $cfg.Label; $model = $cfg.Model; $w = $cfg.W; $expect = $cfg.Expect

    # ¿El modelo está en el device?
    $exists = Adb-Short "test -f /data/local/tmp/$model && echo yes"
    if (-not $exists) {
        $row = "$label,$model,$w,-,SKIP,-,-,-,-,-,$expect (push pendiente)"
        Write-Output $row
        $row | Out-File -FilePath $Output -Append -Encoding utf8
        continue
    }

    for ($rep = 1; $rep -le $cfg.Repeat; $rep++) {
        $WinEnv = if ($w -eq "auto") { "" } else { "NANORTIME_RESIDENCY_WINDOW=$w" }
        Adb-Short "pkill -x nanortime 2>/dev/null; sleep 1; cd /data/local/tmp && LD_LIBRARY_PATH=/data/local/tmp $WinEnv nohup timeout $TimeoutSec ./nanortime --model $model --prompt '$Prompt' --edge-only -n $NTokens --log-level info > $DevLog 2>&1 &" | Out-Null

        $snip = $null
        $deadline = (Get-Date).AddSeconds($TimeoutSec + 60)
        while ((Get-Date) -lt $deadline -and -not $snip) {
            Start-Sleep -Seconds 5
            $snip = Adb-Short "grep -E '\[METRICS\]|post-gen|ttft_ms=' $DevLog 2>/dev/null | tail -3"
            if (-not $snip) {
                $alive = Adb-Short "pidof nanortime"
                if (-not $alive) { break }
            }
        }

        $success = "FAIL/OOM"
        $tok_s = "-"; $fault = "-"; $pss = "-"; $thrash = "-"; $ttft_ms = "-"

        if ($snip) {
            $metrics = $snip | Select-String "\[METRICS\]" | Select-Object -First 1
            if ($metrics) {
                $success = "OK"
                if ($metrics.Line -match 'tok_s=([\d.]+)') { $tok_s = $matches[1] }
            }
            $postgen = $snip | Select-String "post-gen" | Select-Object -First 1
            if ($postgen) {
                if ($postgen.Line -match 'fault_rate=([\d.]+)') { $fault = $matches[1] }
                if ($postgen.Line -match 'pss_mb=([\d.]+)') { $pss = $matches[1] }
                if ($postgen.Line -match 'thrash=(\w+)') { $thrash = $matches[1] }
            }
            $ttft = $snip | Select-String "ttft_ms=" | Select-Object -First 1
            if ($ttft -and $ttft.Line -match 'ttft_ms=(\d+)') { $ttft_ms = $matches[1] }
        }

        $row = "$label,$model,$w,$rep,$success,$tok_s,$fault,$pss,$ttft_ms,$thrash,$expect"
        Write-Output $row
        $row | Out-File -FilePath $Output -Append -Encoding utf8

        if ($success -ne "OK") {
            $tail = Adb-Short "tail -5 $DevLog 2>/dev/null"
            if ($tail) { Write-Output "    [tail] $($tail -join ' | ')" }
        }
    }
}

Write-Output "`nCSV guardado en $Output"
Write-Output "Expect: 1.5B→OK rápido · 9B_FULL→OOM · 9B_WSTAR→OK estable · 27B→OK lentísimo o alive sin tokens"
