# NanoRuntime V1 — Release Gates

Baseline congelado y reproducible. Tag: `nanoruntime-v1.0`.

Regla de veredicto: un gate está VERDE si pasa por test automatizado **o** por
verificación manual en dispositivo. Los tests cubren lógica; el hardware real
(OPPO/Android) cubre PSS, TTFT y termal. Nada se marca verde solo por intención.

| Gate | Criterio | Evidencia |
|------|----------|-----------|
| R1 | Server disponible antes de cargar modelo; TTID < 2s | Manual en dispositivo (liveness responde desde segundo 0) |
| R2 | `/liveness` 200 siempre; `/readiness` LOADING/READY/FAILED | `cargo test -p nanortime-cli server` |
| R3 | SSE emite heartbeat + fase de carga + timings | `chat_timings_test.dart` + `completion_sse_final_frame_includes_timings` |
| R4 | Timeout 45s + heartbeat de silencio | Manual (heartbeat `generating` en prefill largo) |
| R5 | NanoSession: gates de invalidación KV (modelo/template/rollback) | `session_kv_test.rs` + `session.rs` unit tests |
| R6 | Cancelación corta stream + KV queda en estado conocido | `chat_cancel_test.dart` + `session_registry_roundtrip` |
| R7 | 20 ciclos load/generate/unload sin fuga de estado | `lifecycle_soak_test.rs` |
| R8 | SHA256 obligatorio en descarga + oom_guard + mensajes honestos | Preexistente (catálogo + OomGuard) |
| R9 | ModelTier en UI; EXTREME exige confirmación | `chat_tier_gate_test.dart` |
| R10 | Timings por turno (TTFT, prefill, tok/s) en frame SSE | `chat_timings_test.dart` |
| R11 | Loopback puro + offline (sin red) | Preexistente (routing local) |
| R12 | 30 turnos de conversación sin crash ni corrupción | `chat_soak_test.dart` |

## Cómo reproducir

```bash
# Rust (core + server, feature simulated — sin GGUF real)
cargo clippy -p nanortime-core --features simulated -- -D warnings
cargo clippy -p nanortime-cli --features simulated -- -D warnings
cargo test -p nanortime-core --features simulated
cargo test -p nanortime-cli --features simulated server

# Flutter
cd products/nanoMOBILE/flutter_app
flutter analyze
flutter test test/chat_cancel_test.dart test/chat_timings_test.dart \
          test/chat_tier_gate_test.dart test/chat_soak_test.dart
```

O en una sola orden: `make release-gates` (o `bash scripts/release_gates.sh`).

## Verificación manual en dispositivo (OPPO/Android)

No reproducible en CI — requiere hardware:

```text
PSS peak/steady         → scripts/smaps_validator.py (lee /proc/<pid>/smaps_rollup)
TTFT / prefill / decode → telemetría [GenerationStats] en log del server
temperature / energy    → ThermalController + BatteryGuardian (telemetría)
model load/unload       → 20 ciclos manuales, sin zombies (doble instancia → huérfano)
```

## Notas honestas

- Tests de UI/layout (`chat_models_screens_test`, `chat_attachments_test`,
  `chat_tool_loop_test`) tienen fallos preexistentes de rendering/texto no
  relacionados con los gates. Se verifican manualmente; no bloquean V1.
- `cargo test --workspace` (default, sin `simulated`) compila llama.cpp vendor
  y requiere el toolchain ARM/NDK en Android; en CI ubuntu usa la matriz de
  features de producción.
