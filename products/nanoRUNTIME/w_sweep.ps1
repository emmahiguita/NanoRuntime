# Barrido de W (ventana residente) — valida que el planner acierta el óptimo.
#
# Corre NANORTIME_RESIDENCY_WINDOW = 2..32 sobre el modelo en el device y
# extrae por corrida: success, tok/s, fault_rate, PSS, thrash. Sirve para
# comparar "planner recommendation ≈ experimental optimum".
#
# Uso:
#   .\w_sweep.ps1 -Model qwen9b.gguf -Ws 2,4,8,12,16,24,32 -NTokens 16

param(
    [string]$Model = "qwen9b.gguf",
    [int[]]$Ws = @(2, 4, 8, 12, 16, 24, 32),
    [string]$Prompt = "Cuanto es 7 por 8?",
    [int]$NTokens = 16
)

$ErrorActionPreference = "Continue"
$Adb = "C:\Users\emman\AppData\Local\Android\Sdk\platform-tools\adb.exe"

function Get-Device {
    $out = & $Adb devices 2>$null
    return ($out -match "\s+device\s*$")
}

if (-not (Get-Device)) { throw "Dispositivo no conectado" }

Write-Output "W  | success | tok_s  | fault_rate/s | pss_mb  | thrash"
Write-Output "---|---------|--------|--------------|---------|-------"

foreach ($w in $Ws) {
    $out = & $Adb shell "cd /data/local/tmp && LD_LIBRARY_PATH=/data/local/tmp NANORTIME_RESIDENCY_WINDOW=$w ./nanortime --model $Model --prompt '$Prompt' --edge-only -n $NTokens --log-level info" 2>&1

    $metrics = $out | Select-String "\[METRICS\]" | Select-Object -First 1
    $postgen = $out | Select-String "post-gen" | Select-Object -First 1
    $residency = $out | Select-String "\[Residency\]" | Select-Object -First 1

    if ($metrics) {
        $success = "OK"
        $tok_s = if ($metrics.Line -match 'tok_s=([\d.]+)') { $matches[1] } else { "?" }
    } else {
        $success = "FAIL/OOM"
        $tok_s = "-"
    }

    $fault = if ($postgen -and $postgen.Line -match 'fault_rate=([\d.]+)') { $matches[1] } else { "-" }
    $pss = if ($postgen -and $postgen.Line -match 'pss_mb=([\d.]+)') { $matches[1] } else { "-" }
    $thrash = if ($postgen -and $postgen.Line -match 'thrash=(\w+)') { $matches[1] } else { "-" }

    $res = if ($residency) { " ($($residency.Line -replace '.*modelo\s+\d+\s+MB\s+[><]\s+presupuesto\s+\d+\s+MB:\s+', '' -replace '\s+—.*$', ''))" } else { "" }

    Write-Output ("{0,-2} | {1,-7} | {2,-6} | {3,-12} | {4,-7} | {5}{6}" -f $w, $success, $tok_s, $fault, $pss, $thrash, $res)
}

Write-Output "`nNota: success=FAIL/OOM cuando no se generaron tokens (proceso muerto o timeout)."
