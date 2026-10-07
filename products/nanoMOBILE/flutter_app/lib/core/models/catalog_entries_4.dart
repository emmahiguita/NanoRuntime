part of 'catalog_models.dart';

// Catálogo GenAI 2026: modelos móviles verificados de LiteRT Community y Unsloth.
// Incluye artefactos descargables con SHA256 inmutable de Hugging Face.
const _catalogEntries4 = <LmCatalogEntry>[
  // Qwen3.5-0.8B LiteRT: chat principal ultra-eficiente con soporte multi-turn.
  LmCatalogEntry(
    'Qwen3.5-0.8B-Instruct (LiteRT)',
    '0.8B',
    'INT8',
    0.90,
    1.2,
    'Qwen3.5-0.8B_int8.litertlm',
    'https://huggingface.co/litert-community/Qwen3.5-0.8B/resolve/main/Qwen3.5-0.8B_int8.litertlm',
    '64ed396fcdae75e5158945c77a08142b1322ce1bbf1be4d2198783119a1169e8',
    template: ChatTemplate.qwen,
    tier: ModelTier.interactive,
    backendType: ModelBackendType.litertlm,
  ),

  // Qwen3.5-0.8B-VL: visión multimodal móvil compacta (1.21 GB).
  LmCatalogEntry(
    'Qwen3.5-0.8B-VL (LiteRT Visión)',
    '0.8B',
    'INT8-VL',
    1.21,
    1.8,
    'Qwen3.5-0.8B-VL_int8.litertlm',
    'https://huggingface.co/litert-community/Qwen3.5-0.8B/resolve/main/Qwen3.5-0.8B-VL_int8.litertlm',
    'e3360b658c929ff35ab740a21f5e4b688096a72e351b8d347e26ccda314121b7',
    template: ChatTemplate.qwen,
    tier: ModelTier.deep,
    kind: ModelKind.multimodalVision,
    backendType: ModelBackendType.litertlm,
  ),

  // LFM2.5-1.2B-Instruct GPU: ejecución acelerada por OpenCL / GPU en Android.
  LmCatalogEntry(
    'LFM2.5-1.2B-Instruct GPU (LiteRT)',
    '1.2B',
    'INT4-GPU',
    0.69,
    1.3,
    'LFM2.5-1.2B-Instruct_int4_gpu.litertlm',
    'https://huggingface.co/litert-community/LFM2.5-1.2B-Instruct/resolve/main/LFM2.5-1.2B-Instruct_int4_gpu.litertlm',
    '97e6a9700208f59fce2ceb993cd6c18ea77ada8c2a940f68332004f38a404671',
    template: ChatTemplate.qwen,
    tier: ModelTier.interactive,
    backendType: ModelBackendType.litertlm,
  ),

  // MiniCPM5-2B: razonamiento profundo móvil en 1.45 GB.
  LmCatalogEntry(
    'MiniCPM5-2B-Instruct (LiteRT)',
    '2.0B',
    'INT4',
    1.45,
    2.2,
    'MiniCPM5-2B_int4.litertlm',
    'https://huggingface.co/litert-community/MiniCPM5-2B/resolve/main/MiniCPM5-2B_int4.litertlm',
    '9858563beafbc6d5e0d25fcee3827541515296a9302ed3d088b16a58d4fbe7b8',
    template: ChatTemplate.qwen,
    tier: ModelTier.deep,
    backendType: ModelBackendType.litertlm,
  ),

  // EmbeddingGemma 2 Text: 165 MB para búsqueda semántica local sin saturar RAM.
  LmCatalogEntry(
    'EmbeddingGemma-2-Text-270M (LiteRT)',
    '270M',
    'FP16/INT8',
    0.16,
    0.4,
    'embeddinggemma-2-text-270m.litertlm',
    'https://huggingface.co/litert-community/embeddinggemma-2-text-270m-litert-lm/resolve/main/embeddinggemma-2-text-270m.litertlm',
    '2d079ee2f6f066b1f368e8d7c819f55214eaef1d0513b312321901f30ab286fb',
    template: ChatTemplate.gemma,
    tier: ModelTier.interactive,
    backendType: ModelBackendType.litertlm,
  ),

  // EmbeddingGemma 2 Omni: espacio semántico compartido texto/imagen/audio.
  LmCatalogEntry(
    'EmbeddingGemma-2-740M-Omni (LiteRT)',
    '740M',
    'FP16/INT8',
    0.45,
    0.9,
    'embeddinggemma-2-740m.litertlm',
    'https://huggingface.co/litert-community/embeddinggemma-2-740m-litert-lm/resolve/main/embeddinggemma-2-740m.litertlm',
    'e7a8a2204b91e0f96e92960e84a09a89212e1633dcb7575a9bf3378b4df77f4c',
    template: ChatTemplate.gemma,
    tier: ModelTier.interactive,
    backendType: ModelBackendType.litertlm,
  ),

  // Moonshine Tiny: STT ultraligero de 52 MB para notas de voz breves.
  LmCatalogEntry(
    'Moonshine-Tiny (Voz Local LiteRT)',
    '27M',
    'INT8',
    0.05,
    0.15,
    'moonshine_tiny_5s_i8.tflite',
    'https://huggingface.co/litert-community/Moonshine-Tiny/resolve/main/moonshine_tiny_5s_i8.tflite',
    '97abdeea122d579229091659c24c59d988c6419d453a200f6471241a53b9a9b9',
    kind: ModelKind.voiceStt,
    tier: ModelTier.interactive,
    backendType: ModelBackendType.litertlm,
  ),

  // Qwen3.5-0.8B GGUF: formato nativo llama.cpp balanceado (532 MB).
  LmCatalogEntry(
    'Qwen3.5-0.8B-Instruct (GGUF Q4_K_M)',
    '0.8B',
    'Q4_K_M',
    0.50,
    0.85,
    'Qwen3.5-0.8B-Q4_K_M.gguf',
    'https://huggingface.co/unsloth/Qwen3.5-0.8B-GGUF/resolve/main/Qwen3.5-0.8B-Q4_K_M.gguf',
    'bd258782e35f7f458f8aced1adc053e6e92e89bc735ba3be89d38a06121dc517',
    template: ChatTemplate.qwen,
    tier: ModelTier.interactive,
    backendType: ModelBackendType.gguf,
  ),

  // Qwen3.5-2B GGUF: alta calidad conversacional en CPU ARM (1.28 GB).
  LmCatalogEntry(
    'Qwen3.5-2B-Instruct (GGUF Q4_K_M)',
    '2.0B',
    'Q4_K_M',
    1.20,
    1.9,
    'Qwen3.5-2B-Q4_K_M.gguf',
    'https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/main/Qwen3.5-2B-Q4_K_M.gguf',
    'aaf42c8b7c3cab2bf3d69c355048d4a0ee9973d48f16c731c0520ee914699223',
    template: ChatTemplate.qwen,
    tier: ModelTier.deep,
    backendType: ModelBackendType.gguf,
  ),
];
