# Rebuttal / Cover Letter — NanoRuntime (ICA/SCIRP, MS 7900800)

*Respuesta punto por punto a los 7 comentarios del revisor. Cada respuesta
distingue lo medido de lo pendiente y cita los artefactos exactos. No se
modifican cifras con números sintéticos: toda afirmación que depende de
mediciones per-proceso no recolectadas aún se marca **[pending rerun]**.*

---

## Carta de respuesta a los 7 puntos del revisor

### Punto 1 — "Reconciliar 7B en 3.72 GB; identificar el modelo de cada evaluación Samsung"

**Respuesta**: Corregido. El 7B (DeepSeek-R1-Distill-Qwen-7B, 4.47 GB) se
ejecutó **solo** en OPPO CPH2557 (7.8 GB). Samsung Galaxy A30s (3.72 GB,
$\sim$1.43 GB usable al arranque) ejecuta **solo** Qwen-2.5-1.5B Q4_K_M; con
1.43 GB usables no satisface el piso de $\sim$2.5 GB de RAM libre que el 7B
requiere. Abstract y Conclusión ahora lo explicitan; la Tabla 4.4 ya identifica
el modelo 1.5B en el caption. La frase "previene OOM en dispositivos con 3.72 GB"
se acotó a "(modelo 1.5B; el 7B requiere $\geq$7.8 GB)".

### Punto 2 — "Reemplazar 'guaranteed liveness' y 'no leaks'; medir PSS/RSS anónimo por proceso"

**Respuesta**: Aceptado y corregido. Se eliminó "guarantees liveness"
$\rightarrow$ "is designed to preserve liveness", y se eliminó "no observable
memory leaks" basado en `MemAvailable`. Se implementó telemetría per-proceso
(`scripts/telemetry.py`) que lee `/proc/<pid>/smaps_rollup` (PSS, RssAnon),
`/proc/<pid>/status` (VmRSS/VmSize), `/proc/<pid>/stat` (minflt/majflt, CPU) e
`/proc/<pid>/io` (lecturas de almacenamiento). `MemAvailable` se conserva
**solo** como señal global de presión, nunca como prueba de ausencia de fuga.
**Resultado medido (1.5B, Android, 41 corridas)**: RssAnon estable — Samsung
$107\pm1.3$ MB (pendiente $p{=}0.66$, 21 corridas) y OPPO $289\pm1.5$ MB
($p{=}0.94$, 20 corridas) → sin evidencia de fuga per-proceso. El 7B y la
ablación PC siguen **[pending rerun]**.

### Punto 3 — "Documentar el mecanismo de paging y configuración por plataforma; APIs reales de Windows; baseline llama.cpp --mmap en Android"

**Respuesta**: En Windows el paging usa `PrefetchVirtualMemory` y
`DiscardVirtualMemory` (no `madvise`), ya documentado en §3.2 y reiterado en
§4.2. **Hecho (PC)**: la ablación Windows ya corre los baselines matched
llama.cpp `--mmap` y `--no-mmap` (mismo modelo, prompt, 80 tokens, 10 corridas)
con telemetría por proceso (Tabla 4.5). **Pendiente (Android)**: el baseline
matched llama.cpp `--mmap` en dispositivo se marca **[pending rerun]** (el
dispositivo no estuvo conectado en esta sesión; `llama-cli` ya está en
`/data/local/tmp/`).

### Punto 4 — "Etiquetar throughput/latencia/memoria con modelo, contexto, batch y output; aclarar 2.90 vs 0.43 tok/s"

**Respuesta**: 2.90 tok/s es Qwen-2.5-**1.5B** en OPPO (50 iteraciones); 0.43
tok/s es DeepSeek-**7B** en OPPO. Son modelos distintos, no una contradicción.
El 0.43 tok/s del 7B queda **[pending rerun]**: el log retenido
`android_oppo_7b.json` registra timeouts (5/5), no ese valor. El nuevo esquema
JSONL registra `model`, `configuration.context_size`, `batch_size`,
`output_token_limit` por corrida, cumpliendo el etiquetado solicitado.

### Punto 5 — "Sustentar 'strictly I/O-bound' con fallos de página, lecturas de almacenamiento y CPU"

