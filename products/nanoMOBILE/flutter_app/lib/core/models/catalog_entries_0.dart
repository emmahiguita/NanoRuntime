part of 'catalog_models.dart';

// Entradas existentes separadas por tamaño; solo hay un catálogo público.
const _catalogEntries0 = <LmCatalogEntry>[
  LmCatalogEntry(
    'Qwen2.5-0.5B-Instruct',
    '0.5B',
    'Q8_0',
    0.68,
    1.0,
    'qwen2.5-0.5b-instruct-q8_0.gguf',
    'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q8_0.gguf',
    'ca59ca7f13d0e15a8cfa77bd17e65d24f6844b554a7b6c12e07a5f89ff76844e',
    template: ChatTemplate.qwen,
  ),

  LmCatalogEntry(
    'Qwen2.5-1.5B-Instruct',
    '1.5B',
    'Q8_0',
    1.76,
    2.2,
    'qwen2.5-1.5b-instruct-q8_0.gguf',
    'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q8_0.gguf',
    'd7efb072e7724d25048a4fda0a3e10b04bdef5d06b1403a1c93bd9f1240a63c8',
    template: ChatTemplate.qwen,
  ),

  LmCatalogEntry(
    'Qwen2.5-Coder-1.5B-Instruct',
    '1.5B',
    'Q4_K_M',
    0.99,
    1.5,
    'qwen2.5-coder-1.5b-instruct-q4_k_m.gguf',
    'https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf',
    'cc324af070c2ecbfd324a30884d2f951a7ff756aba85cb811a6ec436933bb046',
    template: ChatTemplate.qwen,
  ),

  LmCatalogEntry(
    'Qwen2.5-3B-Instruct-Q4_K_M',
    '3B',
    'Q4_K_M',
    2.09,
    2.8,
    'qwen2.5-3b-instruct-q4_k_m.gguf',
    'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf',
    '626b4a6678b86442240e33df819e00132d3ba7dddfe1cdc4fbb18e0a9615c62d',
    template: ChatTemplate.qwen,
  ),

  LmCatalogEntry(
    'Qwen2.5-3B-Instruct',
    '3B',
    'Q8_0',
    3.37,
    4.0,
    'qwen2.5-3b-instruct-q8_0.gguf',
    'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q8_0.gguf',
    '6dcc22694c8654b045ec40bbe350212b88893fd9010e8474bae5b19a43578ba1',
    template: ChatTemplate.qwen,
  ),

  LmCatalogEntry(
    'Qwen3.8-2B-Q4_K_M',
    '2B',
    'Q4_K_M',
    1.31,
    1.9,
    'Qwen3.8-2B-Q4_K_M.gguf',
    'https://huggingface.co/empero-ai/Qwen3.8-2B-Distill-GGUF/resolve/main/Qwen3.8-2B-Q4_K_M.gguf',
    '4aa0fb13c431514262f259d420ecc95a8714df58ac2a2384514e20b93983f0ff',
    template: ChatTemplate.qwen,
  ),

  LmCatalogEntry(
    'Qwen3.8-2B-Q8_0',
    '2B',
    'Q8_0',
    2.08,
    2.7,
    'Qwen3.8-2B-Q8_0.gguf',
    'https://huggingface.co/empero-ai/Qwen3.8-2B-Distill-GGUF/resolve/main/Qwen3.8-2B-Q8_0.gguf',
    '866773b0d68f09a1db9733555e92daff85b617f9a2e601773dff494c5ca2bbf2',
    template: ChatTemplate.qwen,
  ),

  LmCatalogEntry(
    'Qwen3.5-4B-Q4_K_M',
    '4B',
    'Q4_K_M',
    2.55,
    3.5,
    'Qwen3.5-4B-Q4_K_M.gguf',
    'https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/resolve/main/Qwen3.5-4B-Q4_K_M.gguf',
    '00fe7986ff5f6b463e62455821146049db6f9313603938a70800d1fb69ef11a4',
    template: ChatTemplate.qwen,
    tier: ModelTier.deep,
  ),

  LmCatalogEntry(
    'Phi-3.5-mini-Instruct-3.8B',
    '3.8B',
    'Q4_K_M',
    2.39,
    3.2,
    'Phi-3.5-mini-instruct-Q4_K_M.gguf',
    'https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf',
    'e4165e3a71af97f1b4820da61079826d8752a2088e313af0c7d346796c38eff5',
    template: ChatTemplate.qwen,
    tier: ModelTier.deep,
  ),

  LmCatalogEntry(
    'Llama-3.2-1B-Instruct',
    '1B',
    'Q4_K_M',
    0.79,
    1.2,
    'Llama-3.2-1B-Instruct-Q4_K_M.gguf',
    'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
    '6f85a640a97cf2bf5b8e764087b1e83da0fdb51d7c9fab7d0fece9385611df83',
    template: ChatTemplate.llama,
  ),

  LmCatalogEntry(
    'DeepSeek-R1-Distill-Qwen-7B',
    '7B',
    'Q4_K_M',
    4.36,
    5.5,
    'DeepSeek-R1-Distill-Qwen-7B-Q4_K_M.gguf',
    'https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-7B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-7B-Q4_K_M.gguf',
    '78272d8d32084548bd450394a560eb2d70de8232ab96a725769b1f9171235c1c',
    template: ChatTemplate.deepseek,
    tier: ModelTier.deep,
  ),

  LmCatalogEntry(
    'DeepSeek-R1-Distill-Qwen-7B-Q2',
    '7B',
    'Q2_K',
    2.81,
    4.0,
    'DeepSeek-R1-Distill-Qwen-7B-Q2_K.gguf',
    'https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-7B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-7B-Q2_K.gguf',
    '7680555ca635d38cd851095f0f21caed0632f021005037f7d689de77e8f64c35',
    template: ChatTemplate.deepseek,
    tier: ModelTier.deep,
  ),

  // MODELS-CAT-01 — modelos conversacionales 2025-2026 verificados contra
  // la API real de HuggingFace (api/models/<repo>/tree/main) el 2026-09-04:
  // nombre de archivo, tamaño y lfs.oid (SHA256) copiados tal cual, jamás
  // inventados. El gate de instalación exige coincidencia del hash.
  LmCatalogEntry(
    'Qwen3-1.7B-Instruct',
    '1.7B',
    'Q8_0',
    1.83,
    2.4,
    'Qwen3-1.7B-Q8_0.gguf',
    'https://huggingface.co/Qwen/Qwen3-1.7B-GGUF/resolve/main/Qwen3-1.7B-Q8_0.gguf',
    '061b54daade076b5d3362dac252678d17da8c68f07560be70818cace6590cb1a',
    template: ChatTemplate.qwen,
  ),
];
