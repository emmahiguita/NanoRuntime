// edge_other_definitions.dart — Metadatos canónicos de modelos Llama, Gemma, Liquid AI, Mistral y Phi.
// QUÉ HACE: Registra fuentes canónicas y benchmarks para familias no-Qwen/DeepSeek.
// CÓMO FUNCIONA: Colección inmutable tipada de ModelSourceDefinition para inferencia edge y multimodal.
// POR QUÉ: Mantiene la modularidad y asegura código bajo 200 líneas (SOLID).
library;

import '../../domain/model_metadata_entities.dart';
import 'model_source_definition.dart';

const Map<String, ModelSourceDefinition> edgeOtherDefinitions = {
  'Llama-3.2-1B-Instruct': ModelSourceDefinition(
    id: 'Llama-3.2-1B-Instruct',
    officialRepo: 'meta-llama/Llama-3.2-1B-Instruct',
    quantizedRepo: 'bartowski/Llama-3.2-1B-Instruct-GGUF',
    developerName: 'Meta AI',
    baseArchitecture: 'Decoder Transformer (GQA + RoPE + SwiGLU)',
    officialLicense: 'Llama 3.2 Community License',
    officialContext: 131072,
    officialVocab: 128256,
    officialParams: 1.23,
    quantizationSource: 'Bartowski / llama.cpp (Q4_K_M)',
    officialBenchmarks: [
      VerifiedBenchmark(
        name: 'MMLU',
        value: 49.3,
        unit: 'score (5-shot)',
        source: ModelSource(
          label: 'Meta Llama 3.2 Model Card',
          url: 'https://huggingface.co/meta-llama/Llama-3.2-1B-Instruct',
          provenance: ModelDataProvenance.official,
        ),
      ),
    ],
    officialCapabilities: [
      VerifiedCapability(
        name: 'Contexto Oficial de 128k Tokens',
        description: 'Soporte nativo para lectura y resumen de textos largos en móviles.',
        source: ModelSource(
          label: 'Meta Llama Model Card',
          url: 'https://huggingface.co/meta-llama/Llama-3.2-1B-Instruct',
          provenance: ModelDataProvenance.official,
        ),
      ),
    ],
    story: 'Llama-3.2-1B-Instruct de Meta AI es un modelo optimizado para tareas periféricas con bajo consumo de memoria.',
  ),

  'Gemma-2-27B-IT-Q2': ModelSourceDefinition(
    id: 'Gemma-2-27B-IT-Q2',
    officialRepo: 'google/gemma-2-27b-it',
    quantizedRepo: 'bartowski/gemma-2-27b-it-GGUF',
    developerName: 'Google DeepMind',
    baseArchitecture: 'Decoder Transformer (SWA + Dual RMSNorm + GeGLU)',
    officialLicense: 'Gemma Terms of Use',
    officialContext: 8192,
    officialVocab: 256000,
    officialParams: 27.2,
    quantizationSource: 'Bartowski / llama.cpp (Q2_K)',
    officialBenchmarks: [],
    officialCapabilities: [],
    story: 'Gemma-2-27B-IT de Google DeepMind ofrece capacidades de razonamiento profundo.',
  ),

  'Ministral-3-3B-Instruct-2512': ModelSourceDefinition(
    id: 'Ministral-3-3B-Instruct-2512',
    officialRepo: 'mistralai/Ministral-3-3B-Instruct-2512',
    quantizedRepo: 'mistralai/Ministral-3-3B-Instruct-2512-GGUF',
    developerName: 'Mistral AI',
    baseArchitecture: 'Mistral 3 (mistral3)',
    officialLicense: 'Apache-2.0',
    officialContext: 262144,
    officialVocab: 131072,
    officialParams: 3.4,
    quantizationSource: 'Mistral AI / llama.cpp (Q4_K_M)',
    officialBenchmarks: [],
    officialCapabilities: [],
    story: 'Modelo edge de Mistral AI con soporte de generación de texto y ventana extensa.',
  ),

  'Phi-3.5-mini-Instruct-3.8B': ModelSourceDefinition(
    id: 'Phi-3.5-mini-Instruct-3.8B',
    officialRepo: 'microsoft/Phi-3.5-mini-instruct',
    quantizedRepo: 'bartowski/Phi-3.5-mini-instruct-GGUF',
    developerName: 'Microsoft Research',
    baseArchitecture: 'Decoder Transformer (Su-scaled RoPE + Flash Attention)',
    officialLicense: 'MIT License',
    officialContext: 131072,
    officialVocab: 32064,
    officialParams: 3.82,
    quantizationSource: 'Bartowski / llama.cpp (Q4_K_M)',
    officialBenchmarks: [
      VerifiedBenchmark(
        name: 'MMLU',
        value: 69.0,
        unit: 'score (5-shot)',
        source: ModelSource(
          label: 'Microsoft Phi-3.5 Model Card',
          url: 'https://huggingface.co/microsoft/Phi-3.5-mini-instruct',
          provenance: ModelDataProvenance.official,
        ),
      ),
    ],
    officialCapabilities: [
      VerifiedCapability(
        name: 'Datos Sintéticos Curados',
        description: 'Entrenado con material sintético de alta densidad de conocimiento.',
        source: ModelSource(
          label: 'Microsoft Model Card',
          url: 'https://huggingface.co/microsoft/Phi-3.5-mini-instruct',
          provenance: ModelDataProvenance.official,
        ),
      ),
    ],
    story: 'Phi-3.5-mini-Instruct (3.8B) es un modelo compacto de Microsoft Research con alta capacidad de razonamiento formal.',
  ),

  'LFM2.5-350M-Q4_K_M': ModelSourceDefinition(
    id: 'LFM2.5-350M-Q4_K_M',
    officialRepo: 'LiquidAI/LFM2.5-350M',
    quantizedRepo: 'LiquidAI/LFM2.5-350M-GGUF',
    developerName: 'Liquid AI',
    baseArchitecture: 'LFM2 (Conv corta + Atención, no Transformer puro)',
    officialLicense: 'LFM Open License v1.0',
    officialContext: 32768,
    officialVocab: 0,
    officialParams: 0.35,
    quantizationSource: 'Liquid AI Official GGUF',
    officialBenchmarks: [
      VerifiedBenchmark(
        name: 'MMLU',
        value: 42.1,
        unit: 'score (5-shot)',
        source: ModelSource(
          label: 'LFM2.5 Model Card',
          url: 'https://huggingface.co/LiquidAI/LFM2.5-350M',
          provenance: ModelDataProvenance.official,
        ),
      ),
    ],
    officialCapabilities: [
      VerifiedCapability(
        name: 'Arquitectura Edge-First (Conv + Atención)',
        description: 'Reduce el coste de inferencia en CPU para contextos móviles (<500 MB RAM).',
        source: ModelSource(
          label: 'LFM2.5 Model Card',
          url: 'https://huggingface.co/LiquidAI/LFM2.5-350M',
          provenance: ModelDataProvenance.official,
        ),
      ),
    ],
    story: 'LFM2.5-350M es el modelo más ligero de Liquid AI, diseñado para ejecución edge sin GPU.',
  ),

  'LFM2.5-350M-QAD': ModelSourceDefinition(
    id: 'LFM2.5-350M-QAD',
    officialRepo: 'LiquidAI/LFM2.5-350M',
    quantizedRepo: 'LiquidAI/LFM2.5-350M-GGUF',
    developerName: 'Liquid AI',
    baseArchitecture: 'LFM2 (Conv corta + Atención, no Transformer puro)',
    officialLicense: 'LFM Open License v1.0',
    officialContext: 32768,
    officialVocab: 0,
    officialParams: 0.35,
    quantizationSource: 'Liquid AI Official GGUF (QAD calibrado)',
    officialBenchmarks: [],
    officialCapabilities: [
      VerifiedCapability(
        name: 'QAD: Cuantización Calibrada',
        description: 'Usa datos de activación para minimizar la pérdida de fidelidad en 219 MB.',
        source: ModelSource(
          label: 'LFM2.5-350M-GGUF README',
          url: 'https://huggingface.co/LiquidAI/LFM2.5-350M-GGUF',
          provenance: ModelDataProvenance.official,
        ),
      ),
    ],
    story: 'Variante QAD de LFM2.5-350M con calibración de activación para máxima fidelidad en 219 MB.',
  ),
};
