# Pruebas Funcionales — NanoRuntime Telemetry

Suite de pruebas que valida que el dashboard y el servidor funcionan con datos
REALES (hardware nvidia-smi/psutil + inferencia nanortime.exe), no simulados.

## Requisitos

- Python 3.11+ con `websockets` (`pip install websockets`)
- Node.js 21+ (WebSocket global integrado)
- Modelo GGUF en `data/qwen_tmp.gguf` y motor en `target/release/nanortime.exe`

## Servidor (tests/server_tests.py)

Gestiona su propio ciclo de vida: inicia `server/main.py`, ejecuta las pruebas
y lo detiene.

```powershell
python tests\server_tests.py
```

Cubre:
- `/metrics` y `/api/v1/system-info`
- Contrato del WebSocket: 18 campos reales, cero campos fake
- Cadencia de snapshots (500ms)
- Ciclo real de inferencia (tok/s, ms/token, tokens, texto)
- Modo deshabilitado (`NANO_INFERENCE_ENABLED=0`)
- Modelo inexistente → error descriptivo

## Cliente (tests/client_sync_test.js)

Replica la lógica de sincronización de `dashboard/src/app/page.tsx` contra el
servidor en vivo.

```powershell
# 1) servidor corriendo
python server\main.py
# 2) en otra terminal
node tests\client_sync_test.js
```

Cubre:
- Flujo continuo de snapshots (~2/s)
- Ventana deslizante (MAX_POINTS)
- Timestamps incrementales
- Deduplicación de ciclos de inferencia

## Lógica estadística (tests/logic_tests.mjs)

Pruebas unitarias del módulo REAL `dashboard/src/lib/telemetryStream.ts`
(ejecutado con Node 24 type-stripping, sin duplicar lógica).

```powershell
node --experimental-strip-types tests\logic_tests.mjs
```

Cubre:
- Entrada vacía → ceros
- Deduplicación de valores consecutivos (cada muestra = ciclo real)
- Percentiles P50/P90/P95/P99, media, desviación (comparados con simple-statistics)
- Skewness/kurtosis muestrales reales (no heurísticas)
- Guards con muestras insuficientes
- Tendencia de throughput (regresión lineal)
- Ceros ignorados (sin medición aún)

## Datos reales en vivo (tests/live_logic_test.mjs)

Valida el cálculo estadístico contra mediciones REALES del servidor.

```powershell
# 1) servidor corriendo
python server\main.py
# 2) en otra terminal
node --experimental-strip-types tests\live_logic_test.mjs
```

Cubre: `latencySamples` = ciclos distintos, percentiles en rango plausible,
integridad de hardware real (VRAM/temp/CPU/RAM).

## Código de salida

`0` = todas las pruebas PASSA · `1` = al menos una falla
