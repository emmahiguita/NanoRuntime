# ==============================================================================
# NanoAI - Instalador y Desplegador Automatizado iOS desde Windows
# ==============================================================================
param (
    [switch]$SkipPush = $false,
    [switch]$QuickInstall = $false
)

$ErrorActionPreference = 'Stop'

Write-Host '==========================================================' -ForegroundColor Cyan
Write-Host '   NanoAI - Instalador y Desplegador iOS desde Windows    ' -ForegroundColor Cyan
Write-Host '==========================================================' -ForegroundColor Cyan

# 1. Comprobar GitHub CLI
Write-Host '[1/5] Verificando GitHub CLI (gh)...' -ForegroundColor Yellow
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error 'GitHub CLI (gh.exe) no esta instalado o no esta en el PATH.'
    exit 1
}

$ghStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error 'GitHub CLI no esta autenticado. Ejecuta gh auth login primero.'
    exit 1
}
Write-Host ' -> GitHub CLI autenticado correctamente.' -ForegroundColor Green

# 2. Localizar Sideloadly
Write-Host '[2/5] Verificando instalacion de Sideloadly...' -ForegroundColor Yellow
$sideloadlyExe = "$env:LOCALAPPDATA\Sideloadly\sideloadly.exe"
if (-not (Test-Path $sideloadlyExe)) {
    Write-Error "Sideloadly no se encontro en $sideloadlyExe. Descargalo de https://sideloadly.io"
    exit 1
}
Write-Host " -> Sideloadly detectado en: $sideloadlyExe" -ForegroundColor Green

$productsDir = $PSScriptRoot
$repoRoot = (git rev-parse --show-toplevel).Trim()
$outDir = Join-Path $productsDir 'build_ios_artifacts'
$existingIpa = Join-Path $outDir 'NanoAI.ipa'

# Si no existe en products, buscar en repoRoot
if (-not (Test-Path $existingIpa)) {
    $altIpa = Join-Path $repoRoot 'build_ios_artifacts\NanoAI.ipa'
    if (Test-Path $altIpa) {
        $outDir = Join-Path $repoRoot 'build_ios_artifacts'
        $existingIpa = $altIpa
    }
}

if ($QuickInstall -or (Test-Path $existingIpa)) {
    Write-Host ''
    Write-Host '[INFO] NanoAI.ipa local ya existe. Omitiendo compilacion remota.' -ForegroundColor Green
} else {
    # 3. Sincronizar y Subir al Repositorio
    if (-not $SkipPush) {
        Write-Host '[3/5] Comprobando cambios de configuracion iOS...' -ForegroundColor Yellow
        git add .github/workflows/build_ios.yml
        git add products/nanoMOBILE/flutter_app/ios/
        $status = git status --porcelain
        if ($status) {
            git commit -m 'ci(ios): actualizar configuracion iOS'
        }
        Write-Host ' -> Enviando codigo a GitHub (branch ios-release)...' -ForegroundColor White
        git push origin HEAD:ios-release
    }

    # 4. Iniciar y Monitorear GitHub Actions
    Write-Host '[4/5] Monitoreando compilacion en GitHub Actions...' -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    $runId = (gh run list --workflow=build_ios.yml --limit 1 --json databaseId --jq '.[0].databaseId').Trim()
    if ($runId) {
        gh run watch $runId
        if (Test-Path $outDir) { Remove-Item $outDir -Recurse -Force }
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
        gh run download $runId --name 'NanoAI-iOS-IPA' --dir $outDir
    }
}

$ipaFile = Get-ChildItem -Path $outDir -Filter '*.ipa' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $ipaFile) {
    Write-Error "No se encontro el archivo NanoAI.ipa en $outDir."
    exit 1
}

Write-Host " -> IPA verificado: $($ipaFile.FullName)" -ForegroundColor Green

# Reset de base de datos de Sideloadly
$resetScript = Join-Path $repoRoot 'products\reset_sideloadly.py'
if (Test-Path $resetScript) {
    Write-Host ' -> Limpiando bloqueos previos de Sideloadly...' -ForegroundColor Gray
    python $resetScript 2>$null
}

# Abrir Sideloadly con el archivo IPA cargado
Write-Host ''
Write-Host '==========================================================' -ForegroundColor Green
Write-Host ' [OK] NanoAI.ipa LISTO PARA INSTALAR! ' -ForegroundColor Green
Write-Host ' Abriendo Sideloadly automaticamente...' -ForegroundColor Cyan
Write-Host '==========================================================' -ForegroundColor Green

Start-Process -FilePath $sideloadlyExe -ArgumentList @($ipaFile.FullName)

Write-Host ''
Write-Host 'Pasos finales en tu iPhone:' -ForegroundColor White
Write-Host ' 1. Conecta tu iPhone por USB y pulsa Confiar en este ordenador.' -ForegroundColor White
Write-Host ' 2. En Sideloadly pulsa Start (ingresa tu Apple ID gratuito).' -ForegroundColor White
Write-Host ' 3. En el iPhone: Ajustes -> General -> VPN y gestion de dispositivos -> Confiar.' -ForegroundColor White