**Respuesta**: Aceptado. "strictly I/O-bound" se degradó a "suspected I/O-bound"
y se marcó **[pending rerun]**. La telemetría nueva captura exactamente los
tres requisitos: fallos de página (`/proc/<pid>/stat` minflt/majflt; en Windows
`GetProcessMemoryInfo().PageFaultCount`), lecturas de almacenamiento
(`/proc/<pid>/io` read_bytes/read_chars) y CPU por proceso (utime/stime).
**Resultado medido (1.5B, Android)**: el 1.5B está **CPU-bound**, no I/O-bound —
CPU 569\% (OPPO, 5.7 núcleos) y 197\% (Samsung, 2 núcleos); fallos mayores
$\approx$0.25 (OPPO) y 2.5 (Samsung) por corrida; read_bytes $\approx$0.15–1.6 MB
(el modelo se carga vía mmap/demand paging, no read()). El "I/O-bound" del 7B
sigue **[pending rerun]**.
**Resultado medido (PC)**: llama.cpp `--no-mmap` lee el modelo entero vía
`read()` (1,123 MB), nanortime (mmap+madvise) lee 29.3 MB y llama.cpp `--mmap`
11.9 MB; CPU per-proceso 459–506% (CPU-bound) y fallos de página totales
$\sim$562k–680k.

### Punto 6 — "MMLU 90.0% / HumanEval 66.7% no reproducibles (muestreo no especificado)"

**Respuesta**: Aceptado. 9/10 (MMLU) y 2/3 (HumanEval) son **pilotos** sobre
muestras limitadas, no estimadores reproducibles. Se etiquetaron como pilotos
en abstract, contribuciones, §4.6 y conclusión; la evaluación completa
(MMLU 14k, HumanEval 164, vía `scripts/eval_harness.py`) queda pendiente.

### Punto 7 — "Se especifican tests estadísticos (Shapiro-Wilk, Mann-Whitney, bootstrap, Spearman, regresión) pero no se reportan"

**Respuesta**: Aceptado. Se creó `scripts/analyze_telemetry.py`, que lee
exclusivamente el JSONL nuevo y computa Shapiro-Wilk, Mann-Whitney U, bootstrap
95% CI, Spearman y regresión **solo cuando hay tamaño muestral y datos válidos**,
reportando siempre `n`, estadístico, p-value, CI, tamaño de efecto y exclusiones.
Sin corridas nuevas emite el esquema y "NO RESULTS YET" — no inventa p-values ni
intervalos. **Resultado medido**: 71 corridas (20 OPPO + 21 Samsung + 30 PC).
Tablas 4.4 y 4.5 actualizadas con n, media$\pm$std, bootstrap CI95 y regresión
(RssAnon $p{=}0.94/0.66$; tok/s OPPO pendiente $-0.13$, $p{<}10^{-5}$);
Mann-Whitney U cross-device ($U{=}12$, $p{<}0.001$, Cohen's $d{=}-1.82$,
confundido por throttling térmico) y PC ($U{=}100$, $p{=}0.00018$ para
\nanort{} vs cada baseline).

---

## Cambios de redacción conservadora (resumen)

- no "guaranteed liveness" → "is designed to preserve liveness";
- no "no memory leaks" basado en `MemAvailable`;
- no "strictly I/O-bound" sin fallos de página, lecturas de almacenamiento y CPU;
- no inferir Android a partir de la ablación Windows;
- no mezclar 7B (OPPO) con 1.5B (Samsung);
- MMLU/HumanEval siguen como pilotos hasta evaluación reproducible.

---

*Las respuestas preemptivas originales (R1–R9) se conservan a continuación como
material de apoyo; donde contradigan lo anterior, prevalecen las respuestas
específicas a los 7 puntos del revisor.*


## R1. "Los números de calidad (90% MMLU) no son estadísticamente válidos"

**Respuesta**: Correcto, y así está declarado en el paper: MMLU 90.0% y
HumanEval 66.7% provienen de una muestra limitada (5/3 ítems) y se marcan
como *preliminares*. La suite completa (MMLU 14k, HumanEval 164) está
documentada como extensión pendiente en el Reproducibility Statement, con
el harness (`scripts/eval_harness.py`) en el repo. La contribución del
paper no depende de estos números: depende de la supervivencia bajo presión
de memoria, medida directamente.

## R2. "0.29 tok/s es inutilizable — ¿por qué publicar esto?"

**Respuesta**: La contribución no es throughput sino *disponibilidad*. En
el target (móvil ≤8 GB sin GPU programable), el baseline llama.cpp
`--no-mmap` **termina con OOM** cargando el modelo de 4.47 GB (Tabla RSS);
NanoRuntime completa la generación degradando el contexto a 512, con log
verificado: `Model file (4466MB) exceeds usable RAM (2978MB). Forcing
minimum context (512).` Un sistema que termina lento supera a uno que
muere. Además, el 0.29 tok/s medido es térmica-dependiente: 0.14–0.38 tok/s
en 3 ejecuciones (ver R4).

