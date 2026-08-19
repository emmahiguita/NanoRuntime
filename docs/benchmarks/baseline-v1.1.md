# Baseline oficial — NanoRuntime v1.1.0

Resultados medidos en hardware real (OPPO CPH2557). **Estos números son
activos del proyecto y no se modifican retrospectivamente.** Cada versión
futura se compara contra ellos.

## Dispositivo

```text
Modelo:  OPPO CPH2557
SoC:     MediaTek MT6833 (Dimensity 6100+)
GPU:     Mali-G57 MC2 (matrix cores: none, 32KB shared)
RAM:     7.8 GB total, ~3.2 GB libre
ISA:     NEON + DOTPROD (sin SME/SME2)
```

## Rendimiento por modelo (CPU, 4 threads)

| Modelo | Cuant | Decode tok/s | Veredicto |
|--------|-------|--------------|-----------|
| Qwen2.5-1.5B | Q8_0 | 5.4 (cold) | ✅ interactivo |
| Qwen2.5-1.5B | Q4_K_M | 4.2 (sustained) | ✅ interactivo (menos calor) |
| Qwen 9B | Q4_K_M | 0.31 (sustained) | ❌ NON-INTERACTIVE |
| Qwen 27B | — | — | ❌ no cabe (thrashing) |

## Backends

| Backend | Resultado | Veredicto |
|---------|-----------|-----------|
| llama.cpp CPU | 4.2–5.4 tok/s (1.5B) | ✅ PRODUCTION |
| Vulkan (Mali-G57) | ≤ 2.52 tok/s, prefill 12s vs 1s | ❌ NO-GO (GPU overhead domina) |
| MNN | — | ⏸ UNVALIDATED (tokenizer GGUF vs SentencePiece incompatible) |
| NPU/QNN | — | 🔜 no detectado |

## Evidencia complementaria

- `docs/benchmarks/oppo-cph2557-vulkan.md` — benchmark Vulkan detallado.
- `docs/benchmarks/oppo-cph2557-recovery.md` — batería de recovery (A–F).
- `docs/benchmarks/oppo-cph2557-mnn.md` — bloqueo MNN documentado.

## Regla de comparación

```text
Ninguna optimización futura cambia estos números.
v1.2+ se mide CONTRA ellos: la ganancia es relativa al baseline.
```

## El aporte técnico

NanoRuntime no intenta ejecutar siempre el modelo/backend más grande; intenta
seleccionar la ejecución más útil que el dispositivo puede sostener realmente:

```text
"Vulkan está disponible"           → cualquier runtime
"Vulkan existe, lo medí, CPU es 1.65× más rápido, no lo usaré"  → NanoRuntime
```
