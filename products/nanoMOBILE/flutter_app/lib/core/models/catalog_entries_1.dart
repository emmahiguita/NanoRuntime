part of 'catalog_models.dart';

// Alternativas LiteRT-LM verificadas; la velocidad en el OPPO queda por medir.
const _catalogEntries1 = <LmCatalogEntry>[
  // Gemma queda avanzada por su estimación declarada de 3.5 GB de RAM.
  // El formato LiteRT-LM se conserva y la interfaz no lo presenta como velocidad medida en este equipo.
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
  // Liquid AI: descarga INT8 de 266053344 bytes, sin añadir pesos a la APK.
  // El bundle lleva plantilla, tokenizer y estados híbridos para LiteRT >= 0.15.
  // RAM estimada con margen; el nivel avanzado exige elegirlo sin recomendarlo.
  LmCatalogEntry(
    'LFM2.5-230M (LiteRT)',
    '230M',
    'INT8',
    0.25,
    1.0,
    'LFM2.5-230M_int8.litertlm',
    'https://huggingface.co/litert-community/LFM2.5-230M/resolve/bcbead5912c3b7451a01f2bf45a17bbe8733356b/LFM2.5-230M_int8.litertlm',
    'f8bc1a685e07e4f547d0390476b7d21b72c6dba3a7e4a76400b211b3d28628a9',
    tier: ModelTier.deep,
    backendType: ModelBackendType.litertlm,
  ),
  // DeepSeek: mismo artefacto fijado por Google AI Edge Gallery, con SHA LFS.
  // Es una opción de razonamiento; el tamaño y la RAM no son mediciones de rapidez.
  LmCatalogEntry(
    'DeepSeek-R1-Distill-Qwen-1.5B (LiteRT)',
    '1.5B',
    'Q8',
    1.71,
    3.0,
    'DeepSeek-R1-Distill-Qwen-1.5B_multi-prefill-seq_q8_ekv4096.litertlm',
    'https://huggingface.co/litert-community/DeepSeek-R1-Distill-Qwen-1.5B/resolve/e34bb88632342d1f9640bad579a45134eb1cf988/DeepSeek-R1-Distill-Qwen-1.5B_multi-prefill-seq_q8_ekv4096.litertlm',
    '69b35f01759eed765641ab4af589bbe98131fd2825662a086d9037409b8c1295',
    template: ChatTemplate.deepseek,
    tier: ModelTier.deep,
    backendType: ModelBackendType.litertlm,
  ),
];
