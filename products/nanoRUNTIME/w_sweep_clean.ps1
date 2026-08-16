# Barrido de W LIMPIO — protocolo G6 de NanoRuntime V1.
#
# Elimina el sesgo de cache del orden monótono (2→4→8...) usando tres
# corridas rotadas desde estado fresh. Cada W se mide Repeat veces dentro
# de cada corrida.
#
# Órdenes (fijados en el plan V1):
#   Run A: 2 → 4 → 8 → 12 → 16 → 24 → 32
#   Run B: 16 → 4 → 24 → 2 → 32 → 8 → 12
#   Run C: 8 → 32 → 4 → 16 → 2 → 24 → 12
#   Run D: auto (sin NANORTIME_RESIDENCY_WINDOW — ventana derivada del
#          presupuesto por el runtime). Fila crítica del plan: AUTO debe
#          acercarse al mejor W manual (W*). N≥5 → -Sweeps D -Repeat 5.
#
# ROBUSTEZ (aprendida del gate G5 en ColorOS): adb shell muere (exit 255)
# bajo carga pesada de I/O. Por eso cada corrida se lanza DESPEGADA en el
# device (nohup + timeout de toybox + log local) y el host hace poll con
# comandos adb CORTOS e independientes — un corte de adb no mata la
# corrida ni al script, solo reintenta el poll.
#
# Métricas por medición: success, tok_s, fault_rate/s, pss_mb, ttft_ms,
# tok_avg_ms, tok_p90_ms, thrash. (p50 no existe en los logs del binario:
# se reporta avg/p90, honesto.)
#
# Uso:
#   .\w_sweep_clean.ps1 -Model qwen9b.gguf -Sweeps A,B,C -Repeat 2 -NTokens 16

param(
    [string]$Model = "qwen9b.gguf",
    [string[]]$Sweeps = @("A", "B", "C"),
    [int]$Repeat = 2,
    [string]$Prompt = "Cuanto es 7 por 8?",
    [int]$NTokens = 16,
    [int]$RunTimeoutSec = 240,
    [string]$Output = "w_sweep_clean.csv"
)

$ErrorActionPreference = "Continue"
$Adb = "C:\Users\emman\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$DevLog = "/data/local/tmp/sweep_run.log"

$Orders = @{
    A = @(2, 4, 8, 12, 16, 24, 32)
    B = @(16, 4, 24, 2, 32, 8, 12)
    C = @(8, 32, 4, 16, 2, 24, 12)
    D = @("auto")
}

function Get-Device {
    $out = & $Adb devices 2>$null
    return ($out -match "\s+device\s*$")
}

# Comando adb corto con reintento: devuelve $null si adb está caído.
function Adb-Short {
    param([string]$Cmd)
    for ($i = 0; $i -lt 3; $i++) {
        $r = & $Adb shell $Cmd 2>$null
        if ($LASTEXITCODE -eq 0) { return $r }
        Start-Sleep -Milliseconds 800
    }
    return $null
}

if (-not (Get-Device)) { throw "Dispositivo no conectado" }

$header = "run,order,w,rep,success,tok_s,fault_rate,pss_mb,ttft_ms,tok_avg_ms,tok_p90_ms,thrash"
Write-Output $header
$header | Out-File -FilePath $Output -Encoding utf8

foreach ($run in $Sweeps) {
    if (-not $Orders.ContainsKey($run)) { throw "Sweep desconocido: $run (A, B, C)" }
    foreach ($w in $Orders[$run]) {
        for ($rep = 1; $rep -le $Repeat; $rep++) {
            $runId = "$run/$w/$rep"

            # Lanzamiento despegado en device: nohup + timeout de toybox
            # + log local. Retorna inmediato; adb no transporta stdout.
            # w=auto → sin env: el runtime deriva la ventana del presupuesto.
            $WinEnv = if ($w -eq "auto") { "" } else { "NANORTIME_RESIDENCY_WINDOW=$w" }
            Adb-Short "pkill -x nanortime 2>/dev/null; sleep 1; cd /data/local/tmp && LD_LIBRARY_PATH=/data/local/tmp $WinEnv nohup timeout $RunTimeoutSec ./nanortime --model $Model --prompt '$Prompt' --edge-only -n $NTokens --log-level info > $DevLog 2>&1 &" | Out-Null

            # Poll: greps cortos hasta [METRICS] o muerte del proceso o timeout.
            $snip = $null
            $deadline = (Get-Date).AddSeconds($RunTimeoutSec + 30)
            while ((Get-Date) -lt $deadline -and -not $snip) {
                Start-Sleep -Seconds 5
                $snip = Adb-Short "grep -E '\[METRICS\]|post-gen|ttft_ms=' $DevLog 2>/dev/null | tail -3"
                if (-not $snip) {
                    # ¿Proceso murió sin emitir METRICS? (OOM/kill).
                    # pidof: exit 1 cuando no existe → Adb-Short devuelve $null.
                    # (grep -x contra ps -A nunca matchea: la línea tiene USER/PID.)
                    $alive = Adb-Short "pidof nanortime"
                    if (-not $alive) { break }
                }
            }

            $success = "FAIL/OOM"
            $tok_s = "-"; $fault = "-"; $pss = "-"; $thrash = "-"
            $ttft_ms = "-"; $avg_ms = "-"; $p90_ms = "-"

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
                    if ($postgen.Line -match 'tok_avg_ms=([\d.]+)') { $avg_ms = $matches[1] }
                    if ($postgen.Line -match 'tok_p90_ms=([\d.]+)') { $p90_ms = $matches[1] }
                }
                $ttft = $snip | Select-String "ttft_ms=" | Select-Object -First 1
                if ($ttft -and $ttft.Line -match 'ttft_ms=(\d+)') { $ttft_ms = $matches[1] }
            }

            $row = "$run,$($Orders[$run] -join '>'),$w,$rep,$success,$tok_s,$fault,$pss,$ttft_ms,$avg_ms,$p90_ms,$thrash"
            Write-Output $row
            $row | Out-File -FilePath $Output -Append -Encoding utf8

            # Post-mortem solo en fallo: tail del log del device para diagnóstico.
            if ($success -ne "OK") {
                $tail = Adb-Short "tail -5 $DevLog 2>/dev/null"
                if ($tail) { Write-Output "    [tail] $($tail -join ' | ')" }
            }
        }
    }
}

Write-Output "`nCSV guardado en $Output"
Write-Output "Nota: success=FAIL/OOM cuando no se emitio [METRICS] (proceso muerto, timeout o kill)."
