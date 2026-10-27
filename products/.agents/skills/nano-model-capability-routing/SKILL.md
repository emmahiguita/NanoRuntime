---
name: nano-model-capability-routing
description: Audit and repair Nano Mobile model catalog capabilities, chat selection, and routing to GGUF, LiteRT-LM, MNN, or voice runtimes. Use when a listed model loads in the wrong backend, cannot answer, or its actual role is unclear.
---

# Nano model capability and routing

Keep model role, artifact format, backend, and UI selection consistent. A valid file hash proves artifact identity, not that its runtime supports the model's task.

## Workflow

1. Use the codebase graph first to trace the catalog entry through path resolution, selection UI, lifecycle service, adapter, and native runtime. Read the relevant sources before editing.
2. Classify each entry by task: generative chat, vision-capable generation, speech recognition, wake-word, or embeddings. Embedding models produce vectors; do not expose them as chat models. Do not route generic TFLite speech models through Whisper.cpp.
3. Resolve known paths from the exact catalog filename and use that same catalog entry for both capability checks and backend selection. Unknown custom GGUF paths may retain the documented GGUF fallback.
4. Keep specialized models out of chat selectors and reject invalid legacy selections at the runtime boundary with a visible engine failure reason. Route a specialized model only when its dedicated adapter exists; otherwise state that support is absent instead of simulating success.
5. Inspect installed files and active preferences separately from catalog metadata. Use sanitized, read-only device logs to verify initialization and inference; never print message bodies or treat RemoteInput acceptance as confirmed delivery.
6. Make the smallest change at the ownership layer, add comments for non-obvious routing rules, run formatter and static analysis, then build the app's actual product flavor. Do not run automated tests when the user has prohibited them.

## Proven Nano Mobile boundaries

- Chat inference is routed by `NeuralCatalog` metadata through `RuntimeEngineNotifier` and `RoutedLlmEngineClient` to llama.cpp, LiteRT-LM, or MNN.
- Whisper GGML is consumed by `WhisperSttService`; a `.tflite` file is not a Whisper model.
- EmbeddingGemma catalog entries are not generative chat models. Do not claim they power RAG until an embedding adapter and caller are wired.
- A successful inference on one installed model verifies only that model and that route. It does not prove every catalog artifact is installed or compatible.
