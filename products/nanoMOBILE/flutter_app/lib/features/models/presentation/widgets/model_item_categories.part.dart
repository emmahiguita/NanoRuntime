// QUÉ: metadatos del catálogo separados por responsabilidad.
// CÓMO: extiende el DTO sin modificar archivos ni seleccionar motores.
// POR QUÉ: mantiene una sola clasificación y archivos breves.
part of 'model_catalog_types.dart';

extension ModelItemCategories on UnifiedModelItem {
  String get capabilityLabel {
    if (!isCatalog) return 'GGUF local · función no verificada';
    final cat = catalog!;
    final n = cat.name.toLowerCase();
    if (cat.kind == ModelKind.llm && hasPublishedMultimodality) {
      return 'Multimodal de origen · texto en Nano';
    }
    if (cat.kind == ModelKind.embedding) {
      return 'Búsqueda semántica y memoria RAG';
    }
    if (cat.kind == ModelKind.wakeWord) {
      return 'Activación por palabra clave';
    }
    if (cat.kind == ModelKind.imageOcr) return 'OCR de documentos e imágenes';
    if (cat.kind == ModelKind.voiceTts) return 'Síntesis de voz';
    if (cat.kind == ModelKind.speakerDiarization) {
      return 'Separación de hablantes';
    }
    if (cat.isVoiceStt) {
      return 'Transcripción de audio';
    }
    if (cat.isMultimodal) {
      return 'Comprensión de imágenes y documentos';
    }
    if (n.contains('coder')) {
      return 'Generación y análisis de código';
    }
    if (n.contains('deepseek') || n.contains('r1')) {
      return 'Razonamiento y análisis';
    }
    return 'Chat y tareas generales';
  }

  String get categoryKey {
    if (!isCatalog) return 'local';
    final cat = catalog!;
    final n = cat.name.toLowerCase();
    if (cat.kind == ModelKind.llm && hasPublishedMultimodality) {
      return 'multimodal';
    }
    if (cat.kind == ModelKind.embedding) return 'rag';
    if (cat.kind == ModelKind.wakeWord) return 'agentes';
    if (cat.kind == ModelKind.imageOcr) return 'ocr';
    if (cat.kind == ModelKind.voiceTts) return 'voz_generativa';
    if (cat.kind == ModelKind.speakerDiarization) return 'voz_hablantes';
    if (cat.isVoiceStt) {
      return 'voz';
    }
    if (cat.isMultimodal) return 'vision';
    if (n.contains('coder')) return 'codigo';
    if (n.contains('deepseek') ||
        n.contains('r1') ||
        n.contains('granite-4.2') ||
        n.contains('spark-x2.5')) {
      return 'razonamiento';
    }
    if (n.contains('agents-a1')) {
      return 'agentes';
    }
    return 'chat';
  }

  String get categoryLabel => switch (categoryKey) {
    'chat' => 'AI Chat',
    'razonamiento' => 'Razonamiento',
    'codigo' => 'Programación',
    'vision' => 'Imagen y documentos',
    'multimodal' => 'Multimodales',
    'ocr' => 'OCR de documentos',
    'voz' => 'Transcripción de audio',
    'voz_generativa' => 'Síntesis de voz',
    'voz_hablantes' => 'Separación de hablantes',
    'rag' => 'Memoria y RAG',
    'agentes' => 'Agentes y acciones',
    'local' => 'Importados localmente',
    _ => 'Otros modelos',
  };
}
