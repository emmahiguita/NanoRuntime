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
    'F16',
    0.075,
    0.15,
    'ggml-tiny.bin',
    'https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-tiny.bin',
    'be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21',
    kind: ModelKind.voiceStt,
    tier: ModelTier.interactive,
  ),

  LmCatalogEntry(
    'Whisper-Base (Voz Local)',
    '74M',
    'F16',
    0.142,
    0.25,
    'ggml-base.bin',
    'https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-base.bin',
    '60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe',
    kind: ModelKind.voiceStt,
    tier: ModelTier.interactive,
  ),

];
