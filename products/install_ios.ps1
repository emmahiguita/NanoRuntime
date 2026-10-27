# ==============================================================================
# NanoAI — Instalador y Desplegador Automatizado iOS desde Windows
# ==============================================================================
param (
    [switch]$SkipPush = $false
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   NanoAI — Instalador y Desplegador iOS desde Windows    " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Comprobar GitHub CLI
Write-Host "[1/5] Verificando GitHub CLI (gh)..." -ForegroundColor Yellow
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI (gh.exe) no está instalado o no está en el PATH."
    exit 1
}

$ghStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "GitHub CLI no está autenticado. Ejecuta 'gh auth login' primero."
    exit 1
}
Write-Host " -> GitHub CLI autenticado correctamente." -ForegroundColor Green

# 2. Localizar Sideloadly
Write-Host "[2/5] Verificando instalación de Sideloadly..." -ForegroundColor Yellow
$sideloadlyExe = "$env:LOCALAPPDATA\Sideloadly\sideloadly.exe"
if (-not (Test-Path $sideloadlyExe)) {
    Write-Warning "Sideloadly no se encontró en '$sideloadlyExe'."
    Write-Host "Descárgalo e instálalo desde: https://sideloadly.io" -ForegroundColor White
    exit 1
}
Write-Host " -> Sideloadly detectado en: $sideloadlyExe" -ForegroundColor Green

# 3. Sincronizar y Subir al Repositorio (si no se omite)
$repoRoot = (git rev-parse --show-toplevel).Trim()
Set-Location $repoRoot

if (-not $SkipPush) {
    Write-Host "[3/5] Comprobando cambios y workflow de compilación..." -ForegroundColor Yellow
    git add .github/workflows/build_ios.yml
    git add products/nanoMOBILE/flutter_app/ios/
    
    $status = git status --porcelain
    if ($status) {
        Write-Host " -> Confirmando cambios de configuración iOS..." -ForegroundColor White
        git commit -m "ci(ios): configurar build automatizado de NanoAI.ipa y Podfile"
    }
    
    Write-Host " -> Enviando código a GitHub (git push origin master)..." -ForegroundColor White
    git push origin master
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "El push falló o no hubo cambios pendientes. Continuando con workflow..."
    }
} else {
    Write-Host "[3/5] Omitiendo sincronización git (--SkipPush activo)..." -ForegroundColor Gray
}

# 4. Iniciar y Monitorear GitHub Actions
Write-Host "[4/5] Disparando compilación de NanoAI.ipa en GitHub Actions..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

# Disparar workflow manualmente si está disponible
gh workflow run build_ios.yml --ref master 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host " -> Workflow disparado exitosamente." -ForegroundColor Green
} else {
    Write-Host " -> Esperando detección del commit en GitHub Actions..." -ForegroundColor White
}

# Esperar el inicio de la corrida
Write-Host " -> Conectando con el runner macOS en la nube..." -ForegroundColor White
Start-Sleep -Seconds 8

$runId = ""
for ($i = 0; $i -lt 15; $i++) {
    $runId = (gh run list --workflow=build_ios.yml --limit 1 --json databaseId --jq '.[0].databaseId').Trim()
    if ($runId) { break }
    Start-Sleep -Seconds 3
}

if (-not $runId) {
    Write-Error "No se pudo obtener el ID de ejecución de GitHub Actions."
    exit 1
}

Write-Host " -> Ejecución iniciada [ID: $runId]. Monitoreando compilación..." -ForegroundColor Cyan
gh run watch $runId

# 5. Descargar Artefacto IPA y Lanzar Sideloadly
Write-Host "[5/5] Descargando NanoAI.ipa compilado..." -ForegroundColor Yellow
$outDir = Join-Path $repoRoot "build_ios_artifacts"
if (Test-Path $outDir) { Remove-Item $outDir -Recurse -Force }
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

gh run download $runId --name "NanoAI-iOS-IPA" --dir $outDir

$ipaFile = Get-ChildItem -Path $outDir -Filter "*.ipa" -Recurse | Select-Object -First 1
if (-not $ipaFile) {
    Write-Error "No se encontró el archivo NanoAI.ipa en los artefactos descargados."
    exit 1
}

Write-Host " -> IPA descargado con éxito: $($ipaFile.FullName)" -ForegroundColor Green

# Reset de base de datos de Sideloadly (para evitar bloqueos o fallos residuales)
$resetScript = Join-Path $repoRoot "products\reset_sideloadly.py"
if (Test-Path $resetScript) {
    Write-Host " -> Optimizando estado previo de Sideloadly..." -ForegroundColor Gray
    python $resetScript 2>$null
}

# Abrir Sideloadly con el archivo IPA cargado
Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " ¡NanoAI.ipa LISTO PARA INSTALAR! " -ForegroundColor Green
Write-Host " Abriendo Sideloadly automáticamente..." -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Green

Start-Process -FilePath $sideloadlyExe -ArgumentList "`"$($ipaFile.FullName)`""

Write-Host "`nPasos finales en tu iPhone:" -ForegroundColor White
Write-Host " 1. Conecta tu iPhone por USB y pulsa 'Confiar en este ordenador'." -ForegroundColor White
Write-Host " 2. En Sideloadly pulsa 'Start' (ingresa tu Apple ID gratuito si lo solicita)." -ForegroundColor White
Write-Host " 3. En el iPhone ve a: Ajustes > General > VPN y gestión de dispositivos > Confiar." -ForegroundColor White