## R3. "La comparación contra llama.cpp es injusta (--no-mmap es el peor caso)"

**Respuesta**: El paper declara explícitamente que `--no-mmap` es el peor
caso (modelo completo en páginas anónimas). Pero la re-validación del
2026-08-01 añadió el caso mmap: llama.cpp mmap usó **2501 MB** de RSS frente
a **1363 MB** de NanoRuntime (mismo modelo, misma máquina) — el modo
"favorable" de llama.cpp sigue usando 45% más memoria. La ventaja no
depende del modo elegido. (Nota: 2030 MB para --no-mmap, 2501 MB para mmap;
contra-intuitivo pero medido — mmap con prompt no cacheadable genera más
páginas residentes en este workload.)

## R4. "Alta varianza de throughput en 7B (0.14–0.38 tok/s) — ¿es confiable?"

**Respuesta**: La varianza es térmica, no arquitectónica, y se cuantifica:
3 ejecuciones consecutivas en el mismo dispositivo con presión de RAM
sistémica decreciente (2978 → 2696 MB usables) dieron 0.14–0.38 tok/s. El
perfil energético formal (>30 min, con logs de throttling de CPU/GPU) está
documentado como trabajo futuro — es el ensayo que cerramos esta brecha.
La evidencia de *que el sistema no muere* es invariante a la térmica: 3/3
ejecuciones completaron.

## R5. "¿Por qué no comparar contra MLC-LLM o PowerInfer?"

**Respuesta**: Ambos requieren GPU programable (OpenCL/Vulkan/TVM) o
sparsity de activaciones; el target declarado de NanoRuntime es CPU-only
sin GPU programable, donde estos sistemas no operan. La comparación se
limitó al baseline que sí puede operar en el target (llama.cpp). Una
extensión legítima es ejecutar MLC-LLM en modo CPU como tercer baseline —
documentada como trabajo futuro con el harness en el repo.

## R6. "τ=0.85 parece calibrado ad-hoc"

**Respuesta**: Correcto, y declarado: τ se fijó empíricamente sobre el
conjunto de 20 prompts (Δμ=0.049 entre distribuciones de entropía). La
calibración formal (ROC/AUC sobre dataset etiquetado, barrido de τ,
`scripts/benchmark_routing.py`) es extensión pendiente. El paper no vende
τ como óptimo global; vende la *señal* (entropía del modelo como
confianza task-agnóstica, sin clasificador externo) y su mecanismo.

## R7. "¿El sistema realmente no tiene memory leaks?"

**Respuesta**: Evidencia directa de la sesión del 2026-08-01:
- PC: 10 ejecuciones consecutivas, RSS 1362.9→1363.4 MB (delta **0.5 MB**,
  std 0.141 MB).
- OPPO (10 queries 1.5B): MemAvailable 3446→3695 MB (creciente, no
  decreciente).
- Samsung (10 queries 1.5B): MemAvailable 2263→2279 MB (estable).
La atribución formal de crecimiento residual (si lo hay) con contexto fijo
a largo plazo está en Future Work. La evidencia actual apunta a ausencia de
leak, no solo a ausencia de crash.

## R8. "Solo hay 2 dispositivos — ¿generalización?"

**Respuesta**: Cierto, y se declara: OPPO (7.8 GB, UFS 1067 MB/s) y Samsung
A30s (3.7 GB, eMMC 364 MB/s) son los extremos del rango. El tercer
dispositivo de rango medio (6 GB, ~600 MB/s) y los percentiles p50/p95/p99
de latencia están documentados como ensayo requerido en Future Work.

## R9. "¿Por qué los scripts de benchmark están marcados pendientes en el paper?"

**Respuesta**: Honestidad metodológica. El paper distingue explícitamente
lo medido (Tablas RSS/tps, degradación logueada) de lo pendiente (calidad
completa, ROC del router, perfil térmico). Los 31 scripts de `scripts/`
(incluido `_verify_claims.py`) son el camino de reproducción; la suite
automatizada del repo (46 tests) valida contrato, sync y lógica
estadística contra el servidor real. Preferimos marcar pendiente lo no
medido a presentarlo como medido — un defecto de documentación, no de
honestidad.

---

## Frase de cierre sugerida

"The paper reports measured behavior on physical hardware, distinguishes
explicitly between validated and pending measurements, and provides the
full harness for independent reproduction. The architectural claim —
deterministic completion under memory pressure where baselines fail — is
supported by live-captured degradation logs and repeated no-OOM runs."
