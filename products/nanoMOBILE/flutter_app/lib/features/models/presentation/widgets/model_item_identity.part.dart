// QUÉ: metadatos del catálogo separados por responsabilidad.
// CÓMO: extiende el DTO sin modificar archivos ni seleccionar motores.
// POR QUÉ: mantiene una sola clasificación y archivos breves.
part of 'model_catalog_types.dart';

extension ModelItemIdentity on UnifiedModelItem {
  // QUÉ HACE: Resuelve la empresa/familia del modelo por nombre.
  // POR QUÉ: Centraliza la detección de familia para secciones y filtros.
  String get company {
    if (!isCatalog) return 'Tarjeta SD / Local';
    final n = catalog!.name.toLowerCase();
    // Una destilación de Qwen pertenece a DeepSeek: comprobarla antes de Qwen.
    if (n.contains('deepseek')) return 'DeepSeek AI';
    if (n.contains('lfm') || n.contains('liquid')) return 'Liquid AI';
    if (n.contains('qwen')) return 'Alibaba Qwen';
    if (n.contains('gemma')) return 'Google Gemma';
    if (n.contains('granite')) return 'IBM Granite';
    if (n.contains('paddle')) return 'Baidu PaddlePaddle';
    if (n.contains('agents-a1')) return 'InternScience';
    if (n.contains('spark')) return 'iFLYTEK Spark';
    if (n.contains('nemotron')) return 'NVIDIA Nemotron';
    if (n.contains('audio8')) return 'Edge0 Audio';
    if (n.contains('moonshine')) return 'Useful Sensors';
    if (n.contains('whisper')) return 'OpenAI Whisper';
    if (n.contains('llama')) return 'Meta Llama';
    return 'Comunidad AI';
  }

  // QUÉ HACE: Genera el título de sección agrupada (familia + función).
  // POR QUÉ: Cada familia debe aparecer en su propia sección, no mezclada.
  String get sectionTitle {
    if (categoryKey == 'multimodal') return 'MULTIMODALES · TEXTO EN NANO';
    if (categoryKey == 'razonamiento') {
      return 'RAZONAMIENTO · ANÁLISIS DE TEXTO';
    }
    if (!isCatalog) return 'ALMACENAMIENTO LOCAL • TARJETA SD';
    final cat = catalog!;
    final n = cat.name.toLowerCase();
    if (cat.kind == ModelKind.embedding) return 'MEMORIA Y RAG • EMBEDDINGS';
    if (cat.kind == ModelKind.wakeWord) return 'WAKE WORD • ACTIVACIÓN LOCAL';
    if (cat.kind == ModelKind.imageOcr) return 'OCR • DOCUMENTOS E IMÁGENES';
    if (cat.kind == ModelKind.voiceTts) return 'VOZ Y AUDIO • SÍNTESIS';
    if (cat.kind == ModelKind.speakerDiarization) {
      return 'VOZ Y AUDIO • SEPARACIÓN DE HABLANTES';
    }
    if (cat.isVoiceStt) {
      return 'VOZ Y AUDIO • TRANSCRIPCIÓN';
    }
    if (cat.isMultimodal) return 'IMAGEN • COMPRENSIÓN MULTIMODAL';
    if (n.contains('coder')) return 'PROGRAMACIÓN • MODELOS DE CÓDIGO';
    if (n.contains('lfm') || n.contains('liquid')) {
      return 'CHAT LOCAL • EDGE ULTRALIGERO';
    }
    if (n.contains('deepseek') || n.contains('r1')) {
      return 'RAZONAMIENTO • ANÁLISIS PROFUNDO';
    }
    return 'CHAT Y ASISTENTES • CONVERSACIÓN GENERAL';
  }

  // QUÉ HACE: Etiqueta corta de la tarjeta.
  // NANO = recomendado para Nano Personal (ultrapequeño, < 1B params).
  // EDGE = arquitectura edge-first (LFM).
  String get typeTag {
    if (!isCatalog) return 'SD';
    final cat = catalog!;
    if (hasPublishedMultimodality && cat.kind == ModelKind.llm) {
      return 'MULTIMODAL';
    }
    if (cat.kind == ModelKind.imageOcr) return 'OCR';
    if (cat.kind == ModelKind.voiceTts) return 'TTS';
    if (cat.kind == ModelKind.speakerDiarization) return 'DIAR';
    if (cat.isVoiceStt) return 'VOZ';
    if (cat.kind == ModelKind.embedding) return 'RAG';
    if (cat.kind == ModelKind.wakeWord) return 'WAKE';
    if (cat.isMultimodal) return 'VISIÓN';
    final n = cat.name.toLowerCase();
    if (cat.backendType == ModelBackendType.litertlm) return 'LITERT';
    if (cat.backendType == ModelBackendType.mnn) return 'MNN';
    if (n.contains('lfm')) return 'EDGE';
    if (n.contains('coder')) return 'CODER';
    if (n.contains('deepseek') || n.contains('r1')) return 'RAZÓN';
    if (n.contains('0.6b') || n.contains('0.8b') || n.contains('350m')) {
      return 'NANO';
    }
    if (n.contains('instruct')) return 'CHAT';
    return 'LLM';
  }

  // QUÉ HACE: true si es modelo especializado (Voz, Visión, Embeddings o Wake).
  // POR QUÉ: Permite agrupar herramientas de funciones dedicadas con separador propio.
  bool get isSpecialized {
    if (!isCatalog) return false;
    final cat = catalog!;
    return cat.isVoiceStt ||
        cat.kind == ModelKind.voiceTts ||
        cat.kind == ModelKind.speakerDiarization ||
        cat.kind == ModelKind.imageOcr ||
        cat.isMultimodal ||
        cat.kind == ModelKind.wakeWord ||
        cat.kind == ModelKind.embedding;
  }
}
