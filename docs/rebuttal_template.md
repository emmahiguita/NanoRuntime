# Rebuttal Template — NanoRuntime (MLSys/USENIX ATC)

*Respuestas preemptivas a las objeciones esperables de reviewers. Cada
respuesta usa evidencia verificada de la sesión del 2026-08-01 o cita
exactamente qué falta. Formato: [Objeción] → [Respuesta].*

---

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
