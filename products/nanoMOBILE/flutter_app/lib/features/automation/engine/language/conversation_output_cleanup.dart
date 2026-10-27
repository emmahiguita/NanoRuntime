// QUÉ: limpia exclusivamente artefactos de formato en una respuesta ya redactada.
// CÓMO: preserva palabras y signos originales; solo retira prefijos y repeticiones.
// POR QUÉ: replaceAll usa texto literal y r'$1' dañaba los signos de puntuación.
abstract final class ConversationOutputCleanup {
  static String clean(String draft) {
    var out = draft.trim();
    if (out.isEmpty) return out;
    // Metadatos del protocolo no forman parte del mensaje del contacto.
    out = out.replaceFirst(
      RegExp(
        r'^(?:respuesta|reply|assistant|asistente)\s*:\s*',
        caseSensitive: false,
      ),
      '',
    );
    // Conserva la primera marca terminal sin convertir preguntas en afirmaciones.
    out = out.replaceAllMapped(RegExp(r'([!?])[!?]+'), (m) => m.group(1)!);
    out = out.replaceAll(RegExp(r',{2,}'), ',');
    out = out.replaceAll(RegExp(r';{2,}'), ';');
    out = out.replaceAll(RegExp(r':{2,}'), ':');
    out = out.replaceAll(RegExp(r'\.{3,}'), '...');
    // El grupo capturado se obtiene del Match: nunca se envía el literal «$1».
    out = out.replaceAllMapped(RegExp(r'\s+([,.;:!?])'), (m) => m.group(1)!);
    out = out.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
    out = out.replaceAll(RegExp(r' {2,}'), ' ');
    return out.trim();
  }
}
