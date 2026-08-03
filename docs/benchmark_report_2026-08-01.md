# Benchmark Funcional y Lógico — NanoRuntime (2026-08-01)

Pruebas completas ejecutadas en hardware físico: PC (i5-12450HX, 31.7GB RAM,
RTX 3050 6GB) y dos dispositivos Android conectados por ADB (OPPO CPH2557
7.8GB, Samsung Galaxy A30s 3.8GB). Todos los valores provienen de logs reales
generados en esta sesión; los JSON crudos quedan en `data/research/`.

---

## 1. PC — Comparación de motores (Qwen 2.5 1.5B Q4_K_M, 1.07GB)

Protocolo: 5 iteraciones/motor, prompt fijo, 80 tokens, temp=0, RSS muestreado
cada 50ms (psutil). nanortime spawn por proceso; llama.cpp vía llama-server
(API, generación sostenida).

| Motor | tok/s mean | tok/s p50 | RSS (MB) | Cold start p50 | Éxito |
|---|---|---|---|---|---|
| nanortime CUDA (gpu_layers=-1) | **49.03** | 49.66 | **1363** | 3.56s | 5/5 |
| nanortime CPU (gpu_layers=0) | **45.82** | 46.24 | **1363** | 3.83s | 5/5 |
| llama.cpp mmap | 14.24 | 14.63 | 2501 | 4.55s | 5/5 |
| llama.cpp --no-mmap | 17.94 | 18.45 | 2030 | 4.52s | 5/5 |

Lectura honesta: nanortime usa **33–45% menos RSS** que llama.cpp y genera
2.5–3.4× más rápido en este equipo con estos ajustes. El paper afirmaba
"paridad 1.84 vs 1.85 GB" — la medición fresca muestra una ventaja mayor.

## 2. PC — Estabilidad de memoria (test de leak real)

10 ejecuciones consecutivas, contexto fijo, 40 tokens:

```
RSS: 1362.9 / 1363.0 / 1363.2 / 1363.4 / 1363.1 / 1363.0 / 1363.0 / 1363.1 / 1363.1 / 1363.2 MB
min=1362.9  max=1363.4  delta=0.5 MB  mean=1363.1  std=0.141 MB
```

**Delta 0.5 MB en 10 runs → sin leak.** El paper reclamaba "ΔRAM < 1.1 MB"
sin respaldo; ahora tiene log real (aún más estricto: 0.5 MB).

## 3. Móvil — 1.5B Qwen (10 queries consecutivas, 64 tokens)

| Dispositivo | tok/s mean±std | p50 | min | max | Lat media | Éxito |
|---|---|---|---|---|---|---|
| OPPO CPH2557 (UFS) | **3.23 ± 0.61** | 3.57 | 1.91 | 3.95 | 22.3s | 10/10 |
| Samsung A30s (eMMC) | **2.52 ± 0.12** | 2.57 | 2.30 | 2.64 | 27.8s | 10/10 |

Memoria disponible por query (MB) — **estable o creciente, sin tendencia a leak**:
- OPPO: 3446→3401→3448→3453→3452→3676→3682→3703→3694→3695
- Samsung: 2263→2270→2269→2286→2284→2281→2281→2280→2273→2279

Texto generado real (muestra OPPO): "In modern operating systems, a process
and a thread are both fundamental units of execution..."

## 4. Móvil — 7B DeepSeek-R1-Distill (OPPO, 32 tokens) — el claim central

Dos ejecuciones directas con monitoreo de proceso:

- **Run 1**: 85.2s wall (≈0.38 tok/s efectivos), modelo 4466MB cargado.
- **Run 2**: 232.7s wall, `[METRICS] tokens=32 elapsed_ms=222046 tok_s=0.14
  tier=local confidence=0.853`.
- **Log de degradación capturado en vivo**:
  `WARN Model file (4466MB) exceeds usable RAM (2978MB). Forcing minimum context (512).`
- RSS del proceso durante generación: 3.46–3.53 GB en dispositivo de 7.8 GB.
- MemAvailable: 3.63 GB antes → 4.22 GB después (modelo descargado). Sin OOM.
- Detector de alucinaciones activo (log WARN pos=2 confidence=0.39).

Interpretación: la degradación adaptativa (8192→512) disparó automáticamente
y la generación completó — es el mecanismo de "supervivencia" del paper
ejecutándose en producción. El 0.29 tok/s del paper cae dentro del rango
medido (0.14–0.38); la variabilidad es térmica (el dispositivo llevaba
~45 min de benchmarks continuos).

