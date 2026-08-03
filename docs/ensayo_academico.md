# Ensayo Académico — La contribución de NanoRuntime

*Documento de argumentación técnica en estilo MLSys/USENIX ATC. No contiene
datos nuevos: usa exclusivamente las mediciones verificadas de la sesión del
2026-08-01 y los artefactos del repo.*

---

## 1. La tesis en una frase

En el dominio de dispositivos móviles de consumo, la disponibilidad
determinista (no morir por OOM) es un requisito de primer orden que los
baselines de inferencia no satisfacen; NanoRuntime lo convierte en una
propiedad de diseño explícita — y lo demuestra físicamente.

## 2. El problema de sistemas que nadie resuelve de frente

Los sistemas de inferencia on-device se optimizan para el régimen "cómodo":
GPU programable (MLC-LLM/TVM), VRAM suficiente (vLLM), o memoria unificada
amplia (LLM-in-a-Flash). El régimen "hostil" — un SoC mid-range sin GPU
programable, 3.7–8 GB de RAM, almacenamiento eMMC/UFS — queda desatendido
por tres razones de arquitectura:

1. **vLLM (PagedAttention, SOSP'23)** paga la fragmentación de KV-cache para
   maximizar throughput en lote sobre NVIDIA CUDA. Sin CUDA no aplica; y su
   modelo de fallo ante presión de memoria es el error, no la degradación.
2. **llama.cpp (mmap)** delega la residencia al page cache del kernel. Bajo
   presión, Android evicta las páginas del modelo durante la generación →
   page faults que cuelgan la generación, o directamente OOM-kill. El dato
   empírico: en el OPPO de 7.8 GB, el baseline `--no-mmap` termina con OOM
   cargando un modelo de 4.47 GB.
3. **MLC-LLM (TVM)** asume GPU móvil programable; el target "CPU-only
   ≤4 GB" queda fuera de su espacio de diseño.

NanoRuntime no compite con ninguno de los tres: opera en el punto de
operación que ellos no cubren, con una restricción explícita: *liveness
primero, throughput después*.

## 3. Los tres mecanismos y su evidencia

### 3.1 Residencia explícita vs page cache implícito

En lugar de `mmap` completo (que deja la decisión de residencia al kernel),
`OSMemoryPaginator` + `WeightCacheAware` emiten `madvise` por ventana de
capas: `WILLNEED`/`SEQUENTIAL` en la ventana activa, `COLD`/`PAGEOUT` en
tokens KV fríos, `DONTNEED` en páginas evictables. Esto convierte la
residencia en una variable controlable del sistema, no un accidente del
scheduler de memoria.

*Evidencia de la sesión*: RSS del proceso 7B en OPPO = 3.46–3.53 GB
(sustentando un modelo de 4.47 GB con contexto mínimo 512), sin OOM en
3 ejecuciones consecutivas con presión creciente del sistema (2978 → 2696 MB
de RAM usable). En PC, RSS = 1363 MB frente a 2030–2501 MB de llama.cpp
(mismo modelo, misma máquina): reducción del 33–45%.

### 3.2 Degradación adaptativa síncrona con /proc/meminfo

`AdaptiveScheduler` consulta `MemAvailable` antes de cada forward pass;
si la RAM libre cruza el umbral (15% del total), recorta KV por pasos de
25% hasta el mínimo viable (512 tokens), o devuelve `ContextTooSmall`.

*Evidencia (log real capturado en la sesión)*:
```
WARN Model file (4466MB) exceeds usable RAM (2978MB). Forcing minimum context (512).
[METRICS] tokens=32 elapsed_ms=222046 tok_s=0.14 tier=local confidence=0.853
```
La generación completó con contexto 512. El mecanismo no es una promesa de
diseño: está en el log del dispositivo físico. Es el análogo móvil del
*admission control* de los sistemas de servidor, aplicado a la memoria.

### 3.3 Routing por entropía del modelo

La señal de confianza es la entropía normalizada de los propios logits
(`c = 1 − H_norm`, τ=0.85), no un clasificador externo ni reglas de prompt.
Task-agnóstico: el modelo mide su propia incertidumbre. Con filtro PII regex
obligatorio antes de cualquier escalado a cloud.

## 4. El trade-off que define el sistema

| Eje | NanoRuntime | Baselines GPU-first |
|---|---|---|
| Criterio de éxito | Completar bajo presión de memoria | Throughput bajo carga |
| Modo de fallo | Contexto reducido, generación lenta pero completa | Error/OOM |
| Target | CPU móvil ≤4–8 GB | GPU (VRAM/unified memory) |
| Latencia | 0.14–0.38 tok/s (7B térmica-dependiente) | 10–100+ tok/s |

El coste es real y medido: 7B en CPU móvil rinde 0.14–0.38 tok/s (3.23/2.52
tok/s con 1.5B), inviable para chat interactivo. La defensa es de sistemas:
en el dominio target, *un modelo que termina en 5 minutos vale más que un
modelo que muere en 1 segundo*. Es la misma lógica que justificó el
swap/suspend en los sistemas operativos de los años 70, trasladada a la
inferencia.

## 5. Por qué la evidencia de esta sesión fortalece el caso

1. **La "varianza <1 MB" resultó cierta**: delta 0.5 MB de RSS en 10 runs
   consecutivos PC, y MemAvailable estable o creciente en 10 queries
   consecutivas en ambos teléfonos. El paper lo afirmaba sin log; ahora
   existe el log.
2. **El baseline medido es más favorable a NanoRuntime de lo que el paper
   creía**: 2030–2501 MB de llama.cpp vs 1363 MB de NanoRuntime (−33/−45%),
   no "paridad 1.84 vs 1.85".
3. **La degradación se capturó en vivo con su línea de log** — reproducible
   y citable en la sección de evaluación.

## 6. Límites que un reviewer marcaría (declarados)

- MMLU 90.0%/HumanEval 66.7% sobre 5/3 muestras — estadísticamente inválido
  como claim de calidad; se declara como preliminar.
- La variabilidad térmica del 7B (0.14–0.38 tok/s) requiere perfil
  energético formal (30+ min sostenido) para separar throttling de diseño.
- La comparación justa contra MLC-LLM/PowerInfer en el mismo target
  (CPU-only) no se ejecutó — solo contra llama.cpp.
- El routing no tiene ROC/AUC ni dataset de calibración publicado.

## 7. Conclusión argumentativa

NanoRuntime plantea una hipótesis falsable: *"en dispositivos ≤8 GB sin GPU
programable, controlar explícitamente la residencia de memoria permite
ejecutar modelos que los baselines no pueden, a costa de throughput"*. Las
tres ejecuciones 7B en OPPO (supervivencia con degradación a 512) y la
medición RSS en PC (1363 vs 2030–2501 MB) son evidencia directa a favor.
Las objeciones esperables (calidad preliminar, variabilidad térmica,
ausencia de A/B contra MLC-LLM) son debilidades de *validación*, no de
*tests de diseño*: se responden con ensayos, no con rediseño.
