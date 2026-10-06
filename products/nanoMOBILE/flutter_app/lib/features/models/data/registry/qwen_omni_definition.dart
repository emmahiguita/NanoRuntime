// QUÉ: separa capacidades originales del soporte efectivamente conectado en Nano.
// CÓMO: fuentes primarias del desarrollador y del GGUF; sin cifras de rendimiento.
// POR QUÉ: multimodal original no equivale a entradas multimodales disponibles aquí.
import '../../domain/model_metadata_entities.dart';
import 'model_source_definition.dart';

const _omniSource = ModelSource(
  label: 'ggml-org: modalidades GGUF',
  url: 'https://huggingface.co/ggml-org/Qwen2.5-Omni-3B-GGUF',
  provenance: ModelDataProvenance.quantization,
);
const qwenOmniDefinition = <String, ModelSourceDefinition>{
  'Qwen2.5-Omni-3B': ModelSourceDefinition(
    id: 'Qwen2.5-Omni-3B',
    officialRepo: 'Qwen/Qwen2.5-Omni-3B',
    quantizedRepo: 'ggml-org/Qwen2.5-Omni-3B-GGUF',
    developerName: 'Qwen Team',
    baseArchitecture: 'Qwen2.5-Omni Thinker (GGUF qwen2vl)',
    officialLicense: 'Qwen Research',
    officialContext: 32768,
    officialVocab: 151936,
    officialParams: 3,
    quantizationSource: 'ggml-org Q4_K_M',
    officialBenchmarks: [],
    officialCapabilities: [
      VerifiedCapability(
        name: 'GGUF: texto, imagen y audio de entrada',
        description:
            'La distribución GGUF declara estas entradas; Nano conecta '
            'sólo texto. GGUF no admite vídeo ni generación de voz.',
        source: _omniSource,
      ),
    ],
    story:
        'Omni 3B está disponible para descargar como chat de texto. '
        'Inferencia y RAM en este teléfono pendientes de medir; '
        'no incluye el proyector multimodal ni el Talker.',
  ),
};
