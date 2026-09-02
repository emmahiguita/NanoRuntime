/// Registro de fuentes canónicas y metadatos verificados por modelo.
library;

import '../domain/model_metadata_entities.dart';

class ModelSourceDefinition {
  final String id;
  final String officialRepo;
  final String quantizedRepo;
  final String developerName;
  final String baseArchitecture;
  final String officialLicense;
  final int officialContext;
  final int officialVocab;
  final double officialParams;
  final String quantizationSource;
  final List<VerifiedBenchmark> officialBenchmarks;
  final List<VerifiedCapability> officialCapabilities;
  final String story;

  const ModelSourceDefinition({
    required this.id,
    required this.officialRepo,
    required this.quantizedRepo,
    required this.developerName,
    required this.baseArchitecture,
    required this.officialLicense,
    required this.officialContext,
    required this.officialVocab,
    required this.officialParams,
    required this.quantizationSource,
    required this.officialBenchmarks,
    required this.officialCapabilities,
    required this.story,
  });
}

abstract final class ModelSourceRegistry {
  static const Map<String, ModelSourceDefinition> registry = {
    // -------------------------------------------------------------
    // DEEPSEEK
    // -------------------------------------------------------------
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
            url:
                'https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-7B',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedBenchmark(
          name: 'AIME 2024',
          value: 55.5,
          unit: 'pass@1',
          source: ModelSource(
            label: 'DeepSeek AI Technical Report',
            url:
                'https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-7B',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedBenchmark(
          name: 'LiveCodeBench',
          value: 37.6,
          unit: 'pass@1',
          source: ModelSource(
            label: 'DeepSeek AI Technical Report',
            url:
                'https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-7B',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedBenchmark(
          name: 'MMLU-Redux',
          value: 74.5,
          unit: 'score',
          source: ModelSource(
            label: 'DeepSeek AI Model Card',
            url:
                'https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-7B',
            provenance: ModelDataProvenance.official,
          ),
        ),
      ],
      officialCapabilities: [
        VerifiedCapability(
          name: 'Pensamiento Explícito <think>',
          description:
              'Cadenas de razonamiento estructuradas paso a paso generadas mediante RL a gran escala.',
          source: ModelSource(
            label: 'DeepSeek Model Card',
            url:
                'https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-7B',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedCapability(
          name: 'Matemáticas y Lógica Formal',
          description:
              'Resolución de problemas de nivel competición y deducción matemática.',
          source: ModelSource(
            label: 'DeepSeek Model Card',
            url:
                'https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-7B',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedCapability(
          name: 'Desarrollo de Algoritmos',
          description:
              'Generación y corrección de código en múltiples lenguajes.',
          source: ModelSource(
            label: 'DeepSeek Model Card',
            url:
                'https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-7B',
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
            url:
                'https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-7B',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedBenchmark(
          name: 'MMLU-Redux',
          value: 74.5,
          unit: 'score',
          source: ModelSource(
            label: 'DeepSeek AI Model Card',
            url:
                'https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-7B',
            provenance: ModelDataProvenance.official,
          ),
        ),
      ],
      officialCapabilities: [
        VerifiedCapability(
          name: 'Pensamiento Explícito <think>',
          description:
              'Cadenas de razonamiento en huella de memoria reducida (Q2_K).',
          source: ModelSource(
            label: 'DeepSeek Model Card',
            url:
                'https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-7B',
            provenance: ModelDataProvenance.official,
          ),
        ),
      ],
      story:
          'Versión ultra compacta en cuantización Q2_K de DeepSeek-R1-Distill-7B provista por Unsloth para dispositivos con RAM ajustada.',
    ),

    // -------------------------------------------------------------
    // QWEN 2.5
    // -------------------------------------------------------------
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
        VerifiedBenchmark(
          name: 'MMLU',
          value: 47.4,
          unit: 'score (5-shot)',
          source: ModelSource(
            label: 'Qwen 2.5 Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedBenchmark(
          name: 'GSM8K',
          value: 43.1,
          unit: 'score (4-shot)',
          source: ModelSource(
            label: 'Qwen 2.5 Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
      ],
      officialCapabilities: [
        VerifiedCapability(
          name: 'Inferencia Ultrarrápida Móvil',
          description:
              'Optimizado para CPU móvil ARM con latencia mínima (<1 GB RAM).',
          source: ModelSource(
            label: 'Qwen Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedCapability(
          name: 'Soporte Multilingüe (29+ idiomas)',
          description:
              'Capacidad de comprensión y generación en español, inglés, chino, etc.',
          source: ModelSource(
            label: 'Qwen Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
      ],
      story:
          'Qwen2.5-0.5B-Instruct es el modelo más ligero de la familia Qwen2.5, ideal para tareas directas, clasificación de texto y respuestas rápidas en dispositivos móviles.',
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
        VerifiedBenchmark(
          name: 'MMLU',
          value: 60.9,
          unit: 'score (5-shot)',
          source: ModelSource(
            label: 'Qwen 2.5 Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedBenchmark(
          name: 'GSM8K',
          value: 68.5,
          unit: 'score (4-shot)',
          source: ModelSource(
            label: 'Qwen 2.5 Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedBenchmark(
          name: 'HumanEval',
          value: 53.0,
          unit: 'pass@1',
          source: ModelSource(
            label: 'Qwen 2.5 Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
      ],
      officialCapabilities: [
        VerifiedCapability(
          name: 'Diálogo Multiturno & Asistente',
          description:
              'Excelente coherencia conversacional en teléfonos de 4GB a 6GB RAM.',
          source: ModelSource(
            label: 'Qwen Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedCapability(
          name: 'Salida JSON Estructurada',
          description:
              'Soporte de formato estructurado y llamadas a herramientas.',
          source: ModelSource(
            label: 'Qwen Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
      ],
      story:
          'Qwen2.5-1.5B-Instruct ofrece un equilibrio óptimo entre calidad lingüística, precisión matemática y velocidad de ejecución local en smartphones.',
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
        VerifiedBenchmark(
          name: 'HumanEval',
          value: 70.1,
          unit: 'pass@1',
          source: ModelSource(
            label: 'Qwen 2.5 Coder Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedBenchmark(
          name: 'MBPP',
          value: 73.3,
          unit: 'pass@1',
          source: ModelSource(
            label: 'Qwen 2.5 Coder Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedBenchmark(
          name: 'MultiPL-E (Media)',
          value: 58.4,
          unit: 'pass@1',
          source: ModelSource(
            label: 'Qwen 2.5 Coder Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
      ],
      officialCapabilities: [
        VerifiedCapability(
          name: 'Generación y Completado de Código',
          description:
              'Especializado en más de 92 lenguajes de programación (Dart, Python, JS, C++, Rust).',
          source: ModelSource(
            label: 'Qwen Coder Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedCapability(
          name: 'Depuración y Corrección de Sintaxis',
          description:
              'Análisis de errores y refactorización guiada por instrucciones.',
          source: ModelSource(
            label: 'Qwen Coder Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
      ],
      story:
          'Qwen2.5-Coder-1.5B-Instruct es un modelo especializado en desarrollo de software, entrenado con 5.5 billones de tokens de código fuente.',
    ),

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
        VerifiedBenchmark(
          name: 'MMLU',
          value: 68.4,
          unit: 'score (5-shot)',
          source: ModelSource(
            label: 'Qwen 2.5 Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedBenchmark(
          name: 'GSM8K',
          value: 79.2,
          unit: 'score (4-shot)',
          source: ModelSource(
            label: 'Qwen 2.5 Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedBenchmark(
          name: 'HumanEval',
          value: 62.8,
          unit: 'pass@1',
          source: ModelSource(
            label: 'Qwen 2.5 Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
      ],
      officialCapabilities: [
        VerifiedCapability(
          name: 'Comprensión de Instrucciones Complejas',
          description:
              'Capacidad de resumen, redacción y análisis de textos extensos.',
          source: ModelSource(
            label: 'Qwen Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedCapability(
          name: 'Tool Use & Function Calling',
          description:
              'Llamada estructurada a herramientas externas mediante JSON.',
          source: ModelSource(
            label: 'Qwen Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
      ],
      story:
          'Qwen2.5-3B-Instruct es la opción insignia para smartphones modernos con 6GB+ de RAM, con rendimiento comparable a modelos de 7B de generaciones previas.',
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
        VerifiedBenchmark(
          name: 'MMLU',
          value: 68.4,
          unit: 'score (5-shot)',
          source: ModelSource(
            label: 'Qwen 2.5 Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedBenchmark(
          name: 'GSM8K',
          value: 79.2,
          unit: 'score (4-shot)',
          source: ModelSource(
            label: 'Qwen 2.5 Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
      ],
      officialCapabilities: [
        VerifiedCapability(
          name: 'Inferencia Balanceada (2.09 GB)',
          description:
              'Cuantización de peso medio de 4 bits con baja degradación de perplejidad.',
          source: ModelSource(
            label: 'Qwen Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
      ],
      story:
          'Variante cuantizada Q4_K_M de Qwen2.5-3B-Instruct para máxima eficiencia en uso de memoria RAM móvil.',
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
        VerifiedBenchmark(
          name: 'MMLU',
          value: 74.2,
          unit: 'score (5-shot)',
          source: ModelSource(
            label: 'Qwen 2.5 Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-7B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedBenchmark(
          name: 'GSM8K',
          value: 86.4,
          unit: 'score (4-shot)',
          source: ModelSource(
            label: 'Qwen 2.5 Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-7B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedBenchmark(
          name: 'MATH',
          value: 50.2,
          unit: 'score (4-shot)',
          source: ModelSource(
            label: 'Qwen 2.5 Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-7B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedBenchmark(
          name: 'HumanEval',
          value: 79.9,
          unit: 'pass@1',
          source: ModelSource(
            label: 'Qwen 2.5 Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-7B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
      ],
      officialCapabilities: [
        VerifiedCapability(
          name: 'Contexto Extenso de 128k Tokens',
          description:
              'Capacidad nativa de procesamiento de documentos y libros extensos.',
          source: ModelSource(
            label: 'Qwen Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-7B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedCapability(
          name: 'Razonamiento Matemático Avanzado',
          description:
              'Resolución de problemas de lógica y cálculo paso a paso.',
          source: ModelSource(
            label: 'Qwen Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-7B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
      ],
      story:
          'Qwen2.5-7B-Instruct es el modelo de referencia en la categoría de 7B parámetros a nivel mundial en benchmarks de código, matemáticas y razonamiento.',
    ),

    'Qwen3.5-4B': ModelSourceDefinition(
      id: 'Qwen3.5-4B',
      officialRepo: 'Qwen/Qwen2.5-3B-Instruct',
      quantizedRepo: 'unsloth/Qwen3.5-4B-GGUF',
      developerName: 'Alibaba Cloud (Tongyi Lab)',
      baseArchitecture: 'Hybrid Transformer (Linear Attention + GQA)',
      officialLicense: 'Apache 2.0',
      officialContext: 131072,
      officialVocab: 152064,
      officialParams: 4.15,
      quantizationSource: 'Unsloth AI (Dynamic Q4_K_S)',
      officialBenchmarks: [
        VerifiedBenchmark(
          name: 'MMLU',
          value: 70.8,
          unit: 'score',
          source: ModelSource(
            label: 'Model Card',
            url: 'https://huggingface.co/unsloth/Qwen3.5-4B-GGUF',
            provenance: ModelDataProvenance.huggingFace,
          ),
        ),
      ],
      officialCapabilities: [
        VerifiedCapability(
          name: 'Atención Híbrida Eficiente',
          description: 'Reduce el consumo de memoria en contextos largos.',
          source: ModelSource(
            label: 'Model Card',
            url: 'https://huggingface.co/unsloth/Qwen3.5-4B-GGUF',
            provenance: ModelDataProvenance.huggingFace,
          ),
        ),
      ],
      story:
          'Variante moderna con optimizaciones de inferencia rápida y bajo consumo de memoria distribuida por Unsloth.',
    ),

    'Qwen3.8-2B-Q4_K_M': ModelSourceDefinition(
      id: 'Qwen3.8-2B-Q4_K_M',
      officialRepo: 'empero-ai/Qwen3.8-2B',
      quantizedRepo: 'empero-ai/Qwen3.8-2B-GGUF',
      developerName: 'Empero AI (Distilled from Qwen3.8 2.4T A95B)',
      baseArchitecture:
          'Qwen3.5 (Hybrid Gated DeltaNet + Multi-Head Attention)',
      officialLicense: 'Apache 2.0',
      officialContext: 262144,
      officialVocab: 152064,
      officialParams: 2.27,
      quantizationSource: 'Empero AI Official (Q4_K_M)',
      officialBenchmarks: [
        VerifiedBenchmark(
          name: 'MMLU (CoT, 57 subjects)',
          value: 54.8,
          unit: 'score (CoT)',
          source: ModelSource(
            label: 'Empero AI Model Card',
            url: 'https://huggingface.co/empero-ai/Qwen3.8-2B-GGUF',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedBenchmark(
          name: 'GSM8K (CoT)',
          value: 64.0,
          unit: 'score (CoT)',
          source: ModelSource(
            label: 'Empero AI Model Card',
            url: 'https://huggingface.co/empero-ai/Qwen3.8-2B-GGUF',
            provenance: ModelDataProvenance.official,
          ),
        ),
      ],
      officialCapabilities: [
        VerifiedCapability(
          name: 'Destilación Completa de Parámetros',
          description:
              'Destilado a partir de Qwen3.8 2.4T A95B entrenado en ~30.000 trazas de razonamiento curricular.',
          source: ModelSource(
            label: 'Empero AI Model Card',
            url: 'https://huggingface.co/empero-ai/Qwen3.8-2B-GGUF',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedCapability(
          name: 'Arquitectura Híbrida Gated DeltaNet',
          description:
              'Tres capas Gated DeltaNet por cada capa de atención completa para una inferencia ultra veloz en móviles.',
          source: ModelSource(
            label: 'Empero AI Model Card',
            url: 'https://huggingface.co/empero-ai/Qwen3.8-2B-GGUF',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedCapability(
          name: 'Ventana de Contexto Nativa de 256k Tokens',
          description:
              '262,144 tokens de contexto para análisis documental completo y razonamiento profundo con bloques <think>.',
          source: ModelSource(
            label: 'Empero AI Model Card',
            url: 'https://huggingface.co/empero-ai/Qwen3.8-2B-GGUF',
            provenance: ModelDataProvenance.official,
          ),
        ),
      ],
      story:
          'Qwen3.8-2B es una destilación directa de Qwen3.8 2.4T A95B en la arquitectura compacta híbrida de 2B parámetros, optimizada para razonamiento CoT y alta velocidad en dispositivos móviles.',
    ),

    'Qwen3.8-2B-Q8_0': ModelSourceDefinition(
      id: 'Qwen3.8-2B-Q8_0',
      officialRepo: 'empero-ai/Qwen3.8-2B',
      quantizedRepo: 'empero-ai/Qwen3.8-2B-GGUF',
      developerName: 'Empero AI (Distilled from Qwen3.8 2.4T A95B)',
      baseArchitecture:
          'Qwen3.5 (Hybrid Gated DeltaNet + Multi-Head Attention)',
      officialLicense: 'Apache 2.0',
      officialContext: 262144,
      officialVocab: 152064,
      officialParams: 2.27,
      quantizationSource: 'Empero AI Official (Q8_0)',
      officialBenchmarks: [
        VerifiedBenchmark(
          name: 'MMLU (CoT, 57 subjects)',
          value: 54.8,
          unit: 'score (CoT)',
          source: ModelSource(
            label: 'Empero AI Model Card',
            url: 'https://huggingface.co/empero-ai/Qwen3.8-2B-GGUF',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedBenchmark(
          name: 'GSM8K (CoT)',
          value: 64.0,
          unit: 'score (CoT)',
          source: ModelSource(
            label: 'Empero AI Model Card',
            url: 'https://huggingface.co/empero-ai/Qwen3.8-2B-GGUF',
            provenance: ModelDataProvenance.official,
          ),
        ),
      ],
      officialCapabilities: [
        VerifiedCapability(
          name: 'Destilación Completa de Parámetros',
          description:
              'Destilado a partir de Qwen3.8 2.4T A95B entrenado en ~30.000 trazas de razonamiento curricular.',
          source: ModelSource(
            label: 'Empero AI Model Card',
            url: 'https://huggingface.co/empero-ai/Qwen3.8-2B-GGUF',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedCapability(
          name: 'Cuantización de Alta Precisión Q8_0',
          description:
              'Preservación de pesos con precisión casi sin pérdidas para máxima coherencia de razonamiento.',
          source: ModelSource(
            label: 'Empero AI Model Card',
            url: 'https://huggingface.co/empero-ai/Qwen3.8-2B-GGUF',
            provenance: ModelDataProvenance.official,
          ),
        ),
      ],
      story:
          'Variante Q8_0 de Qwen3.8-2B con máxima precisión y fidelidad de razonamiento CoT.',
    ),

    'Qwen3.5-4B-Q4_K_M': ModelSourceDefinition(
      id: 'Qwen3.5-4B-Q4_K_M',
      officialRepo: 'Qwen/Qwen2.5-3B-Instruct',
      quantizedRepo: 'unsloth/Qwen3.5-4B-GGUF',
      developerName: 'Alibaba Cloud (Tongyi Lab)',
      baseArchitecture: 'Hybrid Transformer (Linear Attention + GQA)',
      officialLicense: 'Apache 2.0',
      officialContext: 131072,
      officialVocab: 152064,
      officialParams: 4.15,
      quantizationSource: 'Unsloth AI (Dynamic Q4_K_M)',
      officialBenchmarks: [
        VerifiedBenchmark(
          name: 'MMLU',
          value: 70.8,
          unit: 'score',
          source: ModelSource(
            label: 'Model Card',
            url: 'https://huggingface.co/unsloth/Qwen3.5-4B-GGUF',
            provenance: ModelDataProvenance.huggingFace,
          ),
        ),
      ],
      officialCapabilities: [
        VerifiedCapability(
          name: 'Atención Híbrida Eficiente',
          description:
              'Reduce el consumo de memoria en contextos largos con cuantización balanceada.',
          source: ModelSource(
            label: 'Model Card',
            url: 'https://huggingface.co/unsloth/Qwen3.5-4B-GGUF',
            provenance: ModelDataProvenance.huggingFace,
          ),
        ),
      ],
      story:
          'Variante con cuantización Q4_K_M para mayor fidelidad en respuestas complejas.',
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
        VerifiedBenchmark(
          name: 'MMLU',
          value: 79.7,
          unit: 'score (5-shot)',
          source: ModelSource(
            label: 'Qwen 2.5 Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-14B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedBenchmark(
          name: 'GSM8K',
          value: 90.1,
          unit: 'score (4-shot)',
          source: ModelSource(
            label: 'Qwen 2.5 Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-14B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedBenchmark(
          name: 'MATH',
          value: 58.0,
          unit: 'score (4-shot)',
          source: ModelSource(
            label: 'Qwen 2.5 Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-14B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
      ],
      officialCapabilities: [
        VerifiedCapability(
          name: 'Nivel Experto en Razonamiento',
          description:
              'Capacidad cercana a modelos de 70B en matemáticas y redacción técnica.',
          source: ModelSource(
            label: 'Qwen Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-14B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
      ],
      story:
          'Qwen2.5-14B-Instruct es un modelo de alta capacidad para smartphones de gama alta con 12GB+ de RAM.',
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
        VerifiedBenchmark(
          name: 'MMLU',
          value: 79.7,
          unit: 'score (5-shot base)',
          source: ModelSource(
            label: 'Qwen Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-14B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
      ],
      officialCapabilities: [
        VerifiedCapability(
          name: '14B en 5.8 GB de Espacio',
          description:
              'Permite ejecutar un modelo de 14B con menor consumo de RAM.',
          source: ModelSource(
            label: 'Qwen Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-14B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
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
        VerifiedBenchmark(
          name: 'MMLU',
          value: 82.5,
          unit: 'score',
          source: ModelSource(
            label: 'Model Card',
            url: 'https://huggingface.co/bartowski/Qwen3.8-27B-GGUF',
            provenance: ModelDataProvenance.huggingFace,
          ),
        ),
      ],
      officialCapabilities: [
        VerifiedCapability(
          name: 'Gran Escala en Móvil',
          description:
              'Modelo de 27B comprimido a Q2_K para dispositivos con 16GB RAM.',
          source: ModelSource(
            label: 'Model Card',
            url: 'https://huggingface.co/bartowski/Qwen3.8-27B-GGUF',
            provenance: ModelDataProvenance.quantization,
          ),
        ),
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
        VerifiedBenchmark(
          name: 'MMLU',
          value: 82.5,
          unit: 'score',
          source: ModelSource(
            label: 'Model Card',
            url: 'https://huggingface.co/bartowski/Qwen3.8-27B-GGUF',
            provenance: ModelDataProvenance.huggingFace,
          ),
        ),
      ],
      officialCapabilities: [
        VerifiedCapability(
          name: 'Alta Fidelidad (17.7 GB)',
          description:
              'Para estaciones de trabajo y dispositivos con 20GB+ RAM disponible.',
          source: ModelSource(
            label: 'Model Card',
            url: 'https://huggingface.co/bartowski/Qwen3.8-27B-GGUF',
            provenance: ModelDataProvenance.quantization,
          ),
        ),
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
      officialBenchmarks: [
        VerifiedBenchmark(
          name: 'MMLU',
          value: 83.1,
          unit: 'score (5-shot)',
          source: ModelSource(
            label: 'Qwen 2.5 Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-32B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedBenchmark(
          name: 'GSM8K',
          value: 91.6,
          unit: 'score (4-shot)',
          source: ModelSource(
            label: 'Qwen 2.5 Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-32B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
      ],
      officialCapabilities: [
        VerifiedCapability(
          name: 'Capacidad Insignia 32B',
          description:
              'Rendimiento de vanguardia en razonamiento formal y matemáticas.',
          source: ModelSource(
            label: 'Qwen Model Card',
            url: 'https://huggingface.co/Qwen/Qwen2.5-32B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
      ],
      story:
          'Qwen2.5-32B-Instruct es el modelo más potente de la serie Qwen2.5 disponible para inferencia local.',
    ),

    // -------------------------------------------------------------
    // LLAMA 3.2
    // -------------------------------------------------------------
    'Llama-3.2-1B-Instruct': ModelSourceDefinition(
      id: 'Llama-3.2-1B-Instruct',
      officialRepo: 'meta-llama/Llama-3.2-1B-Instruct',
      quantizedRepo: 'bartowski/Llama-3.2-1B-Instruct-GGUF',
      developerName: 'Meta AI',
      baseArchitecture: 'Transformer (RoPE + GQA + SwiGLU)',
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
        VerifiedBenchmark(
          name: 'GSM8K',
          value: 44.4,
          unit: 'score (8-shot CoT)',
          source: ModelSource(
            label: 'Meta Llama 3.2 Model Card',
            url: 'https://huggingface.co/meta-llama/Llama-3.2-1B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedBenchmark(
          name: 'HumanEval',
          value: 37.2,
          unit: 'pass@1',
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
          description:
              'Soporte nativo para lectura y resumen de textos largos en dispositivos móviles.',
          source: ModelSource(
            label: 'Meta Llama Model Card',
            url: 'https://huggingface.co/meta-llama/Llama-3.2-1B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedCapability(
          name: 'Asistente Multilingüe Ligero',
          description:
              'Optimizado para diálogo fluido en inglés, español, alemán, francés, portugués, etc.',
          source: ModelSource(
            label: 'Meta Llama Model Card',
            url: 'https://huggingface.co/meta-llama/Llama-3.2-1B-Instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
      ],
      story:
          'Llama-3.2-1B-Instruct de Meta AI es un modelo optimizado para tareas periféricas (on-device) con bajo consumo de memoria y ventana de 128k tokens.',
    ),

    // -------------------------------------------------------------
    // GEMMA 2
    // -------------------------------------------------------------
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
      officialBenchmarks: [
        VerifiedBenchmark(
          name: 'MMLU',
          value: 75.2,
          unit: 'score (5-shot)',
          source: ModelSource(
            label: 'Google Gemma 2 Model Card',
            url: 'https://huggingface.co/google/gemma-2-27b-it',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedBenchmark(
          name: 'GSM8K',
          value: 74.0,
          unit: 'score (CoT)',
          source: ModelSource(
            label: 'Google Gemma 2 Model Card',
            url: 'https://huggingface.co/google/gemma-2-27b-it',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedBenchmark(
          name: 'HumanEval',
          value: 51.8,
          unit: 'pass@1',
          source: ModelSource(
            label: 'Google Gemma 2 Model Card',
            url: 'https://huggingface.co/google/gemma-2-27b-it',
            provenance: ModelDataProvenance.official,
          ),
        ),
      ],
      officialCapabilities: [
        VerifiedCapability(
          name: 'Destilación de Gemini',
          description:
              'Entrenado mediante destilación de conocimiento de modelos fundacionales masivos de Google.',
          source: ModelSource(
            label: 'Google Model Card',
            url: 'https://huggingface.co/google/gemma-2-27b-it',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedCapability(
          name: 'Sliding Window Attention (SWA)',
          description:
              'Atención de ventana deslizante intercalada para optimizar uso de caché KV.',
          source: ModelSource(
            label: 'Google Model Card',
            url: 'https://huggingface.co/google/gemma-2-27b-it',
            provenance: ModelDataProvenance.official,
          ),
        ),
      ],
      story:
          'Gemma-2-27B-IT de Google DeepMind ofrece capacidades de razonamiento profundo y redacción analítica de nivel institucional.',
    ),

    // -------------------------------------------------------------
    // PHI-3.5
    // -------------------------------------------------------------
    'Phi-3.5-mini-Instruct-3.8B': ModelSourceDefinition(
      id: 'Phi-3.5-mini-Instruct-3.8B',
      officialRepo: 'microsoft/Phi-3.5-mini-instruct',
      quantizedRepo: 'bartowski/Phi-3.5-mini-instruct-GGUF',
      developerName: 'Microsoft Research',
      baseArchitecture:
          'Decoder Transformer (Su-scaled RoPE + Flash Attention)',
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
        VerifiedBenchmark(
          name: 'GSM8K',
          value: 84.9,
          unit: 'score (0-shot CoT)',
          source: ModelSource(
            label: 'Microsoft Phi-3.5 Model Card',
            url: 'https://huggingface.co/microsoft/Phi-3.5-mini-instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedBenchmark(
          name: 'HumanEval',
          value: 62.8,
          unit: 'pass@1',
          source: ModelSource(
            label: 'Microsoft Phi-3.5 Model Card',
            url: 'https://huggingface.co/microsoft/Phi-3.5-mini-instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
      ],
      officialCapabilities: [
        VerifiedCapability(
          name: 'Datos Sintéticos Curados ("Textbooks Are All You Need")',
          description:
              'Entrenado con material sintético de alta densidad de conocimiento.',
          source: ModelSource(
            label: 'Microsoft Model Card',
            url: 'https://huggingface.co/microsoft/Phi-3.5-mini-instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
        VerifiedCapability(
          name: 'Contexto de 128k Tokens',
          description:
              'Soporte nativo de ventana de contexto extensa para razonamiento multi-paso.',
          source: ModelSource(
            label: 'Microsoft Model Card',
            url: 'https://huggingface.co/microsoft/Phi-3.5-mini-instruct',
            provenance: ModelDataProvenance.official,
          ),
        ),
      ],
      story:
          'Phi-3.5-mini-Instruct (3.8B) es un modelo compacto de Microsoft Research con capacidades de razonamiento formal superiores a muchos modelos del doble de su tamaño.',
    ),
  };

  static ModelSourceDefinition definitionFor(String name) {
    if (registry.containsKey(name)) {
      return registry[name]!;
    }
    // Búsqueda por coincidencia parcial
    final lower = name.toLowerCase();
    for (final entry in registry.entries) {
      if (lower.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    // Fallback estándar
    return registry['Qwen2.5-3B-Instruct']!;
  }
}
