# Revisión crítica: "Modo DOOM/ESP32" — aplicabilidad sin dañar la lógica funcional

*Objetivo: determinar qué técnicas del plan son aplicables a NanoRuntime sin
romper la lógica funcional, usando la arquitectura real del repo y las
mediciones de la sesión del 2026-08-01. Verdicto por técnica: ✅ Aplicar ·
⚠️ Medir primero · ❌ Descartar.*

---

## 0. El hecho arquitectónico que decide todo

El bucle de generación (decode) vive **dentro de llama.cpp (C/C++)**, vía
`llama-cpp-2`. La capa Rust solo orquesta: `rx.recv().await` (canal tokio),
`print!` + `flush` por token, muestreo, routing. Medido:

| Costo real por token | Rust (orquestación + flush) | C++ (decode) |
|---|---|---|
| 1.5B PC (49 tok/s) | ~5-50µs flush + µs canal | **~20 ms** |
| 1.5B OPPO (3.23 tok/s) | µs | **~310 ms** |
| 7B OPPO (0.14-0.38 tok/s) | µs | **~2.6-7 s** |

Conclusión: el overhead de orquestación Rust es **<0.5% del costo total**.
Las 6 técnicas del plan optimizan la capa que no es el cuello de botella.
Cualquier ganancia de tok/s declarada por ellas (30-40%, 10-20%) **no es
alcanzable** sin tocar llama.cpp, que el plan no toca.

## 1. Verdicto por técnica

| # | Técnica | Verdicto | Razón |
|---|---|---|---|
| 1 | Scheduler tick-based (10ms) | ❌ | `tokio` ya entrega tokens con latencia µs; un tick de 10ms **añadiría** 10ms de latencia por token (10ms vs decode 20ms-7s). El jitter de ready-queue de tokio es inmedible frente al decode. Riesgo de romper el streaming async que funciona |
| 2 | Memory pools estáticos (bumpalo/wee_alloc) | ⚠️→❌ | La medición real ya logra delta RSS **0.5 MB / std 0.141 MB** en 10 runs *sin* pools. La meta "varianza <0.2 MB" está alcanzada. Además `wee_alloc` está **deprecado/abandonado**; y la asignación caliente es de llama.cpp (allocator propio), no de la capa Rust |
| 3 | CPU pinning + SCHED_RR | ⚠️ | `SCHED_RR` exige `CAP_SYS_NICE`/root — **no disponible en Android** para la app. Pinning vía `sched_setaffinity` es posible pero Android ya usa cpusets big.LITTLE; y un pinning mal hecho **aumenta** la térmica (concentra calor en los cores grandes). Requiere experimento controlado ANTES de tocar código |
| 4 | I/O en chunks 4KB/256KB | ⚠️ | llama.cpp ya lee el GGUF en bloques de tensor (MBs) con `pread`; el runtime ya emite `MADV_SEQUENTIAL`. El eMMC del A30s mide 875/621 MB/s (log termux) — suficiente para el modelo 1.5B. El 7B es **CPU-bound** (0.14 tok/s = 7s decode), no I/O-bound: acelerar I/O no mueve tok/s. Medible pero marginal |
| 5 | Telemetry desacoplada (ring buffer) | ✅ | La única con aplicabilidad real, pero **ya está hecha**: el servidor no loguea por snapshot (broadcast async, 0.5s); el CLI emite `[METRICS]` una vez al final. La afirmación "-15% tok/s por logging" no se sostiene: nuestros runs miden sin logging en el loop. Nada que hacer |
| 6 | Fixed-point / INT-only | ❌ | **Ya existe**: Q4_K_M es matmul entero (cuantización 4-bit). La FP16 de atención en ARM: Cortex-A55 (A30s) tiene NEON FP16 (códec aritmético). El claim "10-20%" ignora el estado del arte de ggml. Reescribir kernels = tocar llama.cpp = máximo riesgo de romper la lógica |

## 2. Errores fácticos del plan

1. **"Portabilidad a ESP32-S3 con PSRAM"** — imposible para estos modelos:
   un 1.5B Q4 = ~1 GB; el ESP32-S3 tiene máx. 8 MB PSRAM. Un 7B jamás
   entrará. La frase "un motor, cualquier hardware" es marketing para LLM
   de este tamaño.
2. **`wee_alloc` deprecado** — abandonado desde 2021; recomendado
   `mimalloc`/`snmalloc`, o mejor: no tocar el allocator global.
3. **"Kernels ARM sin FPU eficiente"** — A73/A55 (Exynos 7904) tienen NEON
   con FP16 aritmético. La premisa es falsa para el hardware real.
4. **"RSS drift +1.2 MB sin optimización"** — contradice la medición real:
   delta **0.5 MB** sin ninguna optimización del plan.
5. **"0.29 ± 0.12 tok/s"** — la medición real 7B OPPO es 0.14-0.38 con
   varianza **térmica** (3 runs), no jitter de scheduler.
