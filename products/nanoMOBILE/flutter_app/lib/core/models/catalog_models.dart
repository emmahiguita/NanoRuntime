import 'chat_models.dart';
part 'catalog_entries_0.dart';
part 'catalog_entries_1.dart';
part 'catalog_entries_2.dart';
part 'catalog_entries_3.dart';

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

/// Tipo de modelo (A16): el catálogo soporta diversas modalidades. Cada kind se
/// carga y consume según su arquitectura:
/// - [llm]: Modelo generativo de texto a texto en GGUF (llama.cpp).
/// - [wakeWord]: Detector local en background (.tflite microWakeWord).
/// - [voiceStt]: Transcripción de voz local en el dispositivo (Whisper GGML).
/// - [multimodalVision]: Modelo con proyector visual CLIP/SigLIP (GGUF + mmproj).
enum ModelKind { llm, wakeWord, voiceStt, multimodalVision }

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

  /// Tipo de modelo (A16): llm, wakeWord, voiceStt, multimodalVision.
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
  ];

  static LmCatalogEntry entryOf(String name) =>
      models.firstWhere((m) => m.name == name, orElse: () => models[0]);

  static String fileOf(String name) => entryOf(name).file;

  /// Resolves an installed path through catalog metadata; imported GGUF paths
  /// are explicitly registered as GGUF by the model picker/repository.
  static ModelBackendType backendForPath(String? path) {
    if (path == null || path.isEmpty) return ModelBackendType.gguf;
    final normalized = path.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
    // El paquete MNN contiene varios archivos internos; clasificamos también
    // las rutas que terminan en llm_config.json, sin confundir nombres parciales.
    final segments = normalized.split('/');
    for (final entry in models) {
      if (segments.contains(entry.file)) return entry.backendType;
    }
    return ModelBackendType.gguf;
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

  /// Modelos de wake word (.tflite) con SHA256 verificado. Se instalan con el
  /// mismo gate de integridad, pero no se envían al runtime GGUF del chat.
  static List<LmCatalogEntry> get wakeWordModels =>
      modelsOf(ModelKind.wakeWord);

  /// Modelos de reconocimiento de voz local (Whisper GGML).
  static List<LmCatalogEntry> get voiceModels => modelsOf(ModelKind.voiceStt);

  /// Modelos con visión multimodal (GGUF + mmproj).
  static List<LmCatalogEntry> get visionModels =>
      modelsOf(ModelKind.multimodalVision);

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
