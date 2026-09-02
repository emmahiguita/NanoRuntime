/// A14.9 — Extracción determinista de DATOS OBSERVADOS.
///
/// Convierte el contenido de una notificación (dato NO CONFIABLE) en valores
/// estructurados (URL, email) que OTRO dominio puede consumir (Linux write,
/// browser open, ...). Determinista, sin LLM, sin visión.
///
/// Seguridad: lo extraído es DATO, no instrucción. Nunca se convierte en un
/// comando ni expande el alcance de la intención original.
library;

/// Datos estructurados extraídos de un texto observado.
class ObservedData {
  final List<String> urls;
  final List<String> emails;

  const ObservedData({this.urls = const [], this.emails = const []});

  bool get hasData => urls.isNotEmpty || emails.isNotEmpty;

  /// Primer dato accionable (URL preferido sobre email).
  String? get primary =>
      urls.isNotEmpty ? urls.first : (emails.isNotEmpty ? emails.first : null);
}

/// Extractor determinista de datos observados (sin LLM).
class ObservedDataExtractor {
  const ObservedDataExtractor();

  static final _urlRe = RegExp(r'https?://[^\s)"<>]+', caseSensitive: false);
  static final _emailRe = RegExp(
    r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b',
  );

  ObservedData extract(String text) {
    final urls = <String>[];
    final emails = <String>[];
    for (final m in _urlRe.allMatches(text)) {
      final u = m.group(0)!;
      // Quitar puntuación final pegada (puntos/comas de la frase).
      final cleaned = u.replaceAll(RegExp(r'[.,;:]+$'), '');
      if (cleaned.isNotEmpty && !urls.contains(cleaned)) urls.add(cleaned);
    }
    for (final m in _emailRe.allMatches(text)) {
      final e = m.group(0)!;
      if (!emails.contains(e)) emails.add(e);
    }
    return ObservedData(urls: urls, emails: emails);
  }
}
