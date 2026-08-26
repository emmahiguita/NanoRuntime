import 'chat_models.dart';

/// Catálogo REAL de modelos GGUF descargables desde HuggingFace.
///
/// Cada entrada declara URL de descarga directa (`resolve/main/...`) y el
/// SHA256 exacto del archivo (lfs oid verificado contra la API de
/// HuggingFace el 2026-08-13). La descarga en la app exige que el hash del
/// archivo recibido coincida: sin SHA256 válido, el modelo no se instala.
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
      'https://huggingface.co/empero-ai/Qwen3.8-2B-GGUF/resolve/main/Qwen3.8-2B-Q4_K_M.gguf',
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
      'https://huggingface.co/empero-ai/Qwen3.8-2B-GGUF/resolve/main/Qwen3.8-2B-Q8_0.gguf',
      '866773b0d68f09a1db9733555e92daff85b617f9a2e601773dff494c5ca2bbf2',
      template: ChatTemplate.qwen,
    ),
    LmCatalogEntry(
      'Qwen3.5-4B',
      '4B',
      'Q4_K_S',
      2.41,
      3.2,
      'Qwen3.5-4B-Q4_K_S.gguf',
      'https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/resolve/main/Qwen3.5-4B-Q4_K_S.gguf',
      '27caeb0e4b999d92ce0a9fdbdd1a7ba5112908d9de125645883732274be2ea77',
      template: ChatTemplate.qwen,
      tier: ModelTier.deep,
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
      'Qwen3.8-27B-Q2_K',
      '27B',
      'Q2_K',
      11.84,
      13.5,
      'Qwen3.8-27B-Q2_K.gguf',
      'https://huggingface.co/bartowski/Qwen3.8-27B-GGUF/resolve/main/Qwen3.8-27B-Q2_K.gguf',
      '028a1d47b9c822ca76d1e9295d0078d21351a8816ec5612cb4860d7c1ef429d9',
      template: ChatTemplate.qwen,
      tier: ModelTier.extreme,
    ),
    LmCatalogEntry(
      'Qwen3.8-27B-Q4_K_M',
      '27B',
      'Q4_K_M',
      17.77,
      19.5,
      'Qwen3.8-27B-Q4_K_M.gguf',
      'https://huggingface.co/bartowski/Qwen3.8-27B-GGUF/resolve/main/Qwen3.8-27B-Q4_K_M.gguf',
      'e103abf9d914d1d7b2f2592f055f2759a71195c350a01c135f71aaae86bca52b',
      template: ChatTemplate.qwen,
      tier: ModelTier.extreme,
    ),
    LmCatalogEntry(
      'Qwen2.5-7B-Instruct',
      '7B',
      'Q4_K_M',
      4.68,
      5.8,
      'qwen2.5-7b-instruct-q4_k_m.gguf',
      'https://huggingface.co/Qwen/Qwen2.5-7B-Instruct-GGUF/resolve/main/qwen2.5-7b-instruct-q4_k_m.gguf',
      '19572b9a7be8e52dbb050cfd173ecfaec07519bfb8e0e64b88939c0f992bc664',
      template: ChatTemplate.qwen,
      tier: ModelTier.deep,
    ),
    LmCatalogEntry(
      'Qwen2.5-14B-Instruct-Q2',
      '14B',
      'Q2_K',
      5.82,
      7.2,
      'qwen2.5-14b-instruct-q2_k.gguf',
      'https://huggingface.co/Qwen/Qwen2.5-14B-Instruct-GGUF/resolve/main/qwen2.5-14b-instruct-q2_k.gguf',
      '95aa0fc9fbe2774db8cfad62e49c7198bb6cf902263158c97daecae348f07297',
      template: ChatTemplate.qwen,
      tier: ModelTier.extreme,
    ),
    LmCatalogEntry(
      'Qwen2.5-14B-Instruct',
      '14B',
      'Q4_K_M',
      8.98,
      10.8,
      'qwen2.5-14b-instruct-q4_k_m.gguf',
      'https://huggingface.co/Qwen/Qwen2.5-14B-Instruct-GGUF/resolve/main/qwen2.5-14b-instruct-q4_k_m.gguf',
      'e8cb7ebfe8847e923e16eeab79b5c00e6fe14589d98d249f3e5b72186fafe399',
      template: ChatTemplate.qwen,
      tier: ModelTier.extreme,
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
      'Gemma-2-27B-IT-Q2',
      '27B',
      'Q2_K',
      10.8,
      13.5,
      'gemma-2-27b-it-Q2_K.gguf',
      'https://huggingface.co/bartowski/gemma-2-27b-it-GGUF/resolve/main/gemma-2-27b-it-Q2_K.gguf',
      'a361b524be3e172f3535b010c440d352f7f3103eee903d1eb939eea21d40e359',
      template: ChatTemplate.gemma,
      tier: ModelTier.extreme,
    ),
    LmCatalogEntry(
      'Qwen2.5-32B-Instruct-Q2',
      '32B',
      'Q2_K',
      12.4,
      14.5,
      'qwen2.5-32b-instruct-q2_k.gguf',
      'https://huggingface.co/Qwen/Qwen2.5-32B-Instruct-GGUF/resolve/main/qwen2.5-32b-instruct-q2_k.gguf',
      '47df9d6a365bbbc5eb38ee49d5690b220e2e92c235cb319d67562be56d787093',
      template: ChatTemplate.qwen,
      tier: ModelTier.extreme,
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
