part of 'catalog_models.dart';

// Modelos de conversación con artefacto LiteRT-LM oficial y SHA fijado.
const _catalogEntries0 = <LmCatalogEntry>[
  // Qwen LiteRT real: artefacto no-think fijado a commit y SHA de Hugging Face.
  // Sus prefills 8..1024 evitan pagar un bloque grande para mensajes cortos.
  LmCatalogEntry(
    'Qwen3-0.6B-Instruct (LiteRT)',
    '0.6B',
    'INT4-B32',
    0.32,
    1.0,
    'qwen3_0.6b_nothink_q4_block32_ekv1280.litertlm',
    'https://huggingface.co/litert-community/Qwen3-0.6B-int4/resolve/6aa2daf8aba4aa456797fb8040b36a3948bcfda7/qwen3_0.6b_nothink_q4_block32_ekv1280.litertlm',
    '2df6821ec12702dafd33915e7a1a1adc7c4b053f3672fd9555dfaf3a114c4139',
    template: ChatTemplate.qwen,
    backendType: ModelBackendType.litertlm,
  ),

  // Paquete LiteRT-LM oficial; queda avanzado porque el Oppo aún no se ha medido.
  // La referencia pública registra hasta 2.2 GB de pico en otro teléfono.
  LmCatalogEntry(
    'Qwen2.5-1.5B-Instruct (LiteRT)',
    '1.5B',
    'Q8',
    1.49,
    2.2,
    'Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv4096.litertlm',
    'https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct/resolve/19edb84c69a0212f29a6ef17ba0d6f278b6a1614/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv4096.litertlm',
    'faa60663b333290c1496c499828b21d3e3254a788cacd8cce917ce0f761a2dc9',
    template: ChatTemplate.qwen,
    tier: ModelTier.deep,
    backendType: ModelBackendType.litertlm,
  ),

];
