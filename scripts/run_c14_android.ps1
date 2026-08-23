# run_c14_android.ps1 — benchmark físico C14-A reproducible en el CPH2557.
#
# flujo: device detect → build APK (dart-defines reproducibles) → install →
#        launch → unlock → run integration benchmark → parse C14_REPORT JSON →
#        exit code.
#
# exit:  0 = todos los gates pasan
#        1 = gates del benchmark fallan
#        2 = infraestructura / preflight falla (device, build, install, modelo)
param(
  [string]$Device = "CPH2557",
  [string]$AppId = "dev.nanoai.mobile"
)
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$appDir = Join-Path $root "products\nanoMOBILE\flutter_app"
$apk = Join-Path $appDir "build\app\outputs\flutter-apk\app-debug.apk"
$commit = (git -C $root rev-parse --short HEAD)

function Fail-Infra([string]$msg) { Write-Error $msg; exit 2 }

# 1. device detect
if (-not (adb devices | Select-String $Device)) { Fail-Infra "Device $Device no detectado" }

# 2. build APK con contexto reproducible
Push-Location $appDir
flutter build apk --debug `
  --dart-define=GIT_COMMIT=$commit `
  --dart-define=DEVICE_MODEL=$Device
if ($LASTEXITCODE -ne 0) { Pop-Location; Fail-Infra "build APK falló" }
Pop-Location

# 3. install
adb -s $Device install -r $apk | Out-Null
if ($LASTEXITCODE -ne 0) { Fail-Infra "install falló" }

# 4. launch + unlock (best effort; el preflight del test valida runtime/modelo)
adb -s $Device shell am start -n "$AppId/.MainActivity" | Out-Null
adb -s $Device shell input keyevent 82 | Out-Null   # wake/unlock
Start-Sleep -Seconds 2

# 5. run el integration benchmark (preflight interno aborta si falta modelo)
$out = Push-Location $appDir; flutter test "integration_test\c14_automation_benchmark_test.dart" -d $Device 2>&1; Pop-Location
$out | Tee-Object -FilePath (Join-Path $root "c14_out.txt") | Out-Host

# 6. parse C14_REPORT:<json>
$m = $out | Select-String "C14_REPORT:(.+)"
if ($m) {
  $json = $m.Matches[0].Groups[1].Value | ConvertFrom-Json
  $gatesPass = ($json.report.gates | Where-Object { $_.pass -eq $false }).Count -eq 0
  Write-Host "C14 gates pass: $gatesPass"
  if ($gatesPass) { exit 0 } else { exit 1 }
} else {
  if ($out -match "preflight no pas") { Write-Error "C14 preflight (infra)"; exit 2 }
  Write-Error "C14 sin reporte (test falló)"; exit 1
}