6. **"Thermal throttle a ~18s"** — sin log que lo respalde; la caída medida
   (0.38→0.14) ocurre entre *ejecuciones*, no a los 18s de una ejecución.

## 3. La tabla "antes vs después" contra la evidencia real

| Claim del plan (sin opt.) | Medición real de la sesión | Verdicto |
|---|---|---|
| tok/s 7B: 0.29 ± 0.12 | 0.14 / 0.18 / 0.38 (3 runs, térmica) | Rango real similar, causa mal atribuida |
| RSS drift: +1.2 MB | delta **0.5 MB**, std 0.141 | Claim inflado 2.4× — ya es plano |
| Throttle a 18s → 0.12 tok/s | Sin log; la caída es entre runs | No verificable |
| Logging: -15% tok/s | Sin logging en el loop; flush <0.5% | Falso |
| <2 GB RAM viable | 1.5B (1.07GB) sí; 7B (4.47GB) no cabe | Parcial (modelo pequeño) |

## 4. Lo que SÍ se puede hacer sin dañar la lógica

**Experimento 1 (medir primero, cero código):** Sustained run 30 min de
1.5B en OPPO + Samsung con tok/s y temp muestreados cada 10s → cuantificar
si existe decay térmico real y a qué escala. Si hay decay >50%, evaluar
pinning a cores grandes (experimento adb, no código).

**Experimento 2 (medir primero):** Comparar `--no-mmap` vs `--mmap` del
mismo modelo en móvil (el plan asume mmap lento; nuestros datos muestran
lo contrario en PC: mmap 2501 vs no-mmap 2030 MB). Medir RSS + tok/s en
ambos modos en el teléfono antes de tocar nada.

**Cambio seguro (único):** Nada del plan toca el hot path de decode. La
única micro-mejora con riesgo cero y medible: batching del flush de
stdout en el CLI (flush cada N tokens en vez de por token) — pero el dato
muestra <0.5% de costo, así que el beneficio sería estadísticamente
invisible. **Recomendación: no hacerlo** (evitar cambio sin beneficio).

## 5. Qué NO tocar (protección de la lógica funcional)

- **No** sustituir `tokio` streaming por scheduler tick — rompería el
  streaming async y el [METRICS] que alimenta todo el observatorio.
- **No** añadir `SCHED_RR` — no funciona en Android y arriesga estabilidad.
- **No** reescribir kernels de atención/INT en llama.cpp — riesgo máximo,
  beneficio nulo (ya cuantizado).
- **No** `wee_alloc`/bumpalo global — deprecado y sin métrica que mover.
- **No** activar nada automáticamente con "MemAvailable < 300MB" — el
  `oom_guard`/`AdaptiveScheduler` actual YA hace degradación con umbral 15%
  y funciona (log real verificado); superponer otra capa de activación
  duplicaría lógica y arriesgaría la degradación probada.

## 6. Verdicto estratégico

- **Para el paper**: correcto del plan — no es obligatorio. La contribución
  (madvise + oom_guard + degradación + routing) está validada.
- **Para el producto**: las técnicas del plan atacan el 0.5% de la latencia.
  La estabilidad que buscan (determinismo) ya está lograda en la capa que
  importa (decode C++ estable + degradación probada). Si se quiere
  determinismo real, la palanca correcta es la **gestión térmica** (medir
  decay, pinning de experimento), no el scheduler ni los pools.
- **Riesgo global**: aplicar el plan como está **sí dañaría la lógica
  funcional** — reemplaza piezas probadas (tokio, degradación, allocator)
  por versiones no validadas para un bottleneck inexistente.

## 7. Resultado empírico del experimento térmico (2026-08-01, post-revisión)

El experimento sugerido en la sección 4 se ejecutó en AMBOS dispositivos
(`tests/thermal_experiment.py`, 10 runs × 80 tokens, temp SoC vía
`dumpsys thermalservice` + frecuencia `scaling_cur_freq`):

| Dispositivo | DECAY tok/s | Temp pico | Frecuencia |
|---|---|---|---|
| Samsung A30s (Exynos 7904) | **−0.9%** | 50.8°C | 73-90% del max |
| OPPO CPH2557 (Snapdragon 695) | **+0.6%** | 59.6°C | n/d |

**Conclusión: decay <1% — sin throttling significativo.** El claim central
del plan DOOM ("throttle activa a ~18s → cae a 0.12 tok/s") queda
**falsificado con datos**: la temperatura superó 43°C en ambos y el tok/s
permaneció plano (Samsung incluso subió 2.583→2.607). El **pacing reactivo
propuesto NO se implementa** — añadiría ~5% de tiempo muerto sin beneficio
medido. La pregunta térmica que el plan planteó se respondió con el dato
que faltaba: **el sistema ya es térmicamente estable en su workload real.**
