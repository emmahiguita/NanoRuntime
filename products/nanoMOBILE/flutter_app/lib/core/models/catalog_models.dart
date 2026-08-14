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
  });
}

abstract final class NeuralCatalog {
  static const models = <LmCatalogEntry>[
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
      'DeepSeek-R1-Distill-Qwen-7B',
      '7B',
      'Q4_K_M',
      4.36,
      5.5,
      'DeepSeek-R1-Distill-Qwen-7B-Q4_K_M.gguf',
      'https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-7B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-7B-Q4_K_M.gguf',
      '78272d8d32084548bd450394a560eb2d70de8232ab96a725769b1f9171235c1c',
      template: ChatTemplate.deepseek,
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
    ),
  ];

  static LmCatalogEntry entryOf(String name) =>
      models.firstWhere((m) => m.name == name, orElse: () => models[0]);

  static String fileOf(String name) => entryOf(name).file;

  /// Devuelve el [ChatTemplate] del modelo por nombre, o [ChatTemplate.qwen]
  /// por defecto.
  static ChatTemplate templateOf(String name) => entryOf(name).template;
}
