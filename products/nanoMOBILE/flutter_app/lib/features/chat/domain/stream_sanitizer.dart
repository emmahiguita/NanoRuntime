/// Sanitizador de tokens de control y delimitadores de plantillas de modelos GGUF.
///
/// **QUÉ HACE:**
/// Elimina los marcadores de fin/inicio de turno específicos de ChatML, DeepSeek y Llama
/// que el motor local pueda dejar escapar en el texto crudo.
///
/// **CÓMO FUNCIONA:**
/// Aplica sustituciones de cadenas fijas sobre los tokens `im_end`, `im_start`, `endoftext`, etc.
///
/// **POR QUÉ:**
/// Si un modelo emite estos tokens literales, la interfaz de chat mostraría basura sintáctica
/// de la plantilla o descolocaría el parseo de markdown en la vista.
class StreamSanitizer {
  const StreamSanitizer();

  /// Sanea el texto generado eliminando delimitadores de plantilla residuales.
  static String sanitize(String raw) {
    final clean = raw
        .replaceAll('<|im_end|>', '')
        .replaceAll('<|im_start|>', '')
        .replaceAll('<|endoftext|>', '')
        .replaceAll('<\uFF5Cend\u2581of\u2581sentence\uFF5C>', '')
        .replaceAll('<\uFF5Cbegin\u2581of\u2581sentence\uFF5C>', '')
        .trim();
    return clean.isEmpty ? raw : clean;
  }
}
