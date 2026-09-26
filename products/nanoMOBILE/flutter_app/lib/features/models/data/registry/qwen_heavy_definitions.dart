// qwen_heavy_definitions.dart — Metadatos canónicos de modelos Qwen pesados y destilaciones (2B a 32B).
// QUÉ HACE: Registra fuentes canónicas y benchmarks para modelos Qwen grandes y destilaciones.
// CÓMO FUNCIONA: Colección inmutable tipada de ModelSourceDefinition para alta capacidad.
// POR QUÉ: Permite modularizar el registro de fuentes cumpliendo la regla de archivos < 200 líneas.
library;

import '../../domain/model_metadata_entities.dart';
import 'model_source_definition.dart';

const _qwenCard = ModelSource(
  label: 'Qwen Official Model Card',
  url: 'https://huggingface.co/Qwen',
  provenance: ModelDataProvenance.official,
);

const _emperoCard = ModelSource(
  label: 'Empero AI Model Card',
  url: 'https://huggingface.co/empero-ai',
  provenance: ModelDataProvenance.official,
);

const _bartowskiCard = ModelSource(
  label: 'Bartowski GGUF Card',
  url: 'https://huggingface.co/bartowski',
  provenance: ModelDataProvenance.huggingFace,
);

const Map<String, ModelSourceDefinition> qwenHeavyDefinitions = {
  'Qwen3.8-2B-Q4_K_M': ModelSourceDefinition(
    id: 'Qwen3.8-2B-Q4_K_M',
    officialRepo: 'empero-ai/Qwen3.8-2B',
    quantizedRepo: 'empero-ai/Qwen3.8-2B-GGUF',
    developerName: 'Empero AI (Distilled from Qwen3.8 2.4T A95B)',
    baseArchitecture: 'Qwen3.5 (Hybrid Gated DeltaNet + Multi-Head Attention)',
    officialLicense: 'Apache 2.0',
    officialContext: 262144,
    officialVocab: 152064,
    officialParams: 2.27,
    quantizationSource: 'Empero AI Official (Q4_K_M)',
    officialBenchmarks: [
      VerifiedBenchmark(name: 'MMLU (CoT, 57 subjects)', value: 54.8, unit: 'score (CoT)', source: _emperoCard),
    ],
    officialCapabilities: [
      VerifiedCapability(name: 'Arquitectura Híbrida Gated DeltaNet', description: 'Tres capas Gated DeltaNet por cada capa de atención completa para inferencia ultra veloz en móviles.', source: _emperoCard),
    ],
    story: 'Qwen3.8-2B es una destilación directa de Qwen3.8 2.4T A95B en arquitectura compacta híbrida de 2B parámetros.',
  ),

  'Qwen3.8-2B-Q8_0': ModelSourceDefinition(
    id: 'Qwen3.8-2B-Q8_0',
    officialRepo: 'empero-ai/Qwen3.8-2B',
    quantizedRepo: 'empero-ai/Qwen3.8-2B-GGUF',
    developerName: 'Empero AI (Distilled from Qwen3.8 2.4T A95B)',
    baseArchitecture: 'Qwen3.5 (Hybrid Gated DeltaNet + Multi-Head Attention)',
    officialLicense: 'Apache 2.0',
    officialContext: 262144,
    officialVocab: 152064,
    officialParams: 2.27,
    quantizationSource: 'Empero AI Official (Q8_0)',
    officialBenchmarks: [
      VerifiedBenchmark(name: 'MMLU (CoT)', value: 54.8, unit: 'score', source: _emperoCard),
    ],
    officialCapabilities: [
      VerifiedCapability(name: 'Cuantización de Alta Precisión Q8_0', description: 'Preservación de pesos con precisión casi sin pérdidas para máxima coherencia.', source: _emperoCard),
    ],
    story: 'Variante Q8_0 de Qwen3.8-2B con máxima precisión y fidelidad de razonamiento CoT.',
  ),

  'Qwen2.5-14B-Instruct': ModelSourceDefinition(
    id: 'Qwen2.5-14B-Instruct',
    officialRepo: 'Qwen/Qwen2.5-14B-Instruct',
    quantizedRepo: 'Qwen/Qwen2.5-14B-Instruct-GGUF',
    developerName: 'Alibaba Cloud (Qwen Team)',
    baseArchitecture: 'Transformer (RoPE + GQA + SwiGLU)',
    officialLicense: 'Apache 2.0',
    officialContext: 131072,
    officialVocab: 152064,
    officialParams: 14.7,
    quantizationSource: 'Qwen Team Official (Q4_K_M)',
    officialBenchmarks: [
      VerifiedBenchmark(name: 'MMLU', value: 79.7, unit: 'score (5-shot)', source: _qwenCard),
    ],
    officialCapabilities: [
      VerifiedCapability(name: 'Nivel Experto en Razonamiento', description: 'Capacidad cercana a modelos de 70B en matemáticas y redacción técnica.', source: _qwenCard),
    ],
    story: 'Qwen2.5-14B-Instruct es un modelo de alta capacidad para smartphones de gama alta con 12GB+ de RAM.',
  ),

  'Qwen2.5-14B-Instruct-Q2': ModelSourceDefinition(
    id: 'Qwen2.5-14B-Instruct-Q2',
    officialRepo: 'Qwen/Qwen2.5-14B-Instruct',
    quantizedRepo: 'Qwen/Qwen2.5-14B-Instruct-GGUF',
    developerName: 'Alibaba Cloud (Qwen Team)',
    baseArchitecture: 'Transformer (RoPE + GQA + SwiGLU)',
    officialLicense: 'Apache 2.0',
    officialContext: 131072,
    officialVocab: 152064,
    officialParams: 14.7,
    quantizationSource: 'Qwen Team Official (Q2_K)',
    officialBenchmarks: [
      VerifiedBenchmark(name: 'MMLU', value: 79.7, unit: 'score (5-shot base)', source: _qwenCard),
    ],
    officialCapabilities: [
      VerifiedCapability(name: '14B en 5.8 GB de Espacio', description: 'Permite ejecutar un modelo de 14B con menor consumo de RAM.', source: _qwenCard),
    ],
    story: 'Versión comprimida a 2 bits de Qwen2.5-14B-Instruct.',
  ),

  'Qwen3.8-27B-Q2_K': ModelSourceDefinition(
    id: 'Qwen3.8-27B-Q2_K',
    officialRepo: 'Qwen/Qwen2.5-32B-Instruct',
    quantizedRepo: 'bartowski/Qwen3.8-27B-GGUF',
    developerName: 'Alibaba Cloud (Tongyi Lab)',
    baseArchitecture: 'Transformer Decoder',
    officialLicense: 'Apache 2.0',
    officialContext: 131072,
    officialVocab: 152064,
    officialParams: 27.0,
    quantizationSource: 'Bartowski / llama.cpp (Q2_K)',
    officialBenchmarks: [
      VerifiedBenchmark(name: 'MMLU', value: 82.5, unit: 'score', source: _bartowskiCard),
    ],
    officialCapabilities: [
      VerifiedCapability(name: 'Gran Escala en Móvil', description: 'Modelo de 27B comprimido a Q2_K para dispositivos con 16GB RAM.', source: _bartowskiCard),
    ],
    story: 'Cuantización comunitaria de gran escala provista por Bartowski.',
  ),

  'Qwen3.8-27B-Q4_K_M': ModelSourceDefinition(
    id: 'Qwen3.8-27B-Q4_K_M',
    officialRepo: 'Qwen/Qwen2.5-32B-Instruct',
    quantizedRepo: 'bartowski/Qwen3.8-27B-GGUF',
    developerName: 'Alibaba Cloud (Tongyi Lab)',
    baseArchitecture: 'Transformer Decoder',
    officialLicense: 'Apache 2.0',
    officialContext: 131072,
    officialVocab: 152064,
    officialParams: 27.0,
    quantizationSource: 'Bartowski / llama.cpp (Q4_K_M)',
    officialBenchmarks: [
      VerifiedBenchmark(name: 'MMLU', value: 82.5, unit: 'score', source: _bartowskiCard),
    ],
    officialCapabilities: [
      VerifiedCapability(name: 'Alta Fidelidad (17.7 GB)', description: 'Para estaciones de trabajo y dispositivos con 20GB+ RAM disponible.', source: _bartowskiCard),
    ],
    story: 'Versión Q4_K_M de gran escala para máxima precisión.',
  ),

  'Qwen2.5-32B-Instruct-Q2': ModelSourceDefinition(
    id: 'Qwen2.5-32B-Instruct-Q2',
    officialRepo: 'Qwen/Qwen2.5-32B-Instruct',
    quantizedRepo: 'Qwen/Qwen2.5-32B-Instruct-GGUF',
    developerName: 'Alibaba Cloud (Qwen Team)',
    baseArchitecture: 'Transformer (RoPE + GQA + SwiGLU)',
    officialLicense: 'Apache 2.0',
    officialContext: 131072,
    officialVocab: 152064,
    officialParams: 32.5,
    quantizationSource: 'Qwen Team Official (Q2_K)',
    officialBenchmarks: [],
    officialCapabilities: [],
    story: 'Versión compacta Q2_K de Qwen2.5-32B.',
  ),
};
