# NanoRuntime — Telemetría por corrida (protocolo de reproducción)

Protocolo de instrumentación reutilizable para cerrar con datos reales los
puntos 2 (throughput/disponibilidad), 5 (comparación de baselines) y 7 (memory
leaks) de la revisión. **No fabrica métricas**: toda métrica que no puede
medirse en una plataforma se escribe como `null` con un motivo explícito en
`collection_status`.

## Fuentes

- Capa reutilizable: `scripts/telemetry.py` (parsers, collectors, orquestador,
  escritores JSONL/CSV/manifest).
- Harnesses instrumentados:
  - `scripts/android_stress_test.py` (Android vía ADB)
  - `scripts/stress_test.py` (PC Linux/Windows local)
  - `scripts/pc_ablation.py` (ablación CPU/paging: NanoRuntime vs llama.cpp)
  - `tests/pc_benchmark.py` (PC: CUDA/CPU vs llama.cpp, separados)
- Análisis estadístico: `scripts/analyze_telemetry.py` (solo lee el JSONL nuevo)
- Tests: `tests/test_telemetry.py` (`python -m pytest tests/test_telemetry.py -v`)

## Artefactos generados (append-only, nunca se sobrescriben)

```
data/research/telemetry/
├── runs.jsonl      # una línea JSON por corrida (schema_version 1.0)
├── runs.csv        # CSV derivado de runs.jsonl
└── manifest.jsonl  # una línea por sesión de ejecución (commit, comando, config)
```

## Esquema de registro (schema_version 1.0)

```json
{
  "schema_version": "1.0",
  "run_id": "uuid",
  "timestamp_utc": "ISO-8601",
  "platform": "android|windows|linux",
  "device": {"model": "", "os": "", "kernel": ""},
  "engine": "nanortime|llama.cpp",
  "model": {"path": "", "sha256": "", "parameters": "", "quantization": ""},
  "configuration": {"context_size": 0, "batch_size": 0, "prompt_id": "",
                    "output_token_limit": 0, "warmup": false, "iteration": 0,
                    "engine_mode": "cuda|cpu|madvise|mmap|no-mmap"},
  "result": {"exit_code": 0, "success": true, "wall_ms": 0,
             "latency_ms": 0, "tokens": 0, "tok_s": 0},
  "memory_before": {},
  "memory_after": {},
  "memory_peak": {},
  "memory_series": [{"elapsed_ms": 0, "rss_mb": 0, "pss_mb": 0,
                     "rss_anon_mb": 0, "rss_file_mb": 0}],
  "cpu": {"cpu_user_ms": 0, "cpu_system_ms": 0, "cpu_percent": 0},
  "io": {"read_bytes": 0, "write_bytes": 0, "read_chars": 0,
         "write_chars": 0, "read_count": 0, "write_count": 0},
  "page_faults": {"minor": 0, "major": 0, "total": 0},
  "collection_status": {"ok": {}, "unavailable": {}, "notes": []},
  "manifest": {"git_commit": "", "schema_version": "1.0"}
}
```

Claves de memoria (todas en MB, `null` si no disponible):
`rss_mb`, `vms_mb`, `pss_mb`, `rss_anon_mb`, `rss_file_mb`, `private_mb`,
`shared_mb`, `swap_mb`, `pagefile_mb`, `uss_mb`, `peak_wset_mb`,
`working_set_mb`, `mem_available_mb`, `mem_total_mb`.

## Métricas disponibles por plataforma

| Métrica | Android/Linux (fuente) | Windows (fuente) |
|---|---|---|
| `rss_mb` / `vms_mb` | `/proc/<pid>/status` VmRSS/VmSize (fallback `stat`/`statm`) | `psutil.memory_info()` |
| `pss_mb` | `smaps_rollup` Pss | — (`null`, no expuesto) |
| `rss_anon_mb` | `smaps_rollup` Anonymous | — (`null`) |
| `rss_file_mb` | `smaps_rollup` Rss − Anonymous | — (`null`) |
| `private_mb` / `shared_mb` | `smaps_rollup` Private/Shared (Clean+Dirty) | `private_mb` vía `memory_full_info()`; `shared_mb` `null` |
| `swap_mb` | `smaps_rollup` Swap / `status` VmSwap | `null` (se usa `pagefile_mb`) |
| `pagefile_mb` / `uss_mb` / `peak_wset_mb` | — (`null`) | `psutil.memory_full_info()` |
| `mem_available_mb` / `mem_total_mb` | `/proc/meminfo` | `psutil.virtual_memory()` (aprox.) |
| CPU user/system | `/proc/<pid>/stat` utime/stime (ticks) | `psutil.cpu_times()` |
| I/O | `/proc/<pid>/io` | `psutil.io_counters()` |
| fallos de página | `/proc/<pid>/stat` minflt/majflt | `GetProcessMemoryInfo().PageFaultCount` (ctypes; sin split minor/major) |

