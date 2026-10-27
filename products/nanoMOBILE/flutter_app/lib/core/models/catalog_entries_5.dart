part of 'catalog_models.dart';

// Modelos LiteRT-LM 2026 de razonamiento, agentes y conversación avanzada.
// Todos tienen URL directa y SHA-256 LFS verificado de litert-community.
const _catalogEntries5 = <LmCatalogEntry>[
  // Gemma 4 E4B: versión multimodal y agentic de mayor capacidad para borde.
  LmCatalogEntry(
    'Gemma-4-E4B-it (LiteRT)',
    '4.0B',
    'INT4',
    3.41,
    4.5,
    'gemma-4-E4B-it.litertlm',
    'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/e6a3892a8c22cf87ff99583996149cf3cb32452b/gemma-4-E4B-it.litertlm',
    '0b2a8980ce155fd97673d8e820b4d29d9c7d99b8fa6806f425d969b145bd52e0',
    template: ChatTemplate.gemma,
    tier: ModelTier.deep,
    backendType: ModelBackendType.litertlm,
  ),

  // Gemma 4 12B GPU: multimodal avanzado (texto/visión/audio) para gama alta.
  LmCatalogEntry(
    'Gemma-4-12B-it GPU (LiteRT)',
    '12B',
    'INT4-GPU',
    5.58,
    8.0,
    'gemma-4-12B-it-gpu.litertlm',
    'https://huggingface.co/litert-community/gemma-4-12B-it-litert-lm/resolve/7a0b1ce0ea821bcd01c5f72af84155e02191152f/gemma-4-12B-it-gpu.litertlm',
    'fba0ea417fda0eecdcc1e62e0ea7777acf44f171cefb3bc05a642746f39faf39',
    template: ChatTemplate.gemma,
    tier: ModelTier.extreme,
    backendType: ModelBackendType.litertlm,
  ),

  // IBM Granite 4.1 3B INT4: chat, RAG, tool calling y contexto largo en móvil.
  LmCatalogEntry(
    'Granite-4.1-3B (LiteRT INT4)',
    '3.4B',
    'INT4',
    2.04,
    3.0,
    'granite-4.1-3b_int4.litertlm',
    'https://huggingface.co/litert-community/granite-4.1-3b/resolve/18243dddea72ce4980c873247f3d124d41fe47ae/granite-4.1-3b_int4.litertlm',
    'ba60c191fd33b1ac9d1ab245d4a24fe81e1a520a0dd9720a435a9cc4773d80a9',
    template: ChatTemplate.qwen,
    tier: ModelTier.deep,
    backendType: ModelBackendType.litertlm,
  ),

  // IBM Granite 4.2 3B INT4: razonamiento nativo, código, matemáticas y agentes.
  LmCatalogEntry(
    'Granite-4.2-3B (LiteRT INT4)',
    '3.66B',
    'INT4',
    2.04,
    3.1,
    'granite-4.2-3b_int4.litertlm',
    'https://huggingface.co/litert-community/granite-4.2-3b/resolve/7b431efd7f81567584a39b244e7733466955f6ec/granite-4.2-3b_int4.litertlm',
    '9859901f6050df5c4616e31462643b76d0aa2bd395a8863cb6162495c1ef517d',
    template: ChatTemplate.qwen,
    tier: ModelTier.deep,
    backendType: ModelBackendType.litertlm,
  ),

  // InternScience Agents-A1 4B Mixed INT4: planificación agentic y tool calling.
  LmCatalogEntry(
    'Agents-A1-4B (LiteRT INT4)',
    '4.0B',
    'INT4-Mix',
    2.57,
    3.6,
    'Agents-A1-4B_mixed_int4.litertlm',
    'https://huggingface.co/litert-community/Agents-A1-4B/resolve/f6c427b5760a40a4d0096d1c95c9387d18a4c22f/Agents-A1-4B_mixed_int4.litertlm',
    '13c53e3ada0655ed1af4204aa2b659fe7cd553a1e7d5ef8e8b11d1ed3c15203c',
    template: ChatTemplate.qwen,
    tier: ModelTier.deep,
    backendType: ModelBackendType.litertlm,
  ),

  // InternScience Agents-A1 4B INT8: máxima fidelidad en tareas largas de agentes.
  LmCatalogEntry(
    'Agents-A1-4B (LiteRT INT8)',
    '4.0B',
    'INT8',
    4.12,
    5.2,
    'Agents-A1-4B_int8.litertlm',
    'https://huggingface.co/litert-community/Agents-A1-4B/resolve/f6c427b5760a40a4d0096d1c95c9387d18a4c22f/Agents-A1-4B_int8.litertlm',
    '53fb97401682c805694f456ccdc56ded8b9f81b8ac7076e2c6b759ae59727292',
    template: ChatTemplate.qwen,
    tier: ModelTier.extreme,
    backendType: ModelBackendType.litertlm,
  ),

  // iFLYTEK Spark-X2.5 4B INT4: razonamiento <think> y arquitectura híbrida.
  LmCatalogEntry(
    'Spark-X2.5-4B (LiteRT INT4)',
    '4.11B',
    'INT4',
    2.31,
    3.4,
    'Spark-X2.5-4B_int4.litertlm',
    'https://huggingface.co/litert-community/Spark-X2.5-4B/resolve/1b22f5490f8d1239760cd6aa8fcbfa637d8ae6aa/Spark-X2.5-4B_int4.litertlm',
    'ff4fd431693086e44d3c02c338791c90c7197068b06190e1cc2f6a655d83c4f4',
    template: ChatTemplate.qwen,
    tier: ModelTier.deep,
    backendType: ModelBackendType.litertlm,
  ),
];
