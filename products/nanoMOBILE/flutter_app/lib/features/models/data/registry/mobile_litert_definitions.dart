// Describe las alternativas móviles instalables sin atribuirles pruebas del OPPO.
// Separa el autor del modelo de la comunidad que preparó el paquete LiteRT.
import '../../domain/model_metadata_entities.dart';
import 'model_source_definition.dart';

const Map<String, ModelSourceDefinition> mobileLiteRtDefinitions = {
  // Los 32768 tokens son del modelo base; este archivo lleva un KV de 4096.
  'LFM2.5-230M (LiteRT)': ModelSourceDefinition(
    id: 'LFM2.5-230M (LiteRT)',
    officialRepo: 'LiquidAI/LFM2.5-230M',
    quantizedRepo: 'litert-community/LFM2.5-230M',
    developerName: 'Liquid AI',
    baseArchitecture: 'LFM2: convoluciones cortas y atención GQA',
    officialLicense: 'LFM Open License v1.0',
    officialContext: 32768,
    officialVocab: 65536,
    officialParams: 0.23,
    quantizationSource: 'LiteRT Community (conversión INT8)',
    officialBenchmarks: [],
    officialCapabilities: [
      VerifiedCapability(
        name: 'Extracción de datos y tareas breves',
        description:
            'Modelo de texto compacto; no se recomienda para '
            'matemáticas avanzadas ni generación extensa de código.',
        source: ModelSource(
          label: 'Liquid AI: ficha del modelo',
          url: 'https://huggingface.co/LiquidAI/LFM2.5-230M',
          provenance: ModelDataProvenance.official,
        ),
      ),
    ],
    story:
        'Conversión comunitaria INT8 de Liquid AI con contexto de paquete '
        'de 4096 tokens. Texto mediante LiteRT-LM; rendimiento sin medir en '
        'el OPPO. La RAM mostrada es una estimación.',
  ),
  // La ficha exacta evita heredar cifras de los DeepSeek 7B ya registrados.
  'DeepSeek-R1-Distill-Qwen-1.5B (LiteRT)': ModelSourceDefinition(
    id: 'DeepSeek-R1-Distill-Qwen-1.5B (LiteRT)',
    officialRepo: 'deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B',
    quantizedRepo: 'litert-community/DeepSeek-R1-Distill-Qwen-1.5B',
    developerName: 'DeepSeek AI',
    baseArchitecture: 'Qwen 2.5 destilado con DeepSeek-R1',
    officialLicense: 'MIT',
    officialContext: 131072,
    officialVocab: 151936,
    officialParams: 1.5,
    quantizationSource: 'LiteRT Community (Q8)',
    officialBenchmarks: [],
    officialCapabilities: [],
    story:
        'Alternativa de razonamiento en texto, con el paquete Q8 de '
        '4096 tokens publicado para Google AI Edge Gallery. Puede generar '
        'respuestas largas. Rendimiento sin medir en el OPPO y RAM estimada.',
  ),
};
