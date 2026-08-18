# Benchmark MNN — OPPO CPH2557

Estado: **BLOCKED** (no es deuda P0, es R&D/V2).

## Setup completado

```text
MNN clonado + llm_demo compilado para Android arm64 (CPU+OpenCL+Vulkan,
transformer fuse, low memory) — versiones master y 3.3.0 probadas.
Modelo preconvertido taobao-mnn/Qwen2.5-0.5B-Instruct-MNN descargado
(553 MB) y desplegado al OPPO.
```

## Bloqueo

El runtime aborta en `llm->load()`:

```text
out_of_range was thrown in -fno-exceptions mode with message
"unordered_map::at: key not found"
```

## Causa raíz

El runtime MNN (`Tokenizer::createTokenizer`) solo soporta **SentencePiece**
y **Tiktoken**. El `tokenizer.txt` del artefacto preconvertido tiene formato
**llama.cpp GGUF**:

```text
430 3
22 2 0
151643 151644 ...
```

MNN intenta parsearlo como SentencePiece, el parseo descarrila y falla. Es un
mismatch del **artefacto del modelo**, no de la versión del runtime — falla
idéntico en `master` y en `3.3.0` (donde `tie_embeddings` ya es opcional).

## Siguiente paso (cuando se retome)

```text
re-exportar HF con llmexport versión fija (genera tokenizer SentencePiece)
o obtener artefacto ModelScope compatible
+ guardar MnnModelManifest { mnn_version, exporter_version, tokenizer_format, hashes }
```

## Veredicto

```text
MNN_GO = UNKNOWN (no medido — bloqueado antes del benchmark)
```

No se declara ganador ni perdedor. Queda documentado para retomar sin repetir
el setup.
