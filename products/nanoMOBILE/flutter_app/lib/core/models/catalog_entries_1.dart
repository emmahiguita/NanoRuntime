part of 'catalog_models.dart';

// Entradas existentes separadas por tamaño; solo hay un catálogo público.
const _catalogEntries1 = <LmCatalogEntry>[
  LmCatalogEntry(
    'Gemma-3-1B-IT',
    '1B',
    'Q4_K_M',
    0.81,
    1.2,
    'gemma-3-1b-it-Q4_K_M.gguf',
    'https://huggingface.co/ggml-org/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q4_K_M.gguf',
    '8ccc5cd1f1b3602548715ae25a66ed73fd5dc68a210412eea643eb20eb75a135',
    template: ChatTemplate.gemma,
  ),

  LmCatalogEntry(
    'Gemma-3-1B-IT-Q8_0',
    '1B',
    'Q8_0',
    1.07,
    1.5,
    'gemma-3-1b-it-Q8_0.gguf',
    'https://huggingface.co/ggml-org/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q8_0.gguf',
    'b205840c5dcef55078e37d344677869a714ffd42a4ae448c48dcfb52e4bb10d5',
    template: ChatTemplate.gemma,
  ),

  LmCatalogEntry(
    'Llama-3.2-3B-Instruct',
    '3B',
    'Q4_K_M',
    2.02,
    2.6,
    'Llama-3.2-3B-Instruct-Q4_K_M.gguf',
    'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
    '6c1a2b41161032677be168d354123594c0e6e67d2b9227c84f296ad037c728ff',
    template: ChatTemplate.llama,
  ),

  LmCatalogEntry(
    'Qwen3-4B-Instruct-2507',
    '4B',
    'Q4_K_M',
    2.50,
    3.2,
    'Qwen3-4B-Instruct-2507-Q4_K_M.gguf',
    'https://huggingface.co/lmstudio-community/Qwen3-4B-Instruct-2507-GGUF/resolve/main/Qwen3-4B-Instruct-2507-Q4_K_M.gguf',
    '8cdb57cbb880d313736a9bc4e3d3d2485f145b5e19cf33783746e753e82641fc',
    template: ChatTemplate.qwen,
    tier: ModelTier.deep,
  ),

  LmCatalogEntry(
    'Ministral-3-3B-Instruct-2512',
    '3B',
    'Q4_K_M',
    2.15,
    2.8,
    'Ministral-3-3B-Instruct-2512-Q4_K_M.gguf',
    'https://huggingface.co/mistralai/Ministral-3-3B-Instruct-2512-GGUF/resolve/main/Ministral-3-3B-Instruct-2512-Q4_K_M.gguf',
    '9ed150d4367e68df0ac8e1540f6ddc65b42d0ee26378329d1ecbca60f93fc5f8',
    template: ChatTemplate.mistral,
    tier: ModelTier.deep,
  ),

  // MODELS-CAT-03 — Modelos multi-tier optimizados para móviles (1.2B a 2.6B):
  // Conversación continua, comprensión, razonamiento, agentic y visión local.
  LmCatalogEntry(
    'LFM2.5-1.2B-Instruct-Q4_0-QAD',
    '1.2B',
    'Q4_0-QAD',
    0.65,
    1.1,
    'LFM2.5-1.2B-Instruct-QAD-Q4_0.gguf',
    'https://huggingface.co/LiquidAI/LFM2.5-1.2B-Instruct-GGUF/resolve/main/LFM2.5-1.2B-Instruct-QAD-Q4_0.gguf',
    'bb741ebb106d543e9de114b843a3d3d73d51c74b5801e69da2abde821a0cb3e1',
    template: ChatTemplate.qwen,
    tier: ModelTier.interactive,
  ),

  LmCatalogEntry(
    'Qwen3.5-2B-Q4_K_M',
    '2B',
    'Q4_K_M',
    1.19,
    1.8,
    'Qwen3.5-2B-Q4_K_M.gguf',
    'https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/main/Qwen3.5-2B-Q4_K_M.gguf',
    'aaf42c8b7c3cab2bf3d69c355048d4a0ee9973d48f16c731c0520ee914699223',
    template: ChatTemplate.qwen,
    tier: ModelTier.interactive,
  ),

  LmCatalogEntry(
    'LFM2.5-1.2B-Thinking',
    '1.2B',
    'Q4_K_M',
    0.68,
    1.1,
    'LFM2.5-1.2B-Thinking.Q4_K_M.gguf',
    'https://huggingface.co/mradermacher/LFM2.5-1.2B-Thinking-GGUF/resolve/main/LFM2.5-1.2B-Thinking.Q4_K_M.gguf',
    '5460bf6d126e85447e5542e88ade8aa6205bc947a28babc77736fffe91747cd8',
    template: ChatTemplate.qwen,
    tier: ModelTier.interactive,
  ),

  LmCatalogEntry(
    'LFM2.5-2.6B-Q4_0-QAD',
    '2.6B',
    'Q4_0-QAD',
    1.48,
    2.2,
    'LFM2.5-2.6B-QAD-Q4_0.gguf',
    'https://huggingface.co/LiquidAI/LFM2.5-2.6B-GGUF/resolve/main/LFM2.5-2.6B-QAD-Q4_0.gguf',
    'a247afd6414918eac8e520a9e6137dc271235461ecbe1180462221d5b8d40b03',
    template: ChatTemplate.qwen,
    tier: ModelTier.interactive,
  ),

  LmCatalogEntry(
    'Gemma-3n-E2B-IT',
    '2B',
    'Q4_K_M',
    2.81,
    3.6,
    'gemma-3n-E2B-it-Q4_K_M.gguf',
    'https://huggingface.co/unsloth/gemma-3n-E2B-it-GGUF/resolve/main/gemma-3n-E2B-it-Q4_K_M.gguf',
    '189d42b4303cb1078ea8d00963f437cd6d884069b7ba2ba80b38cd09585dc415',
    template: ChatTemplate.gemma,
    tier: ModelTier.deep,
  ),

  // Gemma 4 E2B-it — Modelo multimodal 2026 de Google DeepMind (PLE, 2.3B activos, 128k contexto).
  // GGUF y proyector visual mmproj verificados contra la API real de Hugging Face (unsloth/gemma-4-E2B-it-GGUF).
  LmCatalogEntry(
    'Gemma-4-E2B-it',
    '2.3B',
    'Q4_K_M',
    2.89,
    3.8,
    'gemma-4-E2B-it-Q4_K_M.gguf',
    'https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-Q4_K_M.gguf',
    '740185b21d22ceb83a11c3aa62ad5842ef32c70f6096d756bbee85a1e4ec34b8',
    template: ChatTemplate.gemma,
    tier: ModelTier.deep,
    mmprojFile: 'mmproj-F16.gguf',
    mmprojUrl:
        'https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/mmproj-F16.gguf',
    mmprojSha256:
        '140be8d7849741f88c50757d529b84373ee8e27052cc2236855b537f4a8215fa',
  ),

  // Gemma 4 E2B-it (LiteRT-LM) — Formato nativo .litertlm oficial de Google AI Edge (litert-community).
  // Verificado con archivo real en dispositivo físico (2 588 147 712 bytes, GPU/CPU).
  LmCatalogEntry(
    'Gemma-4-E2B-it (LiteRT)',
    '2.3B',
    'int4',
    2.41,
    3.5,
    'gemma-4-E2B-it.litertlm',
    'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/6e5c4f1e395deb959c494953478fa5cec4b8008f/gemma-4-E2B-it.litertlm',
    '181938105e0eefd105961417e8da75903eacda102c4fce9ce90f50b97139a63c',
    template: ChatTemplate.gemma,
    tier: ModelTier.deep,
    backendType: ModelBackendType.litertlm,
  ),

  // A16 — wake word (detector local microWakeWord, modelo .tflite). SHA256
  // verificado del release oficial OHF-Voice/micro-wake-word v2.1_models.
  // No hay modelo "Nano" pre-entrenado: se usa "hey mycroft" como base; un
  // modelo "Nano" se entrenaría con openWakeWord y se añadiría igual.
];
