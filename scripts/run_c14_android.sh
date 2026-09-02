#!/usr/bin/env bash
# run_c14_android.sh — benchmark físico C14-A reproducible en el CPH2557.
# Mismo flujo y mismo runtime que run_c14_android.ps1.
#
# exit: 0 = todos los gates pasan, 1 = gates fallan, 2 = infra/preflight.
set -euo pipefail

DEVICE="${1:-CPH2557}"
APP_ID="dev.nanoai.mobile"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/products/nanoMOBILE/flutter_app"
APK="$APP_DIR/build/app/outputs/flutter-apk/app-debug.apk"
COMMIT="$(git -C "$ROOT" rev-parse --short HEAD)"

fail_infra() { echo "INFRA: $1" >&2; exit 2; }

adb devices | grep -q "$DEVICE" || fail_infra "Device $DEVICE no detectado"

(
  cd "$APP_DIR"
  flutter build apk --debug \
    --dart-define=GIT_COMMIT="$COMMIT" \
    --dart-define=DEVICE_MODEL="$DEVICE" \
    --dart-define=NANO_BOOT_PROFILE=automation-benchmark \
  || exit 2
)

adb -s "$DEVICE" install -r "$APK" || fail_infra "install falló"
adb -s "$DEVICE" shell am start -n "$APP_ID/.MainActivity" || true
adb -s "$DEVICE" shell input keyevent 82 || true
sleep 2

OUT="$(
  cd "$APP_DIR"
  flutter test integration_test/c14_automation_benchmark_test.dart -d "$DEVICE" 2>&1 || true
)"
echo "$OUT" | tee "$ROOT/c14_out.txt"

# ADB flaky: transporte caído NO es fallo del agente, es infra.
adb devices | grep -q "$DEVICE" || fail_infra "INFRA_DEVICE_DISCONNECTED"

if JSON="$(echo "$OUT" | grep -o 'C14_REPORT:.*' | head -1 | sed 's/^C14_REPORT://')"; then
  GATES_PASS="$(echo "$JSON" | jq -e '.report.gates | all(.pass == true)' 2>/dev/null || echo false)"
  echo "C14 gates pass: $GATES_PASS"
  [ "$GATES_PASS" = "true" ] && exit 0 || exit 1
else
  echo "$OUT" | grep -q "preflight no pas" && fail_infra "C14 preflight" || exit 1
fi