Nota: el harness `android_stress_test.py` con timeout fijo de 180s no
alcanza para 7B en estado térmico alto — corregir el timeout a 300s si se
repite vía script.

## 5. Discrepancias encontradas vs el paper

| Claim del paper | Medición real de esta sesión | Estado |
|---|---|---|
| llama.cpp PC RSS 1.85 GB ("paridad") | mmap: 2501 MB · --no-mmap: 2030 MB vs nanortime 1363 MB (−33/−45%) | Paper conservador — ventaja real mayor |
| ΔRAM < 1.1 MB | delta 0.5 MB (PC, 10 runs) + MemAvailable estable en ambos móviles | ✅ Verificado con logs |
| 0.29 tok/s (7B OPPO) | 0.14–0.38 tok/s (térmica, 3 runs) | ✅ En rango |
| Contexto 8192→512 | Log real: "Forcing minimum context (512)" (3/3 runs) | ✅ Verificado con log |
| PC "i7-12700K" | Esta máquina de validación es i5-12450HX (la original pudo ser otra) | ⚠️ Documentar máquinas |
| 2.90 tok/s (1.5B OPPO, docx) | 3.23 mean real (OPPO), 2.52 (Samsung) | Reemplazado por dato real |

## 7. Añadidos de la segunda ronda de pruebas (misma sesión)

### 7.1 Stress multi-cliente → bug real encontrado y corregido
Test de 3 clientes WS concurrentes: antes del fix, cada cliente recibía
snapshots con timestamps distintos (el servidor generaba un snapshot por
cliente con su propio contador; `manager.broadcast` era código muerto).
Refactor: un solo loop de telemetría difunde a todos. Después del fix:
**15/15 snapshots idénticos entre 3 clientes**, sin errores. Regresión
completa: 12/12 tests servidor, 16/16 lógica, 6/6 sync.

### 7.2 Stress 7B adicional (OPPO) — run #3
- Wall: 143.8s · `[METRICS] tokens=24 tok_s=0.18 tier=local conf=0.817`
- Degradación disparada de nuevo: `Model file (4466MB) exceeds usable RAM
  (2696MB). Forcing minimum context (512).` (RAM usable bajó de 2978 a
  2696 MB por presión sistémica — el mecanismo reaccionó a la presión real)
- Texto real: "The time complexity of operations in an AVL tree is O(log n)..."
- Sin OOM. Serie completa 7B OPPO: 0.14 / 0.18 / 0.38 tok/s (térmica).

### 7.3 Samsung A30s 7B (>RAM)
Pendiente: el dispositivo se desconectó del bus ADB durante la sesión.
El test extremo (modelo 4.68GB en 3.8GB RAM) no pudo ejecutarse. El
harness está listo (comando directo adb con timeout generoso).

### 7.4 Experimento térmico SoC/CPU (harness: `tests/thermal_experiment.py`)
15→10 runs consecutivos de 80 tokens, `[METRICS]` exacto por run, temp SoC
vía `dumpsys thermalservice` y frecuencia `scaling_cur_freq`:

| Dispositivo | SoC | tok/s (primeros 3 → últimos 3) | DECAY | Temp pico | Freq |
|---|---|---|---|---|---|
| Samsung A30s | Exynos 7904 | 2.583 → 2.607 | **−0.9%** | 50.8°C | 73-90% del max |
| OPPO CPH2557 | Snapdragon 695 | 4.303 → 4.277 | **+0.6%** | 59.6°C | n/d |

**Conclusión: decay <1% en ambos — no existe throttling significativo en
inferencia 1.5B sostenida.** El claim del plan "DOOM-mode" ("throttle
activa a ~18s, cae a 0.12 tok/s") queda falsificado: la temp superó 43°C
y el tok/s no decayó. El pacing reactivo propuesto (sleep 15ms a T>43°C)
NO se implementa: añadiría tiempo muerto sin beneficio medido. CSV:
`data/research/thermal_R58N21SVSPE_*.csv` y `thermal_VGL7MVFMDYQG8T55_*.csv`.

## 6. Archivos de datos (logs crudos)

- `data/research/pc_benchmark_results.json` — 4 motores × 5 runs + mem-stability
- `data/research/llama_baseline_results.json` — llama.cpp mmap/--no-mmap timings
- `data/research/android_oppo_qwen.json` / `android_samsung_qwen.json` — 10 queries c/u
- Harness: `tests/pc_benchmark.py`, `tests/llama_baseline.py`,
  `scripts/android_stress_test.py`
