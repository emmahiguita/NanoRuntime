// QUÉ: prepara texto externo para celdas y rótulos del PDF.
// CÓMO: retira controles invisibles, normaliza espacios y limita longitud.
// POR QUÉ: evita tablas deformadas sin eliminar acentos ni símbolos Unicode.

abstract final class ReportTextFormatter {
  static final _controls = RegExp(
    r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]',
  );
  static final _spaces = RegExp(r'\s+');

  static String clean(
    Object? value, {
    int maxLength = 240,
    String empty = '-',
  }) {
    final normalized = '${value ?? ''}'
        .replaceAll(_controls, ' ')
        .replaceAll(_spaces, ' ')
        .trim();
    if (normalized.isEmpty) return empty;
    final codePoints = normalized.runes.toList(growable: false);
    if (codePoints.length <= maxLength) return normalized;
    return '${String.fromCharCodes(codePoints.take(maxLength - 1))}…';
  }
}
