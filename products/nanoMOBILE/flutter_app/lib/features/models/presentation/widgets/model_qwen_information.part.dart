// QUÉ: describe las variantes Qwen conocidas con fuentes del publicador original.
// CÓMO: separa la capacidad publicada de la ruta realmente conectada en Nano.
// POR QUÉ: compartir marca no convierte un ASR o una conversión en chat multimodal.
part of 'model_catalog_types.dart';

extension ModelQwenInformation on UnifiedModelItem {
  /// Fuente del modelo original; la descarga conserva su repositorio de conversión.
  String? get qwenOriginalSource {
    if (!isCatalog || company != 'Alibaba Qwen') return null;
    final n = name;
    String? model;
    if (n.startsWith('Qwen3-0.6B-')) model = 'Qwen3-0.6B';
    if (n.startsWith('Qwen2.5-0.5B-Instruct')) model = 'Qwen2.5-0.5B-Instruct';
    if (n.startsWith('Qwen2.5-1.5B-Instruct')) model = 'Qwen2.5-1.5B-Instruct';
    if (n.startsWith('Qwen3.5-0.8B')) model = 'Qwen3.5-0.8B';
    if (n.startsWith('Qwen3.5-2B')) model = 'Qwen3.5-2B';
    if (n.startsWith('Qwen2.5-Omni-3B')) model = 'Qwen2.5-Omni-3B';
    if (n.startsWith('Qwen3-ASR-0.6B')) model = 'Qwen3-ASR-0.6B';
    if (n.startsWith('Qwen3-ASR-1.7B')) model = 'Qwen3-ASR-1.7B';
    return model == null ? null : 'https://huggingface.co/Qwen/$model';
  }

  /// No certifica precisión, velocidad ni inferencia de un archivo en el teléfono.
  String? get qwenPurpose {
    if (qwenOriginalSource == null) return null;
    if (name.startsWith('Qwen3-ASR-')) {
      return 'Reconocimiento de voz de Qwen: transcribe audio en varios idiomas, '
          'incluido español. No redacta respuestas de chat. '
          'Su adaptador de audio todavía no está conectado en Nano.';
    }
    if (name.startsWith('Qwen2.5-Omni-')) {
      return 'Qwen2.5-Omni admite texto, imágenes, audio y vídeo en su '
          'implementación original. Esta integración MNN de Nano solo envía texto; '
          'seleccionarlo no habilita las demás modalidades.';
    }
    if (name.startsWith('Qwen3.5-')) {
      return categoryKey == 'vision'
          ? 'Variante visual de Qwen3.5 para preguntas sobre imágenes y texto. '
                'El archivo VL está catalogado, pero Nano aún no envía imágenes a su motor.'
          : 'Qwen3.5 para conversación y análisis de texto mediante esta '
                'conversión local. El modelo original admite imágenes; '
                'esta ruta de Nano no las recibe directamente.';
    }
    if (name.startsWith('Qwen3-0.6B-')) {
      return 'Modelo compacto de texto de Qwen para conversación y redacción. '
          'Este archivo LiteRT es la variante no-think: no ofrece el modo '
          'de razonamiento del modelo original. No recibe imágenes ni audio.';
    }
    return 'Qwen2.5 Instruct sigue instrucciones para conversar, resumir y '
        'redactar texto, incluido código. Esta variante no analiza imágenes '
        'ni transcribe audio; sus respuestas requieren revisión.';
  }
}
