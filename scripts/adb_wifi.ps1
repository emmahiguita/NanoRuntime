<#
.SYNOPSIS
  Automatiza build + install + launch de NanoAI en OPPO CPH2557 via WiFi.
  Sin USB. Un comando = todo el ciclo.

.EXAMPLE
  .\adb_wifi.ps1 go          # conecta, build, install, launch
  .\adb_wifi.ps1 build       # solo flutter build apk --debug
  .\adb_wifi.ps1 install     # solo instalar APK existente
  .\adb_wifi.ps1 launch      # solo abrir la app
  .\adb_wifi.ps1 log         # tail de logs de la app
  .\adb_wifi.ps1 connect     # solo conectar WiFi
  .\adb_wifi.ps1 disconnect  # desconectar
  .\adb_wifi.ps1 ip          # mostrar IP del OPPO
#>

param(
    [ValidateSet("go", "build", "install", "launch", "log", "connect", "disconnect", "ip")]
    [string]$Action = "go"
)

$ErrorActionPreference = "Stop"
$TARGET = "192.168.0.8:5555"
$PKG    = "dev.nanoai.mobile"
$ACTIVITY = "$PKG.MainActivity"
$FLUTTER_DIR = Join-Path $PSScriptRoot "..\platforms\mobile\flutter_app"
$APK = Join-Path $FLUTTER_DIR "build\app\outputs\flutter-apk\app-debug.apk"

function Write-Step { param($msg) Write-Host "`n>>> $msg" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "  OK  $msg" -ForegroundColor Green }
function Write-ERR  { param($msg) Write-Host "  ERR $msg" -ForegroundColor Red }

$timer = [System.Diagnostics.Stopwatch]::StartNew()

# ── Connect ──
function Connect-WiFi {
    Write-Step "Conectando WiFi: $TARGET"
    adb connect $TARGET 2>&1 | Out-Null
    Start-Sleep -Seconds 1
    $devs = adb devices 2>&1 | Out-String
    if ($devs -match $TARGET) {
        Write-OK "Conectado a OPPO CPH2557"
    } else {
        Write-ERR "No se pudo conectar. Verifica que el OPPO esté en WiFi y debug activo."
        exit 1
    }
}

# ── Build ──
function Build-APK {
    Write-Step "Compilando APK debug..."
    Push-Location $FLUTTER_DIR
    try {
        $result = flutter build apk --debug 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-ERR "Build falló:"
            Write-Host ($result -join "`n") -ForegroundColor DarkGray
            exit 1
        }
        Write-OK "APK compilado: $((Get-Item $APK).Length / 1MB) MB"
    } finally {
        Pop-Location
    }
}

# ── Install ──
function Install-APK {
    if (-not (Test-Path $APK)) {
        Write-ERR "APK no encontrado: $APK"
        Write-Host "  Ejecuta primero: .\adb_wifi.ps1 build" -ForegroundColor Yellow
        exit 1
    }
    Write-Step "Instalando en OPPO..."
    $result = adb -s $TARGET install -r $APK 2>&1
    if ($LASTEXITCODE -ne 0) {
        # Reintentar una vez si falla por desconexión
        Write-Host "  Reintentando conexión..." -ForegroundColor Yellow
        adb disconnect 2>&1 | Out-Null
        adb connect $TARGET 2>&1 | Out-Null
        Start-Sleep -Seconds 2
        $result = adb -s $TARGET install -r $APK 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-ERR "Install falló: $result"
            exit 1
        }
    }
    Write-OK "Instalado en OPPO"
}

# ── Launch ──
function Launch-App {
    Write-Step "Abriendo NanoAI..."
    adb -s $TARGET shell am start -n "$PKG/$ACTIVITY" 2>&1 | Out-Null
    Write-OK "App lanzada"
}

# ── Log tail ──
function Tail-Logs {
    Write-Step "Logs de NanoAI (Ctrl+C para salir)..."
    adb -s $TARGET logcat -c 2>&1 | Out-Null
    adb -s $TARGET logcat -v time -s flutter,AndroidRuntime,System.err | Select-Object
}

# ── Dispatch ──
switch ($Action) {
    "go" {
        Connect-WiFi
        Build-APK
        Install-APK
        Launch-App
        Write-Host "`n=== LISTO en $($timer.Elapsed.TotalSeconds.ToString('0.0'))s ===" -ForegroundColor Green
    }
    "build"    { Build-APK }
    "install"  { Connect-WiFi; Install-APK }
    "launch"   { Connect-WiFi; Launch-App }
    "log"      { Connect-WiFi; Tail-Logs }
    "connect"  { Connect-WiFi }
    "disconnect" { Write-Step "Desconectando..."; adb disconnect $TARGET 2>&1 | Out-Null; Write-OK "Desconectado" }
    "ip"       { Write-Host "OPPO: $TARGET" -ForegroundColor Green }
}
