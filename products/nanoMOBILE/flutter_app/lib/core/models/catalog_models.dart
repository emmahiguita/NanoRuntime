import 'chat_models.dart';
part 'catalog_entries_0.dart';
part 'catalog_entries_1.dart';
part 'catalog_entries_2.dart';

/// Catálogo REAL de modelos GGUF descargables desde HuggingFace.
///
/// Cada entrada declara URL de descarga directa (`resolve/main/...`) y el
/// SHA256 exacto del archivo (lfs oid verificado contra la API de
/// HuggingFace el 2026-08-13 y re-auditado el 2026-09-04). La descarga en
/// la app exige que el hash del archivo recibido coincida: sin SHA256
/// válido, el modelo no se instala.
///
/// MODELS-CAT-02 — reglas de admisión (auditoría 2026-09-04 contra la API):
/// 1. El archivo debe existir COMO UN SOLO GGUF en el repo. Fuera los
///    partidos en shards (qwen2.5-7b/14b/32b): nanortime no soporta split
///    y la URL apuntaría a un archivo inexistente.
/// 2. Solo móvil: ramGb ≤ ~7 GB (cabe en un teléfono de 8 GB con margen).
///    Fuera 27B/32B — nunca cargarán en un móvil, ni en batch.
/// 3. Un solo cuant por modelo cuando uno es estrictamente peor (Q4_K_S
///    vs Q4_K_M del mismo modelo: se queda el K_M).
///
/// Un solo motor nanortime corre a la vez: cambiar de modelo requiere
/// reiniciar el motor, y eso lo orquesta la app vía EngineSupervisor
/// (kill limpio + respawn con --model <path>).
/// Tier de rendimiento del modelo — Gate R9. El chat debe seleccionar
/// INTERACTIVE por defecto; DEEP/EXTREME solo si el usuario elige explícitamente.
enum ModelTier {
  /// ≤3B: tiempo al primer token < ~5s en móvil. Default del chat.
  interactive,

  /// 4B–7B: usable pero lento en el primer token.
  deep,

  /// 9B+: solo batch/insistencia explícita. Nunca default del chat.
  extreme,
}

/// Tipo de modelo (A16): el catálogo soporta diversas modalidades. Cada kind se
/// carga y consume según su arquitectura:
/// - [llm]: Modelo generativo de texto a texto en GGUF (llama.cpp).
/// - [wakeWord]: Detector local en background (.tflite microWakeWord).
/// Tipo de modelo (A16): el catálogo soporta diversas modalidades. Cada kind se
/// carga y consume según su arquitectura:
/// - [llm]: Modelo generativo de texto a texto en GGUF (llama.cpp).
/// - [wakeWord]: Detector local en background (.tflite microWakeWord).
/// - [voiceStt]: Transcripción de voz local en el dispositivo (Whisper GGML).
/// - [multimodalVision]: Modelo con proyector visual CLIP/SigLIP (GGUF + mmproj).
enum ModelKind { llm, wakeWord, voiceStt, multimodalVision }

/// Formato y motor de inferencia nativo que consume el archivo del modelo.
enum ModelBackendType { gguf, litertlm }

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
  });
}

abstract final class NeuralCatalog {
  // Partes privadas conservan el orden y los contratos públicos sin repetir modelos.
  static const models = <LmCatalogEntry>[
    ..._catalogEntries0,
    ..._catalogEntries1,
    ..._catalogEntries2,
  ];

  static LmCatalogEntry entryOf(String name) =>
      models.firstWhere((m) => m.name == name, orElse: () => models[0]);

  static String fileOf(String name) => entryOf(name).file;

  /// Gate R9 — modelo interactivo por defecto: el primer modelo del catálogo
  /// con tier INTERACTIVE (≤3B). El chat NUNCA debe arrancar con un modelo
  /// DEEP/EXTREME seleccionado por defecto: eso hace parecer lenta a toda la
  /// app. El usuario elige un modelo grande explícitamente si lo necesita.
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