`mem_available_mb` es **solo** una señal global de presión; **nunca** se usa
como prueba de ausencia de fuga. La evidencia de fuga requiere `rss_anon_mb`
(tendencia) + fallos de página + I/O de almacenamiento + CPU.

## Métricas NO disponibles y por qué

- **Windows `pss_mb`, `rss_anon_mb`, `rss_file_mb`, `shared_mb`**: requieren
  `smaps`/`smaps_rollup` de Linux; Windows no los expone. Se escribe `null` +
  motivo en `collection_status`.
- **Windows `swap_mb`**: `psutil` no lo expone; se registra `pagefile_mb`.
- **Windows minor/major page faults**: `GetProcessMemoryInfo` solo da
  `PageFaultCount` total; minor/major quedan `null` con motivo explícito.
- **Linux/Android `pagefile_mb`, `uss_mb`, `peak_wset_mb`**: conceptos de
  Windows; `null` + motivo.
- Cualquier lectura que falle en runtime (permisos, proceso muerto) se marca
  `null` con motivo; **jamás** se rellena con cero.

## Comandos de ejecución documentados

Requisitos previos: dispositivo Android con `adb` conectado, `nanortime`
compilado (`cargo build --release -p nanortime-cli`), modelo GGUF en
`/data/local/tmp/` (Android) o ruta local (PC). `psutil` y `scipy` instalados.

### Android — OPPO CPH2557, modelo 7B (DeepSeek-R1-Distill-Qwen-7B Q4_K_M)

```powershell
python scripts/android_stress_test.py `
  --device <OPPO_SERIAL> `
  --model /data/local/tmp/deepseek.gguf `
  --prompts 5 `
  --max-tokens 32 `
  --timeout 600
```

### Android — OPPO CPH2557, modelo 1.5B (Qwen-2.5-1.5B Q4_K_M)

```powershell
python scripts/android_stress_test.py `
  --device <OPPO_SERIAL> `
  --model /data/local/tmp/qwen.gguf `
  --prompts 20 `
  --max-tokens 64
```

### Android — Samsung Galaxy A30s, modelo 1.5B (Qwen-2.5-1.5B Q4_K_M)

```powershell
python scripts/android_stress_test.py `
  --device <SAMSUNG_SERIAL> `
  --model /data/local/tmp/qwen.gguf `
  --prompts 20 `
  --max-tokens 64
```

> Separación obligatoria: **7B solo en OPPO; Samsung solo 1.5B.** No mezclar
> en tablas, resúmenes ni análisis.

### PC — ablación CPU/paging (NanoRuntime vs llama.cpp --mmap vs --no-mmap)

```powershell
python scripts/pc_ablation.py `
  --nanortime target/release/nanortime.exe `
  --llama-cli "C:\llama-cpp-server\bin\llama-cli.exe" `
  --model "C:\llama-cpp-server\models\qwen2.5-1.5b-instruct-q4_k_m.gguf" `
  --iterations 10 `
  --max-tokens 80
```

### PC — benchmark separado CUDA/CPU (NO mezclar con la ablación)

```powershell
python tests/pc_benchmark.py --iterations 5 --tokens 80
```

### PC — stress de estabilidad (Windows/Linux local)

```powershell
python scripts/stress_test.py `
  --binary target/release/nanortime.exe `
  --model "C:\llama-cpp-server\models\qwen2.5-1.5b-instruct-q4_k_m.gguf" `
  --iterations 15
```

### Análisis estadístico (solo JSONL nuevo)

```powershell
python scripts/analyze_telemetry.py --jsonl data/research/telemetry/runs.jsonl --out data/research/telemetry/stats_report.json
```

Si no se han corrido los benchmarks, `analyze_telemetry.py` emite el esquema y
`NO RESULTS YET`; no inventa p-values ni intervalos.

## Pruebas

```powershell
python -m pytest tests/test_telemetry.py -v
```

Cubre: parser de `/proc/<pid>/stat` (con `comm` con espacios y paréntesis),
parser de `smaps_rollup`, cálculo de deltas, y el caso de métrica no disponible
(`null` + motivo, nunca valor inventado).
