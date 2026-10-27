// deepseek_source_definitions.dart — Metadatos canónicos de la familia DeepSeek AI.
// QUÉ HACE: Declara fuentes y benchmarks verificados para modelos DeepSeek-R1 destilados.
// CÓMO FUNCIONA: Mapa estático de ModelSourceDefinition con datos de Hugging Face y reportes técnicos.
// POR QUÉ: Mantiene la modularidad y asegura código limpio bajo 200 líneas (SOLID).
library;

import '../../domain/model_metadata_entities.dart';
import 'model_source_definition.dart';

const Map<String, ModelSourceDefinition> deepseekSourceDefinitions = {
  'DeepSeek-R1-Distill-Qwen-7B': ModelSourceDefinition(
    id: 'DeepSeek-R1-Distill-Qwen-7B',
    officialRepo: 'deepseek-ai/DeepSeek-R1-Distill-Qwen-7B',
    quantizedRepo: 'unsloth/DeepSeek-R1-Distill-Qwen-7B-GGUF',
    developerName: 'DeepSeek AI',
    baseArchitecture: 'Qwen 2.5 (Decoder Transformer con CoT)',
    officialLicense: 'MIT License',
    officialContext: 131072,
    officialVocab: 152064,
    officialParams: 7.61,
    quantizationSource: 'Unsloth AI (Dynamic GGUF)',
    officialBenchmarks: [
      VerifiedBenchmark(
        name: 'MATH-500',
        value: 92.8,
        unit: 'score (pass@1)',
        datasetVersion: 'Official DeepSeek-R1 Report',
        source: ModelSource(
          label: 'DeepSeek AI Model Card',
          url: 'https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-7B',
          provenance: ModelDataProvenance.official,
        ),
      ),
      VerifiedBenchmark(
        name: 'AIME 2024',
        value: 55.5,
        unit: 'pass@1',
        source: ModelSource(
          label: 'DeepSeek AI Technical Report',
          url: 'https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-7B',
          provenance: ModelDataProvenance.official,
        ),
      ),
      VerifiedBenchmark(
        name: 'LiveCodeBench',
        value: 37.6,
        unit: 'pass@1',
        source: ModelSource(
          label: 'DeepSeek AI Technical Report',
          url: 'https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-7B',
          provenance: ModelDataProvenance.official,
        ),
      ),
      VerifiedBenchmark(
        name: 'MMLU-Redux',
        value: 74.5,
        unit: 'score',
        source: ModelSource(
          label: 'DeepSeek AI Model Card',
          url: 'https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-7B',
          provenance: ModelDataProvenance.official,
        ),
      ),
    ],
    officialCapabilities: [
      VerifiedCapability(
        name: 'Pensamiento Explícito <think>',
        description: 'Cadenas de razonamiento estructuradas paso a paso generadas mediante RL a gran escala.',
        source: ModelSource(
          label: 'DeepSeek Model Card',
          url: 'https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-7B',
          provenance: ModelDataProvenance.official,
        ),
      ),
      VerifiedCapability(
        name: 'Matemáticas y Lógica Formal',
        description: 'Resolución de problemas de nivel competición y deducción matemática.',
        source: ModelSource(
          label: 'DeepSeek Model Card',
          url: 'https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-7B',
          provenance: ModelDataProvenance.official,
        ),
      ),
      VerifiedCapability(
        name: 'Desarrollo de Algoritmos',
        description: 'Generación y corrección de código en múltiples lenguajes.',
        source: ModelSource(
          label: 'DeepSeek Model Card',
          url: 'https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-7B',
          provenance: ModelDataProvenance.official,
        ),
      ),
    ],
    story:
        'DeepSeek-R1-Distill-Qwen-7B es un modelo de razonamiento destilado a partir de DeepSeek-R1 utilizando la arquitectura Qwen 2.5. '
        'Ha sido ajustado mediante aprendizaje por refuerzo para generar cadenas de pensamiento transparentes (<think>...</think>).',
  ),

  'DeepSeek-R1-Distill-Qwen-7B-Q2': ModelSourceDefinition(
    id: 'DeepSeek-R1-Distill-Qwen-7B-Q2',
    officialRepo: 'deepseek-ai/DeepSeek-R1-Distill-Qwen-7B',
    quantizedRepo: 'unsloth/DeepSeek-R1-Distill-Qwen-7B-GGUF',
    developerName: 'DeepSeek AI',
    baseArchitecture: 'Qwen 2.5 (Decoder Transformer con CoT)',
    officialLicense: 'MIT License',
    officialContext: 131072,
    officialVocab: 152064,
    officialParams: 7.61,
    quantizationSource: 'Unsloth AI (Dynamic Q2_K)',
    officialBenchmarks: [
      VerifiedBenchmark(
        name: 'MATH-500',
        value: 92.8,
        unit: 'score (pass@1)',
        source: ModelSource(
          label: 'DeepSeek AI Model Card',
          url: 'https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-7B',
          provenance: ModelDataProvenance.official,
        ),
      ),
      VerifiedBenchmark(
        name: 'MMLU-Redux',
        value: 74.5,
        unit: 'score',
        source: ModelSource(
          label: 'DeepSeek AI Model Card',
          url: 'https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-7B',
          provenance: ModelDataProvenance.official,
        ),
      ),
    ],
    officialCapabilities: [
      VerifiedCapability(
        name: 'Pensamiento Explícito <think>',
        description: 'Cadenas de razonamiento en huella de memoria reducida (Q2_K).',
        source: ModelSource(
          label: 'DeepSeek Model Card',
          url: 'https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-7B',
          provenance: ModelDataProvenance.official,
        ),
      ),
    ],
    story:
        'Versión ultra compacta en cuantización Q2_K de DeepSeek-R1-Distill-7B provista por Unsloth para dispositivos con RAM ajustada.',
  ),
};
