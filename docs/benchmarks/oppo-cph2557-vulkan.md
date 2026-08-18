# Benchmark Vulkan — OPPO CPH2557

Evidencia de la tesis: **backend disponible ≠ backend útil**. El planner debe
distinguir "soporta Vulkan" de "Vulkan vale la pena en este dispositivo".

## Dispositivo

| Campo | Valor |
|-------|-------|
| Modelo | OPPO CPH2557 |
| SoC | MediaTek MT6833 (Dimensity 6100+) |
| GPU | Mali-G57 MC2 |
| Vulkan | 1.3.275 (driver MediaTek) |
| GPU heap | ~246 MB |
| RAM | 7.8 GB total, ~3.2 GB libre |

Características reportadas por llama.cpp (`ggml_vulkan`):

```text
Mali-G57 MC2 | uma: 1 | fp16: 1 | bf16: 0 | fp4: 0
warp size: 16 | shared memory: 32768 (32 KB)
int dot: 1 | matrix cores: none
```

Sin matrix cores, sin bf16/fp4, 32 KB de shared memory: GPU de gama baja.

## Benchmark — Qwen 1.5B (Q4_K_M, mismo GGUF, mismo prompt, n_ctx 4096)

| Métrica | CPU | Vulkan (gpu_layers=99) |
|---------|-----|-------------------------|
| decode_tok_s | **4.17** | 0.73 – 2.52 |
| prefill_ms | ~1 s | **11.5 – 12 s** |
| capas offload | 0 (todo CPU) | 28/28 → Vulkan0 |

El offload funcionó (28/28 capas a `Vulkan0`), pero ambas fases regresaron:
- decode: 0.73–2.52 vs 4.17 tok/s (Vulkan más lento).
- prefill: ~12 s para ~19 tokens de prompt vs ~1 s en CPU (12× más lento).

## Veredicto

```text
VULKAN_GO = false
```

Razón: el overhead de transferencias y kernel launches domina sobre el
compute en esta GPU. El modelo pequeño no amortiza el coste de Vulkan.

## Conclusión para el planner

Vulkan es **capacity opcional, no ruta activa**. En este device:

```text
Vulkan disponible: sí
Vulkan recomendado: no (más lento que CPU)
```

En un Snapdragon/Adreno (o Mali de gama alta con matrix cores) el resultado
podría invertirse. La decisión es por hardware real, no universal.

## Setup del build (reproducible)

```text
SDK Vulkan 1.4.357 (glslc)
SPIRV-Headers v1.3.275 en sysroot del NDK
MinGW gcc (host compiler para vulkan-shaders-gen)
headers vulkan.hpp 1.3.275 (matchea vulkan.h del NDK)
API level 28 (vkGetPhysicalDeviceFeatures2)
feature: --features static-stdcxx,vulkan
CARGO_TARGET_DIR corto (paths < 260 chars de Windows)
```

## Siguiente candidato

MNN (runtime completo CPU/OpenCL/Vulkan para Mali). Gate: decode ≥ 1.5×
llama.cpp CPU (6.25 tok/s) o misma velocidad con menor RAM/thermal.
