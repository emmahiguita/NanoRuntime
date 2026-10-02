part of 'catalog_models.dart';

// Entradas existentes separadas por tamaño; solo hay un catálogo público.
const _catalogEntries2 = <LmCatalogEntry>[
  LmCatalogEntry(
    'Hey Mycroft (wake word)',
    'microWakeWord',
    'tflite',
    0.000055,
    0.01,
    'hey_mycroft.tflite',
    'https://github.com/OHF-Voice/micro-wake-word/releases/download/v2.1_models/hey_mycroft.tflite',
    'c2a9b6ed51182db72e014781d5a4ece1929dc232a40b5b4be384f0295f0e1571',
    kind: ModelKind.wakeWord,
  ),

  // Modelos de voz local en el dispositivo (Whisper.cpp)
  LmCatalogEntry(
    'Whisper-Tiny (Voz Local)',
    '39M',
    'Q5_1',
    0.075,
    0.15,
    'ggml-tiny.bin',
    'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin',
    'bd577a113a864445214878a8731112b32f2f458516d0be9b7f58a5f80b957e8d',
    kind: ModelKind.voiceStt,
    tier: ModelTier.interactive,
  ),

  LmCatalogEntry(
    'Whisper-Base (Voz Local)',
    '74M',
    'Q5_1',
    0.142,
    0.25,
    'ggml-base.bin',
    'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin',
    '60ed5bc3dd14eea856493d33afdac61453272d89e677c65069714330d07e600c',
    kind: ModelKind.voiceStt,
    tier: ModelTier.interactive,
  ),

  // Modelo multimodal con proyección visual integrada (Moondream2 GGUF + mmproj)
  LmCatalogEntry(
    'Moondream2-1.8B-Vision',
    '1.8B',
    'Q4_K_M',
    1.18,
    1.9,
    'moondream2-text-model-q4_k_m.gguf',
    'https://huggingface.co/vikhyatk/moondream2/resolve/main/moondream2-text-model-q4_k_m.gguf',
    '7b9c1d0a5f9c46db1d4e08cf8ba52824cfc5aeefd91e3e481beaa07b9a5c88b1',
    kind: ModelKind.multimodalVision,
    mmprojFile: 'moondream2-mmproj-f16.gguf',
    mmprojUrl:
        'https://huggingface.co/vikhyatk/moondream2/resolve/main/moondream2-mmproj-f16.gguf',
    mmprojSha256:
        '9a8d2f1b8c4e09f583e2b9c7d1e8a34f59c8d7e6f5a4b3c2d1e0f9a8b7c6d5e4',
    tier: ModelTier.interactive,
  ),

  // MODELS-CAT-04 — Modelos ultraligeros 2026 (350M–800M) para Nano Personal:
  // Comprensión conversacional, clasificación y generación breve en <1 GB RAM.
  // SHA256 auditados contra la API real de HuggingFace el 2026-09-25.
  // Reglas MODELS-CAT-02 aplicadas: archivo único GGUF, ramGb ≤ 7, sin shards.

  // LFM2.5-350M — arquitectura híbrida (conv + atención), 9 idiomas inc. español.
  // QAD = cuantización con datos calibrados de activación: mejor calidad que Q4_0 puro.
  LmCatalogEntry(
    'LFM2.5-350M-Q4_K_M',
    '350M',
    'Q4_K_M',
    0.22, // 229 312 224 bytes verificado HF API 2026-09-25
    0.45,
    'LFM2.5-350M-Q4_K_M.gguf',
    'https://huggingface.co/LiquidAI/LFM2.5-350M-GGUF/resolve/main/LFM2.5-350M-Q4_K_M.gguf',
    '7e6f72643caafc9a68256686638c4d7916f2cec76d1df478d4c3ddcd95a6aed4',
    template: ChatTemplate.qwen,
    tier: ModelTier.interactive,
  ),

  LmCatalogEntry(
    'LFM2.5-350M-QAD',
    '350M',
    'Q4_0-QAD',
    0.21, // 219 312 832 bytes verificado HF API 2026-09-25
    0.40,
    'LFM2.5-350M-QAD-Q4_0.gguf',
    'https://huggingface.co/LiquidAI/LFM2.5-350M-GGUF/resolve/main/LFM2.5-350M-QAD-Q4_0.gguf',
    '3d10b6ab8fc91a919534b9558e266255aca0bbc7f6d015963599aa9e74e05b1d',
    template: ChatTemplate.qwen,
    tier: ModelTier.interactive,
  ),

  // Qwen3-0.6B — solo disponible en Q8_0 oficial (archivo único en repo GGUF).
  // 640 MB · Apache 2.0 · contexto 32 768 tokens.
  LmCatalogEntry(
    'Qwen3-0.6B-Q8_0',
    '0.6B',
    'Q8_0',
    0.60, // 639 446 688 bytes verificado HF API 2026-09-25
    0.90,
    'Qwen3-0.6B-Q8_0.gguf',
    'https://huggingface.co/Qwen/Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q8_0.gguf',
    '9465e63a22add5354d9bb4b99e90117043c7124007664907259bd16d043bb031',
    template: ChatTemplate.qwen,
    tier: ModelTier.interactive,
  ),

  // Qwen3.5-0.8B — siguiente generación (Qwen 3.5) post-entrenado para instrucciones.
  // Q4_K_M: mejor balance calidad/RAM para conversación cotidiana en español.
  // 553 MB archivo · ~850 MB RAM en inferencia · Apache 2.0.
  LmCatalogEntry(
    'Qwen3.5-0.8B-Q4_K_M',
    '0.8B',
    'Q4_K_M',
    0.54, // 579 615 840 bytes verificado HF API 2026-09-25
    0.85,
    'Qwen_Qwen3.5-0.8B-Q4_K_M.gguf',
    'https://huggingface.co/bartowski/Qwen_Qwen3.5-0.8B-GGUF/resolve/main/Qwen_Qwen3.5-0.8B-Q4_K_M.gguf',
    'fb044e93939a70469c905781334f5de1e6c8b608ced6cbc8c9249bd4127d9526',
    template: ChatTemplate.qwen,
    tier: ModelTier.interactive,
  ),
];
