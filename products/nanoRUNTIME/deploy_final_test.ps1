# Deploy + final test — NanoRuntime streaming (modelo > RAM) en el OPPO.
#
# Maneja el USB inestable: parte el modelo en chunks de 2GB, pushea cada chunk
# con reintento (reconecta adb si la transferencia cae), reensambla en el
# dispositivo con `cat`, y lanza la inferencia con telemetría completa.
#
# Uso:
#   .\deploy_final_test.ps1 -Model "C:\...\Qwen3.8-27B-Q4_K_M.gguf" -Prompt "..."
#
param(
    [string]$Model = "C:\Users\emman\Downloads\Qwen3.8-27B-Q4_K_M.gguf",
    [string]$Device = "VGL7MVFMDYQG8T55",
    [string]$RemoteName = "qwen27b.gguf",
    [string]$Prompt = "Explica en una frase que es la entropia de Shannon.",
    [int]$ChunkGB = 2,
    [int]$MaxRetries = 3
)

$ErrorActionPreference = "Continue"
$Adb = "C:\Users\emman\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$Binary = "C:\Users\emman\Desktop\Proyectos\Nueva carpeta\Nanoai\target\aarch64-linux-android\release\nanortime"
$Tmp = "C:\Users\emman\AppData\Local\Temp\opencode"
$ChunkBytes = [int64]$ChunkGB * 1GB

function Wait-Device {
    for ($i = 0; $i -lt 10; $i++) {
        $out = & $Adb devices 2>$null
        if ($out -match "$Device\s+device") { return $true }
        & $Adb kill-server 2>$null | Out-Null
        Start-Sleep 2
        & $Adb start-server 2>$null | Out-Null
        Start-Sleep 2
    }
    return $false
}

Write-Host "=== Deploy final test ===" -ForegroundColor Cyan
if (-not (Test-Path $Model)) { throw "Modelo no existe: $Model" }
if (-not (Test-Path $Binary)) { throw "Binario no existe: $Binary (compila primero)" }

$fileSize = (Get-Item $Model).Length
Write-Host "Modelo: $Model ($([math]::Round($fileSize/1GB,2)) GB)"
Write-Host "Chunks de $ChunkGB GB, retries=$MaxRetries"

# 1. Conectar.
if (-not (Wait-Device)) { throw "Dispositivo no conectado" }
Write-Host "[1/4] Dispositivo OK" -ForegroundColor Green

# 2. Pushear binario.
& $Adb -s $Device push $Binary /data/local/tmp/nanortime 2>&1 | Out-Null
& $Adb -s $Device shell "chmod 755 /data/local/tmp/nanortime" 2>&1 | Out-Null
Write-Host "[2/4] Binario pusheado" -ForegroundColor Green

# 3. Chunked push del modelo.
& $Adb -s $Device shell "rm -f /data/local/tmp/$RemoteName" 2>&1 | Out-Null
$chunkIdx = 0
$offset = [int64]0
$src = [System.IO.File]::OpenRead($Model)

while ($offset -lt $fileSize) {
    $chunkPath = Join-Path $Tmp "chunk_$chunkIdx.gguf"
    $remaining = $fileSize - $offset
    $toRead = [Math]::Min($ChunkBytes, $remaining)

    # Extraer chunk.
    $dst = [System.IO.File]::Create($chunkPath)
    $buf = New-Object byte[] (8MB)
    $left = $toRead
    while ($left -gt 0) {
        $n = $src.Read($buf, 0, [int][Math]::Min([int64]$buf.Length, $left))
        if ($n -le 0) { break }
        $dst.Write($buf, 0, $n)
        $left -= $n
    }
    $dst.Close()

    # Push con retry (el USB cae ~8GB acumulado: reconectar y reintentar).
    $pushed = $false
    for ($r = 1; $r -le $MaxRetries; $r++) {
        $progress = "{0}% ($([math]::Round($offset/1GB,1))/{1} GB)" -f [math]::Round($offset*100/$fileSize,0), [math]::Round($fileSize/1GB,1)
        Write-Host "  chunk $chunkIdx ($([math]::Round($toRead/1GB,2)) GB) [$progress] intento $r/$MaxRetries"
        & $Adb -s $Device push $chunkPath "/data/local/tmp/chunk_$chunkIdx.gguf" 2>&1 | Out-Null
        # Verificar tamaño remoto (null si el device cayó → mismatch → reintento).
        $remoteOut = @(& $Adb -s $Device shell "stat -c %s /data/local/tmp/chunk_$chunkIdx.gguf 2>/dev/null" 2>$null)
        $remoteSize = if ($remoteOut.Count -gt 0 -and $remoteOut[0]) { "$($remoteOut[0])".Trim() } else { "" }
        if ($remoteSize -eq [string]$toRead) { $pushed = $true; break }
        Write-Host "    tamaño remoto '$remoteSize' != $toRead, reconectando..." -ForegroundColor Yellow
        if (-not (Wait-Device)) { throw "Dispositivo desconectado definitivamente" }
    }
    if (-not $pushed) { $src.Close(); throw "Chunk $chunkIdx no se pudo pushear tras $MaxRetries intentos" }

    $offset += $toRead
    $chunkIdx++
    Remove-Item $chunkPath -Force
}
$src.Close()
Write-Host "[3/4] Modelo pusheado en $chunkIdx chunks" -ForegroundColor Green

# 4. Reensamblar + verificar.
$catCmd = "cat"
for ($i = 0; $i -lt $chunkIdx; $i++) { $catCmd += " /data/local/tmp/chunk_$i.gguf" }
$catCmd += " > /data/local/tmp/$RemoteName"
& $Adb -s $Device shell $catCmd 2>&1 | Out-Null
$assembled = (& $Adb -s $Device shell "stat -c %s /data/local/tmp/$RemoteName 2>/dev/null").Trim()
if ([int64]$assembled -ne $fileSize) { throw "Reensamblado incorrecto: $assembled != $fileSize" }
for ($i = 0; $i -lt $chunkIdx; $i++) { & $Adb -s $Device shell "rm -f /data/local/tmp/chunk_$i.gguf" 2>&1 | Out-Null }
Write-Host "    tamaño verificado: $assembled bytes" -ForegroundColor Green

# 5. Prueba final.
Write-Host "=== Prueba final (streaming) ===" -ForegroundColor Cyan
& $Adb -s $Device shell "cd /data/local/tmp && LD_LIBRARY_PATH=/data/local/tmp ./nanortime --model $RemoteName --prompt '$Prompt' --edge-only -n 24 -t 0.7 --log-level info" 2>&1
Write-Host "=== FIN ===" -ForegroundColor Cyan
