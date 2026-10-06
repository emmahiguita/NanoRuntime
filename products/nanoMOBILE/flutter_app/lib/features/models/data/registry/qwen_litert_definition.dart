// QUÉ HACE: Documenta el Qwen LiteRT rápido con fuentes y límites publicados.
// CÓMO FUNCIONA: Mantiene sus metadatos separados del catálogo GGUF compacto.
// POR QUÉ: Diferencia arquitectura, plantilla y cuantización sin exceder 200 líneas.
import '../../domain/model_metadata_entities.dart';
import 'model_source_definition.dart';

const _qwenLiteRtCard = ModelSource(
  label: 'LiteRT Community Qwen3-0.6B INT4',
  url: 'https://huggingface.co/litert-community/Qwen3-0.6B-int4',
  provenance: ModelDataProvenance.quantization,
);

const Map<String, ModelSourceDefinition> qwenLiteRtDefinition = {
  'Qwen3-0.6B-Instruct (LiteRT rápido)': ModelSourceDefinition(
    id: 'Qwen3-0.6B-Instruct (LiteRT rápido)',
    officialRepo: 'Qwen/Qwen3-0.6B',
    quantizedRepo: 'litert-community/Qwen3-0.6B-int4',
    developerName: 'Alibaba Cloud (Qwen Team)',
    baseArchitecture: 'Qwen3 Transformer (RoPE + GQA + SwiGLU + RMSNorm)',
    officialLicense: 'Apache 2.0',
    officialContext: 32768,
    officialVocab: 151936,
    officialParams: 0.6,
    quantizationSource: 'LiteRT Community (INT4 block32, no-think)',
    officialBenchmarks: [],
    officialCapabilities: [
      VerifiedCapability(
        name: 'Prefill adaptable',
        description:
            'Firmas 8, 64, 128, 256, 512 y 1024; LiteRT usa la menor que contiene el prompt.',
        source: _qwenLiteRtCard,
      ),
      VerifiedCapability(
        name: 'Respuesta directa',
        description:
            'La plantilla cierra thinking y evita gastar tokens internos en consultas breves.',
        source: _qwenLiteRtCard,
      ),
    ],
    story:
        'Conversión INT4 de Qwen3-0.6B para LiteRT-LM con tokenizer, ChatML y KV máximo de 1280 tokens.',
  ),
};
