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
    'https://huggingface.co/litert-community/Qwen3.5-0.8B/resolve/ff11c109e8e56797cd1ee5befa856975bb465afc/Qwen3.5-0.8B_int8.litertlm',
    '25447e2550082aed6145bbc755ec4da5d535f98f6a0c386865fdae2ccb88aed1',
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
    'https://huggingface.co/litert-community/Qwen3.5-0.8B/resolve/ff11c109e8e56797cd1ee5befa856975bb465afc/Qwen3.5-0.8B-VL_int8.litertlm',
    '1ab56460263fe94fde5fec160363d3aacbae9c5ee3638121c11feb51e483e29d',
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
    'https://huggingface.co/litert-community/LFM2.5-1.2B-Instruct/resolve/73c3cabdcf10ca251c63c9707e52ee0f6a25ea17/LFM2.5-1.2B-Instruct_int4_gpu.litertlm',
    '8d3a4d73e121166ad377e9c51148d38ee383c223661f4219e01f22a0fe1d4a1a',
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
    'https://huggingface.co/litert-community/MiniCPM5-2B/resolve/af7706eff3e2ede7b02e67eabcdc7f881a3f0a0c/MiniCPM5-2B_int4.litertlm',
    '05b78bb57dd5ded8a76907cc953cbc57d6261ee9fa66fbfca21ae677a897da45',
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
    'https://huggingface.co/litert-community/embeddinggemma-2-text-270m-litert-lm/resolve/9be6e8b90982095dc05c2bd162e4b954ee4dbac7/embeddinggemma-2-text-270m.litertlm',
    '2d079ee2f6f066b1f368e8d7c819f55214eaef1d0513b312321901f30ab286fb',
    template: ChatTemplate.gemma,
    tier: ModelTier.interactive,
    kind: ModelKind.embedding,
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
    'https://huggingface.co/litert-community/embeddinggemma-2-740m-litert-lm/resolve/24d962e906c7d332c6428e71c9676855024569e2/embeddinggemma-2-740m.litertlm',
    'e7a8a2204b91e0f96e92960e84a09a89212e1633dcb7575a9bf3378b4df77f4c',
    template: ChatTemplate.gemma,
    tier: ModelTier.interactive,
    kind: ModelKind.embedding,
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
    'https://huggingface.co/litert-community/Moonshine-Tiny/resolve/eb73d789d7eebcd4d3d5f1a851692923a8e76763/moonshine_tiny_5s_i8.tflite',
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
    'https://huggingface.co/unsloth/Qwen3.5-0.8B-GGUF/resolve/6ab461498e2023f6e3c1baea90a8f0fe38ab64d0/Qwen3.5-0.8B-Q4_K_M.gguf',
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
    'https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/f6d5376be1edb4d416d56da11e5397a961aca8ae/Qwen3.5-2B-Q4_K_M.gguf',
    'aaf42c8b7c3cab2bf3d69c355048d4a0ee9973d48f16c731c0520ee914699223',
    template: ChatTemplate.qwen,
    tier: ModelTier.deep,
    backendType: ModelBackendType.gguf,
  ),
];
