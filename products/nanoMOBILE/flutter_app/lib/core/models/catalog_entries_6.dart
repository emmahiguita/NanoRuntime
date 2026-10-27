part of 'catalog_models.dart';

// Modelos LiteRT 2026 especializados: OCR, visión documental, embeddings, ASR, diarización y TTS.
// Todos cuentan con URL directa y SHA-256 LFS verificado de litert-community.
const _catalogEntries6 = <LmCatalogEntry>[
  // EmbeddingGemma 2 Text+Vision 440M: embeddings conjuntos de texto e imágenes (388 MB).
  LmCatalogEntry(
    'EmbeddingGemma-2-Text-Vision-440M (LiteRT)',
    '440M',
    'FP16/INT8',
    0.36,
    0.7,
    'embeddinggemma-2-text-vision-440m.litertlm',
    'https://huggingface.co/litert-community/embeddinggemma-2-text-vision-440m-litert-lm/resolve/e301f74d5551b0c2641bd5cb4652a76239d5c5f8/embeddinggemma-2-text-vision-440m.litertlm',
    '92dcbea108899e5d6e30d919b0744f90d9967e80c67a4ab5503ac16d54f62eb0',
    template: ChatTemplate.gemma,
    tier: ModelTier.interactive,
    kind: ModelKind.embedding,
    backendType: ModelBackendType.litertlm,
  ),

  // PaddleOCR-VL 1.6: OCR en 109 idiomas, tablas, fórmulas LaTeX, gráficas y sellos (1.39 GB).
  LmCatalogEntry(
    'PaddleOCR-VL-1.6 (LiteRT Visión)',
    '0.9B',
    'INT8-VL',
    1.29,
    2.0,
    'PaddleOCR-VL-1.6.litertlm',
    'https://huggingface.co/litert-community/PaddleOCR-VL-1.6/resolve/eb04490d43ce6197686ddc878e1093eacc7610a2/PaddleOCR-VL-1.6.litertlm',
    '314df8b34d6911990d488e825602550a5bbcc5d6700cb1a8914e853e9043f4f1',
    template: ChatTemplate.qwen,
    tier: ModelTier.interactive,
    kind: ModelKind.imageOcr,
    backendType: ModelBackendType.litertlm,
  ),

  // Qwen3-ASR 0.6B: reconocimiento de voz e identificación de idioma en 52 idiomas/dialectos.
  LmCatalogEntry(
    'Qwen3-ASR-0.6B (Voz Local LiteRT)',
    '0.6B',
    'INT8',
    0.89,
    1.3,
    'qwen3_asr_0.6b_5s_i8.litertlm',
    'https://huggingface.co/litert-community/Qwen3-ASR-0.6B/resolve/80384dfbad4a6cd0c698892395c4664fd122c081/qwen3_asr_0.6b_5s_i8.litertlm',
    'd4444d51f0c08142f57e16097673150f3ea02900a00b29a58a41f6e7578db251',
    kind: ModelKind.voiceStt,
    tier: ModelTier.interactive,
    backendType: ModelBackendType.litertlm,
  ),

  // Qwen3-ASR 1.7B: ASR de alta precisión para voz, acentos y canciones en 52 variedades.
  LmCatalogEntry(
    'Qwen3-ASR-1.7B (Voz Local LiteRT)',
    '1.7B',
    'INT8',
    2.51,
    3.2,
    'Qwen3-ASR-1.7B.litertlm',
    'https://huggingface.co/litert-community/Qwen3-ASR-1.7B/resolve/184ec0f1ef8c8b5254100e95ec713b5557fb91de/Qwen3-ASR-1.7B.litertlm',
    '6155d5d5f8d57e7a3e50f669fd487ae0d8aed0845bb4091f39a894eea7067b95',
    kind: ModelKind.voiceStt,
    tier: ModelTier.deep,
    backendType: ModelBackendType.litertlm,
  ),

  // NVIDIA Nemotron 3 Diarization: detecta quién habla y cuándo (hasta 8 hablantes, streaming).
  LmCatalogEntry(
    'Nemotron-3-Diarization-100M (Voz LiteRT)',
    '100M',
    'FP16',
    0.19,
    0.4,
    'nemotron3_diar_encoder_low_latency_fp16.tflite',
    'https://huggingface.co/litert-community/Nemotron-3-Diarization-LiteRT/resolve/4a6b8c830a7384169f54668d474865b3b4745c32/nemotron3_diar_encoder_low_latency_fp16.tflite',
    'c5685c76a59e115d47d8e3788192582e966a1b19f53add55d34d7841943be3b9',
    kind: ModelKind.speakerDiarization,
    tier: ModelTier.interactive,
    backendType: ModelBackendType.litertlm,
  ),

  // Edge0 Audio8 TTS Preview 0.6B: síntesis texto → voz 44.1 kHz y clonación zero-shot (11 idiomas).
  LmCatalogEntry(
    'Audio8-TTS-Preview-0.6B (Voz LiteRT)',
    '0.6B',
    'INT4',
    0.36,
    0.8,
    'slow_ar_int4.tflite',
    'https://huggingface.co/litert-community/Audio8-TTS-Preview-0.6b/resolve/56fcb491ebf03eb3a1a66615fedf6744015dd4c7/slow_ar_int4.tflite',
    'bd2ff1a9b1ec98c064e0e801162e1ae8cd83f928574df527a37be23175625458',
    kind: ModelKind.voiceTts,
    tier: ModelTier.interactive,
    backendType: ModelBackendType.litertlm,
  ),
];
