// qwen_compact_definitions.dart — Metadatos canónicos de modelos Qwen compactos (< 3B).
// QUÉ HACE: Registra fuentes canónicas y benchmarks para modelos Qwen optimizados para CPU móvil.
// CÓMO FUNCIONA: Colección inmutable tipada de ModelSourceDefinition para inferencia de baja latencia.
// POR QUÉ: Permite modularizar el registro de fuentes cumpliendo la regla de archivos < 200 líneas.
library;

import '../../domain/model_metadata_entities.dart';
import 'model_source_definition.dart';

const _qwenCard = ModelSource(
  label: 'Qwen Official Model Card',
  url: 'https://huggingface.co/Qwen',
  provenance: ModelDataProvenance.official,
);

const Map<String, ModelSourceDefinition> qwenCompactDefinitions = {
  'Qwen2.5-0.5B-Instruct': ModelSourceDefinition(
    id: 'Qwen2.5-0.5B-Instruct',
    officialRepo: 'Qwen/Qwen2.5-0.5B-Instruct',
    quantizedRepo: 'Qwen/Qwen2.5-0.5B-Instruct-GGUF',
    developerName: 'Alibaba Cloud (Qwen Team)',
    baseArchitecture: 'Transformer (RoPE + GQA + SwiGLU + Dual RMSNorm)',
    officialLicense: 'Apache 2.0',
    officialContext: 32768,
    officialVocab: 152064,
    officialParams: 0.49,
    quantizationSource: 'Qwen Team Official (Q8_0)',
    officialBenchmarks: [
      VerifiedBenchmark(name: 'MMLU', value: 47.4, unit: 'score (5-shot)', source: _qwenCard),
      VerifiedBenchmark(name: 'GSM8K', value: 43.1, unit: 'score (4-shot)', source: _qwenCard),
    ],
    officialCapabilities: [
      VerifiedCapability(name: 'Inferencia Ultrarrápida Móvil', description: 'Optimizado para CPU móvil ARM con latencia mínima (<1 GB RAM).', source: _qwenCard),
      VerifiedCapability(name: 'Soporte Multilingüe (29+ idiomas)', description: 'Capacidad de comprensión y generación en español, inglés, chino, etc.', source: _qwenCard),
    ],
    story: 'Qwen2.5-0.5B-Instruct es el modelo más ligero de la familia Qwen2.5, ideal para tareas directas, clasificación de texto y respuestas rápidas en dispositivos móviles.',
  ),

  'Qwen2.5-1.5B-Instruct': ModelSourceDefinition(
    id: 'Qwen2.5-1.5B-Instruct',
    officialRepo: 'Qwen/Qwen2.5-1.5B-Instruct',
    quantizedRepo: 'Qwen/Qwen2.5-1.5B-Instruct-GGUF',
    developerName: 'Alibaba Cloud (Qwen Team)',
    baseArchitecture: 'Transformer (RoPE + GQA + SwiGLU)',
    officialLicense: 'Apache 2.0',
    officialContext: 32768,
    officialVocab: 152064,
    officialParams: 1.54,
    quantizationSource: 'Qwen Team Official (Q8_0)',
    officialBenchmarks: [
      VerifiedBenchmark(name: 'MMLU', value: 60.9, unit: 'score (5-shot)', source: _qwenCard),
      VerifiedBenchmark(name: 'GSM8K', value: 68.5, unit: 'score (4-shot)', source: _qwenCard),
      VerifiedBenchmark(name: 'HumanEval', value: 53.0, unit: 'pass@1', source: _qwenCard),
    ],
    officialCapabilities: [
      VerifiedCapability(name: 'Diálogo Multiturno & Asistente', description: 'Excelente coherencia conversacional en teléfonos de 4GB a 6GB RAM.', source: _qwenCard),
    ],
    story: 'Qwen2.5-1.5B-Instruct ofrece un equilibrio óptimo entre calidad lingüística, precisión matemática y velocidad de ejecución local en smartphones.',
  ),

  'Qwen2.5-Coder-1.5B-Instruct': ModelSourceDefinition(
    id: 'Qwen2.5-Coder-1.5B-Instruct',
    officialRepo: 'Qwen/Qwen2.5-Coder-1.5B-Instruct',
    quantizedRepo: 'Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF',
    developerName: 'Alibaba Cloud (Qwen Team)',
    baseArchitecture: 'Transformer (RoPE + GQA + SwiGLU)',
    officialLicense: 'Apache 2.0',
    officialContext: 32768,
    officialVocab: 152064,
    officialParams: 1.54,
    quantizationSource: 'Qwen Team Official (Q4_K_M)',
    officialBenchmarks: [
      VerifiedBenchmark(name: 'HumanEval', value: 70.1, unit: 'pass@1', source: _qwenCard),
    ],
    officialCapabilities: [
      VerifiedCapability(name: 'Generación y Completado de Código', description: 'Especializado en más de 92 lenguajes de programación.', source: _qwenCard),
    ],
    story: 'Qwen2.5-Coder-1.5B-Instruct es un modelo especializado en desarrollo de software, entrenado con 5.5 billones de tokens de código fuente.',
  ),

  'Qwen3-0.6B-Q8_0': ModelSourceDefinition(
    id: 'Qwen3-0.6B-Q8_0',
    officialRepo: 'Qwen/Qwen3-0.6B',
    quantizedRepo: 'Qwen/Qwen3-0.6B-GGUF',
    developerName: 'Alibaba Cloud (Qwen Team)',
    baseArchitecture: 'Transformer (RoPE + GQA + SwiGLU + RMSNorm)',
    officialLicense: 'Apache 2.0',
    officialContext: 32768,
    officialVocab: 151936,
    officialParams: 0.6,
    quantizationSource: 'Qwen Team Official (Q8_0)',
    officialBenchmarks: [
      VerifiedBenchmark(name: 'MMLU', value: 49.9, unit: 'score (5-shot)', source: _qwenCard),
    ],
    officialCapabilities: [
      VerifiedCapability(name: 'Thinking Mode (CoT on/off)', description: 'Soporta modo thinking y no-thinking mediante tokens /think y /no_think.', source: _qwenCard),
    ],
    story: 'Qwen3-0.6B es el modelo más pequeño de la familia Qwen3 con soporte oficial de thinking mode (CoT). En Q8_0 ocupa 640 MB.',
  ),

  'Qwen3.5-0.8B-Q4_K_M': ModelSourceDefinition(
    id: 'Qwen3.5-0.8B-Q4_K_M',
    officialRepo: 'Qwen/Qwen3.5-0.8B',
    quantizedRepo: 'bartowski/Qwen_Qwen3.5-0.8B-GGUF',
    developerName: 'Alibaba Cloud (Qwen Team)',
    baseArchitecture: 'Transformer (RoPE + GQA + SwiGLU, generación 3.5)',
    officialLicense: 'Apache 2.0',
    officialContext: 32768,
    officialVocab: 151936,
    officialParams: 0.8,
    quantizationSource: 'bartowski (Q4_K_M)',
    officialBenchmarks: [
      VerifiedBenchmark(name: 'MMLU', value: 55.2, unit: 'score (5-shot)', source: _qwenCard),
    ],
    officialCapabilities: [
      VerifiedCapability(name: 'Conversación e instrucciones en español', description: 'Post-entrenado para seguimiento de instrucciones y conversación cotidiana breve y coherente.', source: _qwenCard),
      VerifiedCapability(name: 'Tool Calling / Function Calling', description: 'Soporta llamadas estructuradas a herramientas (JSON), compatible con Nano Tool Router.', source: _qwenCard),
    ],
    story: 'Qwen3.5-0.8B es la recomendación principal para Nano Personal: post-entrenado para instrucciones, soporta español conversacional y tool calling, y en Q4_K_M ocupa ~580 MB (< 900 MB RAM).',
  ),
};
