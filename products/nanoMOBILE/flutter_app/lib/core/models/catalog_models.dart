import 'chat_models.dart';

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

/// Tipo de modelo (A16): el catálogo deja de ser solo LLM. Cada kind se
/// carga/consume distinto (GGUF → runtime; .tflite → detector de wake word).
enum ModelKind { llm, wakeWord }

class LmCatalogEntry {
  final String name;
  final String params;
  final String quant;
  final double sizeGb;
  final double ramGb;
  final String file;

  /// URL directa al GGUF (HuggingFace resolve).
  final String url;

  /// SHA256 del archivo (obligatorio: la descarga se verifica contra él).
  final String sha256;

  /// Template de chat que espera este modelo para conversaciones multi-turno.
  /// Qwen usa `<|im_start|>`, DeepSeek-R1 usa `<｜begin▁of▁sentence｜>`.
  final ChatTemplate template;

  /// Tier de rendimiento: guía la selección por defecto (Gate R9).
  final ModelTier tier;

  /// Tipo de modelo (A16): llm por defecto; wakeWord para detectores .tflite.
  final ModelKind kind;

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
  });
}

abstract final class NeuralCatalog {
  static const models = <LmCatalogEntry>[
    LmCatalogEntry(
      'Qwen2.5-0.5B-Instruct',
      '0.5B',
      'Q8_0',
      0.68,
      1.0,
      'qwen2.5-0.5b-instruct-q8_0.gguf',
      'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q8_0.gguf',
      'ca59ca7f13d0e15a8cfa77bd17e65d24f6844b554a7b6c12e07a5f89ff76844e',
      template: ChatTemplate.qwen,
    ),
    LmCatalogEntry(
      'Qwen2.5-1.5B-Instruct',
      '1.5B',
      'Q8_0',
      1.76,
      2.2,
      'qwen2.5-1.5b-instruct-q8_0.gguf',
      'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q8_0.gguf',
      'd7efb072e7724d25048a4fda0a3e10b04bdef5d06b1403a1c93bd9f1240a63c8',
      template: ChatTemplate.qwen,
    ),
    LmCatalogEntry(
      'Qwen2.5-Coder-1.5B-Instruct',
      '1.5B',
      'Q4_K_M',
      0.99,
      1.5,
      'qwen2.5-coder-1.5b-instruct-q4_k_m.gguf',
      'https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf',
      'cc324af070c2ecbfd324a30884d2f951a7ff756aba85cb811a6ec436933bb046',
      template: ChatTemplate.qwen,
    ),
    LmCatalogEntry(
      'Qwen2.5-3B-Instruct-Q4_K_M',
      '3B',
      'Q4_K_M',
      2.09,
      2.8,
      'qwen2.5-3b-instruct-q4_k_m.gguf',
      'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf',
      '626b4a6678b86442240e33df819e00132d3ba7dddfe1cdc4fbb18e0a9615c62d',
      template: ChatTemplate.qwen,
    ),
    LmCatalogEntry(
      'Qwen2.5-3B-Instruct',
      '3B',
      'Q8_0',
      3.37,
      4.0,
      'qwen2.5-3b-instruct-q8_0.gguf',
      'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q8_0.gguf',
      '6dcc22694c8654b045ec40bbe350212b88893fd9010e8474bae5b19a43578ba1',
      template: ChatTemplate.qwen,
    ),
    LmCatalogEntry(
      'Qwen3.8-2B-Q4_K_M',
      '2B',
      'Q4_K_M',
      1.31,
      1.9,
      'Qwen3.8-2B-Q4_K_M.gguf',
      'https://huggingface.co/empero-ai/Qwen3.8-2B-Distill-GGUF/resolve/main/Qwen3.8-2B-Q4_K_M.gguf',
      '4aa0fb13c431514262f259d420ecc95a8714df58ac2a2384514e20b93983f0ff',
      template: ChatTemplate.qwen,
    ),
    LmCatalogEntry(
      'Qwen3.8-2B-Q8_0',
      '2B',
      'Q8_0',
      2.08,
      2.7,
      'Qwen3.8-2B-Q8_0.gguf',
      'https://huggingface.co/empero-ai/Qwen3.8-2B-Distill-GGUF/resolve/main/Qwen3.8-2B-Q8_0.gguf',
      '866773b0d68f09a1db9733555e92daff85b617f9a2e601773dff494c5ca2bbf2',
      template: ChatTemplate.qwen,
    ),
    LmCatalogEntry(
      'Qwen3.5-4B-Q4_K_M',
      '4B',
      'Q4_K_M',
      2.55,
      3.5,
      'Qwen3.5-4B-Q4_K_M.gguf',
      'https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/resolve/main/Qwen3.5-4B-Q4_K_M.gguf',
      '00fe7986ff5f6b463e62455821146049db6f9313603938a70800d1fb69ef11a4',
      template: ChatTemplate.qwen,
      tier: ModelTier.deep,
    ),
    LmCatalogEntry(
      'Phi-3.5-mini-Instruct-3.8B',
      '3.8B',
      'Q4_K_M',
      2.39,
      3.2,
      'Phi-3.5-mini-instruct-Q4_K_M.gguf',
      'https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf',
      'e4165e3a71af97f1b4820da61079826d8752a2088e313af0c7d346796c38eff5',
      template: ChatTemplate.qwen,
      tier: ModelTier.deep,
    ),
    LmCatalogEntry(
      'Llama-3.2-1B-Instruct',
      '1B',
      'Q4_K_M',
      0.79,
      1.2,
      'Llama-3.2-1B-Instruct-Q4_K_M.gguf',
      'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
      '6f85a640a97cf2bf5b8e764087b1e83da0fdb51d7c9fab7d0fece9385611df83',
      template: ChatTemplate.llama,
    ),
    LmCatalogEntry(
      'DeepSeek-R1-Distill-Qwen-7B',
      '7B',
      'Q4_K_M',
      4.36,
      5.5,
      'DeepSeek-R1-Distill-Qwen-7B-Q4_K_M.gguf',
      'https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-7B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-7B-Q4_K_M.gguf',
      '78272d8d32084548bd450394a560eb2d70de8232ab96a725769b1f9171235c1c',
      template: ChatTemplate.deepseek,
      tier: ModelTier.deep,
    ),
    LmCatalogEntry(
      'DeepSeek-R1-Distill-Qwen-7B-Q2',
      '7B',
      'Q2_K',
      2.81,
      4.0,
      'DeepSeek-R1-Distill-Qwen-7B-Q2_K.gguf',
      'https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-7B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-7B-Q2_K.gguf',
      '7680555ca635d38cd851095f0f21caed0632f021005037f7d689de77e8f64c35',
      template: ChatTemplate.deepseek,
      tier: ModelTier.deep,
    ),
    // MODELS-CAT-01 — modelos conversacionales 2025-2026 verificados contra
    // la API real de HuggingFace (api/models/<repo>/tree/main) el 2026-09-04:
    // nombre de archivo, tamaño y lfs.oid (SHA256) copiados tal cual, jamás
    // inventados. El gate de instalación exige coincidencia del hash.
    LmCatalogEntry(
      'Qwen3-1.7B-Instruct',
      '1.7B',
      'Q8_0',
      1.83,
      2.4,
      'Qwen3-1.7B-Q8_0.gguf',
      'https://huggingface.co/Qwen/Qwen3-1.7B-GGUF/resolve/main/Qwen3-1.7B-Q8_0.gguf',
      '061b54daade076b5d3362dac252678d17da8c68f07560be70818cace6590cb1a',
      template: ChatTemplate.qwen,
    ),
    LmCatalogEntry(
      'Gemma-3-1B-IT',
      '1B',
      'Q4_K_M',
      0.81,
      1.2,
      'gemma-3-1b-it-Q4_K_M.gguf',
      'https://huggingface.co/ggml-org/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q4_K_M.gguf',
      '8ccc5cd1f1b3602548715ae25a66ed73fd5dc68a210412eea643eb20eb75a135',
      template: ChatTemplate.gemma,
    ),
    LmCatalogEntry(
      'Gemma-3-1B-IT-Q8_0',
      '1B',
      'Q8_0',
      1.07,
      1.5,
      'gemma-3-1b-it-Q8_0.gguf',
      'https://huggingface.co/ggml-org/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q8_0.gguf',
      'b205840c5dcef55078e37d344677869a714ffd42a4ae448c48dcfb52e4bb10d5',
      template: ChatTemplate.gemma,
    ),
    LmCatalogEntry(
      'Llama-3.2-3B-Instruct',
      '3B',
      'Q4_K_M',
      2.02,
      2.6,
      'Llama-3.2-3B-Instruct-Q4_K_M.gguf',
      'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
      '6c1a2b41161032677be168d354123594c0e6e67d2b9227c84f296ad037c728ff',
      template: ChatTemplate.llama,
    ),
    LmCatalogEntry(
      'Qwen3-4B-Instruct-2507',
      '4B',
      'Q4_K_M',
      2.50,
      3.2,
      'Qwen3-4B-Instruct-2507-Q4_K_M.gguf',
      'https://huggingface.co/lmstudio-community/Qwen3-4B-Instruct-2507-GGUF/resolve/main/Qwen3-4B-Instruct-2507-Q4_K_M.gguf',
      '8cdb57cbb880d313736a9bc4e3d3d2485f145b5e19cf33783746e753e82641fc',
      template: ChatTemplate.qwen,
      tier: ModelTier.deep,
    ),
    LmCatalogEntry(
      'Ministral-3-3B-Instruct-2512',
      '3B',
      'Q4_K_M',
      2.15,
      2.8,
      'Ministral-3-3B-Instruct-2512-Q4_K_M.gguf',
      'https://huggingface.co/MistralAI/Ministral-3-3B-Instruct-2512-GGUF/resolve/main/Ministral-3-3B-Instruct-2512-Q4_K_M.gguf',
      '9ed150d4367e68df0ac8e1540f6ddc65b42d0ee26378329d1ecbca60f93fc5f8',
      template: ChatTemplate.mistral,
      tier: ModelTier.deep,
    ),
    // A16 — wake word (detector local microWakeWord, modelo .tflite). SHA256
    // verificado del release oficial OHF-Voice/micro-wake-word v2.1_models.
    // No hay modelo "Nano" pre-entrenado: se usa "hey mycroft" como base; un
    // modelo "Nano" se entrenaría con openWakeWord y se añadiría igual.
    LmCatalogEntry(
      'Hey Mycroft (wake word)',
      'microWakeWord',
      'tflite',
      0.000055,
      0.01,
      'hey_mycroft.tflite',
      'https://github.com/OHF-Voice/micro-wake-word/releases/download/v2.1_models/hey_mycroft.tflite',
      'c2a9b6ed51182db72e014781d5a4ece1929dc232a40b5b4be384f0295f0e1571',
      kind: ModelKind.wakeWord,
    ),
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

  /// Modelos de wake word (.tflite). A16: aún sin entradas — se añaden con el
  /// SHA256 verificado del release oficial de microWakeWord (github.com/OHF-Voice/
  /// micro-wake-word-models). Nunca se inventa un hash: sin SHA256 válido no se
  /// instala (mismo gate que los GGUF).
  static List<LmCatalogEntry> get wakeWordModels =>
      modelsOf(ModelKind.wakeWord);

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
    return ChatTemplate.qwen;
  }
}
