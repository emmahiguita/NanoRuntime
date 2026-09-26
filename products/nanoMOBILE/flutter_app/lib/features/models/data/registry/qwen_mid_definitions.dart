// qwen_mid_definitions.dart — Metadatos canónicos de modelos Qwen de escala media (3B a 7B).
// QUÉ HACE: Registra fuentes canónicas y benchmarks para Qwen 3B, 4B y 7B.
// CÓMO FUNCIONA: Colección inmutable tipada de ModelSourceDefinition para inferencia profunda.
// POR QUÉ: Mantiene la modularidad y asegura código bajo 200 líneas (SOLID).
library;

import '../../domain/model_metadata_entities.dart';
import 'model_source_definition.dart';

const _qwenCard = ModelSource(
  label: 'Qwen Official Model Card',
  url: 'https://huggingface.co/Qwen',
  provenance: ModelDataProvenance.official,
);

const Map<String, ModelSourceDefinition> qwenMidDefinitions = {
  'Qwen2.5-3B-Instruct': ModelSourceDefinition(
    id: 'Qwen2.5-3B-Instruct',
    officialRepo: 'Qwen/Qwen2.5-3B-Instruct',
    quantizedRepo: 'Qwen/Qwen2.5-3B-Instruct-GGUF',
    developerName: 'Alibaba Cloud (Qwen Team)',
    baseArchitecture: 'Transformer (RoPE + GQA + SwiGLU)',
    officialLicense: 'Qwen Research / Apache 2.0',
    officialContext: 32768,
    officialVocab: 152064,
    officialParams: 3.09,
    quantizationSource: 'Qwen Team Official (Q8_0)',
    officialBenchmarks: [
      VerifiedBenchmark(name: 'MMLU', value: 68.4, unit: 'score (5-shot)', source: _qwenCard),
      VerifiedBenchmark(name: 'GSM8K', value: 79.2, unit: 'score (4-shot)', source: _qwenCard),
    ],
    officialCapabilities: [
      VerifiedCapability(name: 'Comprensión de Instrucciones Complejas', description: 'Capacidad de resumen, redacción y análisis de textos extensos.', source: _qwenCard),
    ],
    story: 'Qwen2.5-3B-Instruct es la opción insignia para smartphones modernos con 6GB+ de RAM.',
  ),

  'Qwen2.5-3B-Instruct-Q4_K_M': ModelSourceDefinition(
    id: 'Qwen2.5-3B-Instruct-Q4_K_M',
    officialRepo: 'Qwen/Qwen2.5-3B-Instruct',
    quantizedRepo: 'Qwen/Qwen2.5-3B-Instruct-GGUF',
    developerName: 'Alibaba Cloud (Qwen Team)',
    baseArchitecture: 'Transformer (RoPE + GQA + SwiGLU)',
    officialLicense: 'Qwen Research / Apache 2.0',
    officialContext: 32768,
    officialVocab: 152064,
    officialParams: 3.09,
    quantizationSource: 'Qwen Team Official (Q4_K_M)',
    officialBenchmarks: [
      VerifiedBenchmark(name: 'MMLU', value: 68.4, unit: 'score (5-shot)', source: _qwenCard),
    ],
    officialCapabilities: [
      VerifiedCapability(name: 'Inferencia Balanceada (2.09 GB)', description: 'Cuantización de peso medio de 4 bits con baja degradación de perplejidad.', source: _qwenCard),
    ],
    story: 'Variante cuantizada Q4_K_M de Qwen2.5-3B-Instruct para máxima eficiencia en RAM móvil.',
  ),

  'Qwen2.5-7B-Instruct': ModelSourceDefinition(
    id: 'Qwen2.5-7B-Instruct',
    officialRepo: 'Qwen/Qwen2.5-7B-Instruct',
    quantizedRepo: 'Qwen/Qwen2.5-7B-Instruct-GGUF',
    developerName: 'Alibaba Cloud (Qwen Team)',
    baseArchitecture: 'Transformer (RoPE + GQA + SwiGLU)',
    officialLicense: 'Apache 2.0',
    officialContext: 131072,
    officialVocab: 152064,
    officialParams: 7.61,
    quantizationSource: 'Qwen Team Official (Q4_K_M)',
    officialBenchmarks: [
      VerifiedBenchmark(name: 'MMLU', value: 74.2, unit: 'score (5-shot)', source: _qwenCard),
    ],
    officialCapabilities: [
      VerifiedCapability(name: 'Contexto Extenso de 128k Tokens', description: 'Capacidad nativa de procesamiento de documentos y libros extensos.', source: _qwenCard),
    ],
    story: 'Qwen2.5-7B-Instruct es el modelo de referencia en la categoría de 7B parámetros a nivel mundial.',
  ),

  'Qwen3.5-4B': ModelSourceDefinition(
    id: 'Qwen3.5-4B',
    officialRepo: 'Qwen/Qwen3.5-4B',
    quantizedRepo: 'unsloth/Qwen3.5-4B-GGUF',
    developerName: 'Alibaba Cloud (Tongyi Lab)',
    baseArchitecture: 'Hybrid Transformer (Linear Attention + GQA)',
    officialLicense: 'Apache 2.0',
    officialContext: 131072,
    officialVocab: 152064,
    officialParams: 4.15,
    quantizationSource: 'Unsloth AI (Dynamic Q4_K_S)',
    officialBenchmarks: [
      VerifiedBenchmark(name: 'MMLU', value: 70.8, unit: 'score', source: _qwenCard),
    ],
    officialCapabilities: [
      VerifiedCapability(name: 'Atención Híbrida Eficiente', description: 'Reduce el consumo de memoria en contextos largos.', source: _qwenCard),
    ],
    story: 'Variante moderna con optimizaciones de inferencia rápida y bajo consumo de memoria distribuida por Unsloth.',
  ),

  'Qwen3.5-4B-Q4_K_M': ModelSourceDefinition(
    id: 'Qwen3.5-4B-Q4_K_M',
    officialRepo: 'Qwen/Qwen3.5-4B',
    quantizedRepo: 'unsloth/Qwen3.5-4B-GGUF',
    developerName: 'Alibaba Cloud (Tongyi Lab)',
    baseArchitecture: 'Hybrid Transformer (Linear Attention + GQA)',
    officialLicense: 'Apache 2.0',
    officialContext: 131072,
    officialVocab: 152064,
    officialParams: 4.15,
    quantizationSource: 'Unsloth AI (Dynamic Q4_K_M)',
    officialBenchmarks: [
      VerifiedBenchmark(name: 'MMLU', value: 70.8, unit: 'score', source: _qwenCard),
    ],
    officialCapabilities: [
      VerifiedCapability(name: 'Atención Híbrida Eficiente', description: 'Reduce el consumo de memoria en contextos largos con cuantización balanceada.', source: _qwenCard),
    ],
    story: 'Variante con cuantización Q4_K_M para mayor fidelidad en respuestas complejas.',
  ),
};
