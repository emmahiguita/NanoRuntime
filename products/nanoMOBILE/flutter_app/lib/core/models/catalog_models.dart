import 'chat_models.dart';
part 'catalog_entries_0.dart';
part 'catalog_entries_1.dart';
part 'catalog_entries_2.dart';
part 'catalog_entries_3.dart';
part 'catalog_entries_4.dart';
part 'catalog_entries_5.dart';
part 'catalog_entries_6.dart';

/// Catálogo de modelos y recursos con archivo, backend y SHA definidos.
///
/// LiteRT-LM y GGUF se enrutan por el formato declarado; no se infiere velocidad
/// del nombre del modelo. La instalación comprueba el SHA antes de usar el archivo.
///
/// Se mantiene una opción pequeña por defecto y alternativas pesadas marcadas
/// como avanzadas; el rendimiento de cada teléfono se comprueba por separado.
enum ModelTier {
  /// Opción ligera que se puede ofrecer como predeterminada tras validarla.
  interactive,

  /// Recurso avanzado: el usuario lo elige por memoria o contexto.
  deep,

  /// Modelo pesado: no se selecciona por defecto en un móvil.
  extreme,
}

/// Función que el modelo puede cumplir; evita enviar recursos especializados al chat.
/// Los embeddings producen vectores y no respuestas de texto conversacional.
enum ModelKind {
  llm,
  wakeWord,
  voiceStt,
  voiceTts,
  speakerDiarization,
  multimodalVision,
  imageOcr,
  embedding,
}

/// Formato y motor de inferencia nativo que consume el archivo del modelo.
enum ModelBackendType { gguf, litertlm, mnn }

class LmCatalogEntry {
  final String name;
  final String params;
  final String quant;
  final double sizeGb;
  final double ramGb;
  final String file;

  /// URL directa al archivo principal (GGUF o bin).
  final String url;

  /// SHA256 del archivo (obligatorio: la descarga se verifica contra él).
  final String sha256;

  /// Template de chat que espera este modelo para conversaciones multi-turno.
  /// Qwen usa `<|im_start|>`, DeepSeek-R1 usa `<｜begin▁of▁sentence｜>`.
  final ChatTemplate template;

  /// Tier de rendimiento: guía la selección por defecto (Gate R9).
  final ModelTier tier;

  /// Función del archivo: texto, voz, visión, embeddings o activación.
  final ModelKind kind;

  /// Motor de ejecución correspondiente (GGUF llama.cpp o LiteRT-LM).
  final ModelBackendType backendType;

  /// Nombre del archivo del proyector visual (solo para [ModelKind.multimodalVision]).
  final String? mmprojFile;

  /// URL de descarga directa del proyector visual.
  final String? mmprojUrl;

  /// Hash SHA-256 verificado del proyector visual.
  final String? mmprojSha256;

  /// Commit in the provider's model repository for verified multi-file packages.
  final String? packageRevision;

  const LmCatalogEntry(
    this.name,
    this.params,
    this.quant,
    this.sizeGb,
    this.ramGb,
    this.file,
    this.url,
    this.sha256, {
    this.template = ChatTemplate.qwen,
    this.tier = ModelTier.interactive,
    this.kind = ModelKind.llm,
    this.backendType = ModelBackendType.gguf,
    this.mmprojFile,
    this.mmprojUrl,
    this.mmprojSha256,
    this.packageRevision,
  });
}

abstract final class NeuralCatalog {
  // Partes privadas conservan el orden y los contratos públicos sin repetir modelos.
  static const models = <LmCatalogEntry>[
    ..._catalogEntries0,
    ..._catalogEntries1,
    ..._catalogEntries2,
    ..._catalogEntries3,
    ..._catalogEntries4,
    ..._catalogEntries5,
    ..._catalogEntries6,
  ];

  static LmCatalogEntry entryOf(String name) =>
      models.firstWhere((m) => m.name == name, orElse: () => models[0]);

  static String fileOf(String name) => entryOf(name).file;

  /// Resolves an installed path through catalog metadata; imported GGUF paths
  /// are explicitly registered as GGUF by the model picker/repository.
  static ModelBackendType backendForPath(String? path) {
    // Un único resolvedor conserva el backend declarado para cada artefacto conocido.
    return entryForPath(path)?.backendType ?? ModelBackendType.gguf;
  }

  /// Elige la primera opción ligera; los modelos avanzados requieren elección.
  static LmCatalogEntry get defaultInteractive {
    for (final m in models) {
      if (m.tier == ModelTier.interactive) return m;
    }
    return models[0];
  }

  /// Devuelve las entradas del catálogo por tipo de modelo (A16).
  static List<LmCatalogEntry> modelsOf(ModelKind kind) =>
      models.where((m) => m.kind == kind).toList();

  /// Busca una entrada por nombre de archivo exacto dentro de una ruta privada.
  static LmCatalogEntry? entryForPath(String? path) {
    if (path == null || path.isEmpty) return null;
    final normalized = path
        .replaceAll('\\', '/')
        .replaceAll(RegExp(r'/+$'), '');
    final segments = normalized.split('/');
    for (final entry in models) {
      if (segments.contains(entry.file)) return entry;
    }
    return null;
  }

  /// Solo modelos generativos aparecen en selectores de conversación.
  static List<LmCatalogEntry> get chatModels => models
      .where(
        (m) => m.kind == ModelKind.llm || m.kind == ModelKind.multimodalVision,
      )
      .toList(growable: false);

  /// Modelos de wake word (.tflite) con SHA256 verificado. Se instalan con el
  /// mismo gate de integridad, pero no se envían al runtime GGUF del chat.
  static List<LmCatalogEntry> get wakeWordModels =>
      modelsOf(ModelKind.wakeWord);

  /// Modelos de reconocimiento de voz local (Whisper GGML).
  static List<LmCatalogEntry> get voiceModels => models
      .where(
        (m) =>
            m.kind == ModelKind.voiceStt ||
            m.kind == ModelKind.voiceTts ||
            m.kind == ModelKind.speakerDiarization,
      )
      .toList(growable: false);

  /// Modelos de visión y OCR documental del catálogo, aunque su runtime siga pendiente.
  static List<LmCatalogEntry> get visionModels => models
      .where(
        (m) =>
            m.kind == ModelKind.multimodalVision ||
            m.kind == ModelKind.imageOcr,
      )
      .toList(growable: false);

  /// Devuelve el [ChatTemplate] del modelo por nombre exacto de catálogo.
  ///
  /// Para modelos detectados fuera del catálogo (nombre de archivo),
  /// infiere la familia por el nombre: deepseek/r1, llama, mistral, gemma.
  /// Fallback honesto: [ChatTemplate.qwen] cuando la familia no se reconoce.
  static ChatTemplate templateOf(String name) {
    for (final model in models) {
      if (model.name == name) return model.template;
    }
    final lower = name.toLowerCase();
    if (lower.contains('deepseek') || lower.contains('r1')) {
      return ChatTemplate.deepseek;
    }
    if (lower.contains('llama')) return ChatTemplate.llama;
    if (lower.contains('mistral')) return ChatTemplate.mistral;
    if (lower.contains('gemma')) return ChatTemplate.gemma;
    if (lower.contains('lfm')) return ChatTemplate.qwen;
    return ChatTemplate.qwen;
  }
}
