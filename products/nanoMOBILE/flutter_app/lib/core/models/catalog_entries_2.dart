part of 'catalog_models.dart';

// Descargas auxiliares: transcripción de voz local con whisper.cpp.
const _catalogEntries2 = <LmCatalogEntry>[
  // Qwen Omni necesita su paquete MNN nativo; la revisión fija impide cambios silenciosos.
  LmCatalogEntry(
    'Qwen2.5-Omni-3B (MNN)',
    '3B',
    'MNN 4-bit',
    4.02,
    4.0,
    'Qwen2.5-Omni-3B-MNN',
    'https://huggingface.co/taobao-mnn/Qwen2.5-Omni-3B-MNN',
    '',
    template: ChatTemplate.qwen,
    tier: ModelTier.deep,
    kind: ModelKind.llm,
    backendType: ModelBackendType.mnn,
    packageRevision: '0377bda',
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

];
