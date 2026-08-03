param(
    [Parameter(Mandatory=$true)]
    [string]$ModelPath,
    [string]$RemoteDest = "/data/local/tmp",
    [int]$ChunkSizeMB = 500,
    [int]$MaxRetries = 5,
    [string]$DeviceSerial = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ADB = if ($DeviceSerial) { "adb -s $DeviceSerial" } else { "adb" }
$LogFile = "transfer_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$ModelName = Split-Path $ModelPath -Leaf
$RemotePath = "$RemoteDest/$ModelName"

function Log {
    param([string]$Msg, [string]$Level = "INFO")
    $ts = Get-Date -Format "HH:mm:ss"
    $line = "[$ts][$Level] $Msg"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

function Wait-Device {
    Log "Esperando reconexión ADB..."
    Invoke-Expression "$ADB wait-for-device" 2>$null
    Start-Sleep -Seconds 2
}

function Get-LocalSHA256 { param([string]$P); (Get-FileHash -Path $P -Algorithm SHA256).Hash.ToLower() }

function Get-RemoteSHA256 {
    param([string]$P)
    $r = (Invoke-Expression "$ADB shell `"sha256sum '$P' 2>/dev/null`"") -split '\s+'
    return $r[0].Trim().ToLower()
}

function Disable-UsbSuspend {
    Log "Deshabilitando USB Selective Suspend..."
    powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null
    powercfg /setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null
}

function Enable-KeepAwake {
    Invoke-Expression "$ADB shell `"settings put global stay_on_while_plugged_in 3`"" 2>$null
    Invoke-Expression "$ADB shell `"input keyevent KEYCODE_WAKEUP`"" 2>$null
}

# Pre-checks
Log "=== NanoAI Model Transfer v1.0 ==="
if (-not (Test-Path $ModelPath)) { Log "Modelo no encontrado: $ModelPath" "ERROR"; exit 1 }
$modelSizeMB = (Get-Item $ModelPath).Length / 1MB
Log "Modelo: $ModelPath ($([math]::Round($modelSizeMB,1)) MB)"

Disable-UsbSuspend
Enable-KeepAwake

# SHA256 local
Log "Calculando SHA256..."
$localHash = Get-LocalSHA256 $ModelPath
Log "SHA256: $localHash"

# Verificar si ya existe
$remoteExists = (Invoke-Expression "$ADB shell `"[ -f '$RemotePath' ] && echo yes || echo no`"" 2>$null).Trim()
if ($remoteExists -eq "yes") {
    $remoteHash = Get-RemoteSHA256 $RemotePath
    if ($localHash -eq $remoteHash) { Log "✅ Modelo ya correctamente copiado. SHA256 coincide."; exit 0 }
    Log "SHA256 no coincide. Eliminando archivo remoto corrupto." "WARN"
    Invoke-Expression "$ADB shell `"rm '$RemotePath'`"" 2>$null
}

# Dividir en chunks
$chunkDir = "$env:TEMP\nanoai_$(Get-Date -Format 'HHmmss')"
New-Item -ItemType Directory -Path $chunkDir -Force | Out-Null

$stream = [System.IO.File]::OpenRead($ModelPath)
$buf = New-Object byte[] ($ChunkSizeMB * 1024 * 1024)
$idx = 0; $chunks = @()

Log "Dividiendo en chunks de ${ChunkSizeMB}MB..."
while (($read = $stream.Read($buf, 0, $buf.Length)) -gt 0) {
    $name = "chunk_{0:D4}.part" -f $idx
    $path = Join-Path $chunkDir $name
    $slice = if ($read -lt $buf.Length) { $buf[0..($read-1)] } else { $buf }
    [System.IO.File]::WriteAllBytes($path, $slice)
    $chunks += $path
    $idx++
}
$stream.Close()
Log "Total: $idx chunks"

# Push chunks
$total = $chunks.Count; $done = 0

foreach ($chunk in $chunks) {
    $name = Split-Path $chunk -Leaf
    $remote = "$RemoteDest/$name"
    $retries = 0; $ok = $false

    while (-not $ok -and $retries -lt $MaxRetries) {
        try {
            Enable-KeepAwake
            $t0 = Get-Date
            $result = Invoke-Expression "$ADB push `"$chunk`" `"$remote`"" 2>&1
            if ($LASTEXITCODE -eq 0) {
                $elapsed = ((Get-Date)-$t0).TotalSeconds
                $spd = ((Get-Item $chunk).Length / 1MB) / $elapsed
                Log "  ✅ $name — $([math]::Round($spd,1)) MB/s"
                $ok = $true; $done++
            } else { throw "adb push failed: $result" }
        } catch {
            $retries++
            Log "  WARN: $_ (intento $retries/$MaxRetries)" "WARN"
            if ($retries -lt $MaxRetries) { Wait-Device; Enable-KeepAwake }
        }
    }

    if (-not $ok) { Log "FATAL: fallo en $name tras $MaxRetries intentos" "ERROR"; exit 1 }
    Log "Progreso: $done/$total ($([math]::Round($done/$total*100,0))%)"
}

# Ensamblar
Log "Ensamblando en el dispositivo..."
Invoke-Expression "$ADB shell `"cat $RemoteDest/chunk_*.part > '$RemotePath' && rm $RemoteDest/chunk_*.part`"" 2>&1
Log "Ensamblado OK."

# Verificar integridad
Log "Verificando SHA256 remoto..."
$remoteHash = Get-RemoteSHA256 $RemotePath
if ($localHash -eq $remoteHash) {
    Log "✅ TRANSFERENCIA EXITOSA — SHA256 verificado"
} else {
    Log "❌ SHA256 no coincide: local=$localHash remoto=$remoteHash" "ERROR"
    exit 1
}

Remove-Item $chunkDir -Recurse -Force
Log "=== Completado ==="
