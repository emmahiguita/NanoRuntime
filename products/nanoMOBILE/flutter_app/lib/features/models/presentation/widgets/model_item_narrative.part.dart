// QUÉ: explica el propósito del modelo y la conexión disponible en Nano.
// CÓMO: usa el tipo del catálogo y excepciones de artefactos documentados.
// POR QUÉ: una modalidad publicada no demuestra integración ni calidad local.
part of 'model_catalog_types.dart';

extension ModelItemNarrative on UnifiedModelItem {
  /// Identifica capacidades publicadas sin convertirlas en permisos del motor.
  bool get hasPublishedMultimodality =>
      isCatalog &&
      (catalog!.isMultimodal ||
          catalog!.kind == ModelKind.imageOcr ||
          name.startsWith('Gemma-4-') ||
          name.startsWith('Qwen2.5-Omni-') ||
          name.startsWith('EmbeddingGemma-2-Text-Vision-') ||
          name.startsWith('EmbeddingGemma-2-740M-'));

  String get modalityLabel {
    if (!isCatalog) return 'Modalidades sin verificar';
    if (catalog!.isVoiceStt || catalog!.kind == ModelKind.speakerDiarization) {
      return 'Entrada de audio';
    }
    if (catalog!.kind == ModelKind.voiceTts) return 'Texto → voz';
    if (hasPublishedMultimodality) return 'Multimodal · capacidad publicada';
    return catalog!.kind == ModelKind.embedding ? 'Texto → vectores' : 'Texto';
  }

  String get backendLabel => !isCatalog
      ? 'Formato GGUF'
      : switch (catalog!.backendType) {
          ModelBackendType.gguf =>
            catalog!.isVoiceStt ? 'whisper.cpp' : 'llama.cpp',
          ModelBackendType.litertlm => 'LiteRT-LM',
          ModelBackendType.mnn => 'MNN',
        };

  /// Narrativa por tarea; evita atribuir conversación a recursos especializados.
  String get purposeNarrative {
    // La ficha Qwen describe la variante exacta antes de recurrir al texto por tarea.
    final qwen = qwenPurpose;
    if (qwen != null) return qwen;
    if (!isCatalog) {
      return 'Archivo GGUF importado. Su cabecera identifica el formato, '
          'pero no confirma si genera texto, produce vectores o necesita un proyector.';
    }
    return switch (categoryKey) {
      'multimodal' =>
        'Modelo generativo con modalidades adicionales publicadas '
            'por su proveedor. En Nano se ofrece su ruta de conversación de texto; '
            'las entradas visuales y de audio requieren conexión propia.',
      'vision' =>
        'Modelo de texto e imagen para responder preguntas sobre '
            'fotografías y contenido visual. Necesita recibir la imagen en su motor.',
      'ocr' =>
        'Lector especializado en documentos: reconoce texto y puede '
            'interpretar tablas o fórmulas mediante tareas específicas de PaddleOCR.',
      'voz' =>
        'Convierte voz grabada en texto. La transcripción puede aportar '
            'contenido al chat; el reconocimiento de voz no redacta la respuesta.',
      'voz_generativa' =>
        'Convierte texto en audio hablado. Es un sintetizador '
            'de voz, no un modelo para transcribir mensajes recibidos.',
      'voz_hablantes' =>
        'Distingue los turnos de los hablantes en un audio. '
            'No identifica sus nombres ni transcribe por sí solo la conversación.',
      'rag' =>
        'Transforma contenido en vectores para comparar significados '
            'y recuperar información. No genera respuestas conversacionales.',
      'razonamiento' =>
        'Modelo generativo orientado a problemas con varios '
            'pasos. Puede redactar y analizar texto; sus conclusiones requieren revisión.',
      'codigo' =>
        'Modelo generativo orientado a explicar, proponer y revisar '
            'código. La respuesta no equivale a ejecutar ni validar el programa.',
      'agentes' =>
        'Modelo generativo orientado a planificación e instrucciones '
            'de herramientas. Ejecutar acciones exige conectores y permisos de Nano.',
      _ =>
        'Modelo generativo para conversar, redactar y resumir texto. '
            'Su tamaño no garantiza comprensión, ortografía ni fidelidad al contexto.',
    };
  }

  String get nanoNarrative {
    if (!isCatalog) {
      return 'Nano reconoce el archivo; su tarea y compatibilidad '
          'siguen sin verificar. No se presenta como chat, visión u OCR confirmado.';
    }
    if (catalog!.kind == ModelKind.llm) {
      return 'Nano dispone de una ruta de texto mediante $backendLabel para '
          'Chat IA y Nano Personal. Cargar el archivo y obtener una respuesta '
          'en este equipo son comprobaciones independientes.';
    }
    if (catalog!.isVoiceStt && runtimeReady) {
      return 'Nano conecta este archivo a whisper.cpp para transcripción local. '
          'El texto resultante se entrega al modelo de conversación seleccionado.';
    }
    return switch (categoryKey) {
      'vision' =>
        'La entrada directa de imágenes a este VLM no está conectada '
            'en el chat. Las fotos usan OCR y etiquetas locales de Android.',
      'ocr' =>
        'Este paquete PaddleOCR aún no tiene su adaptador conectado. '
            'El OCR de fotos y PDF del chat usa el lector local de Android.',
      'rag' =>
        'Falta conectar la extracción de vectores, el índice y la '
            'recuperación documental. Descargarlo no activa una biblioteca RAG.',
      _ =>
        'El adaptador de esta tarea todavía no está conectado en Nano. '
            'El archivo puede figurar en el catálogo sin estar listo para ejecutar.',
    };
  }

  String get limitNarrative {
    if (hasPublishedMultimodality && catalog!.kind == ModelKind.llm) {
      return 'El modelo original es multimodal; esta ruta de Nano solo envía '
          'texto. No activa análisis de imágenes, vídeo ni audio por seleccionarlo.';
    }
    if (categoryKey == 'agentes') {
      return 'La selección del modelo no habilita '
          'automáticamente herramientas, permisos ni envío de mensajes.';
    }
    return 'La RAM indicada es una estimación. La integración del motor no '
        'certifica velocidad, calidad ni funcionamiento de cada archivo.';
  }
}
