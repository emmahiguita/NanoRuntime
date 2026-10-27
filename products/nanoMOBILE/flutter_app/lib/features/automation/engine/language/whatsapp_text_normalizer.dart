// whatsapp_text_normalizer.dart
//
// QUÉ HACE:
// Normalización conservadora de abreviaturas y errores ortográficos frecuentes de
// WhatsApp para clasificación de intenciones y recuperación de memoria, más similitud
// aproximada por n-gramas de caracteres.
//
// CÓMO FUNCIONA:
// - Conserva intacto el texto original del usuario; esta salida solo alimenta routers y búsqueda.
// - Reemplaza únicamente tokens completos no ambiguos (ej. "q"->"que", "acer"->"hacer", "oy"->"hoy").
// - Jamás reemplaza letras aisladas ambiguas como "x" para no alterar nombres o direcciones.
// - Calcula similitud de Dice sobre trigramas de caracteres para tolerar erratas tipográficas.

library;

abstract final class WhatsAppTextNormalizer {
  static const Map<String, String> _conservativeTokenMap = {
    'q': 'que',
    'ke': 'que',
    'xq': 'porque',
    'xk': 'porque',
    'pq': 'porque',
    'acer': 'hacer',
    'aser': 'hacer',
    'aces': 'haces',
    'ases': 'haces',
    'aciendo': 'haciendo',
    'asiendo': 'haciendo',
    'aras': 'haras',
    'oy': 'hoy',
    'ayr': 'ayer',
    'mnn': 'manana',
    'tmb': 'tambien',
    'tbn': 'tambien',
    'bn': 'bien',
    'dnd': 'donde',
    'cndo': 'cuando',
    'qndo': 'cuando',
    'kien': 'quien',
    'tngo': 'tengo',
    'fubol': 'futbol',
    'furbol': 'futbol',
    'almorsar': 'almorzar',
    'almorsando': 'almorzando',
    'almorsaste': 'almorzaste',
  };

  /// Normaliza conservadoramente abreviaturas de WhatsApp sin mutar el texto original.
  static String normalizeForUnderstanding(String raw) {
    var text = raw.trim().toLowerCase();
    if (text.isEmpty) return '';
    text = text
        .replaceAll('mñn', 'manana')
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
    text = text.replaceAll(RegExp(r'[^\w\s]'), ' ');
    final tokens = text
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => _conservativeTokenMap[t] ?? t)
        .toList(growable: false);
    return tokens.join(' ');
  }

  /// Coeficiente de Dice sobre trigramas de caracteres entre dos tokens (>= 4 chars).
  static double tokenTrigramSimilarity(String a, String b) {
    final cleanA = a.trim().toLowerCase();
    final cleanB = b.trim().toLowerCase();
    if (cleanA == cleanB) return 1.0;
    if (cleanA.length < 4 || cleanB.length < 4) return 0.0;
    final gramsA = _trigrams(cleanA);
    final gramsB = _trigrams(cleanB);
    if (gramsA.isEmpty || gramsB.isEmpty) return 0.0;
    final overlap = gramsA.intersection(gramsB).length;
    return (2.0 * overlap) / (gramsA.length + gramsB.length);
  }

  static Set<String> _trigrams(String token) {
    final padded = ' $token ';
    final out = <String>{};
    for (var i = 0; i <= padded.length - 3; i++) {
      out.add(padded.substring(i, i + 3));
    }
    return out;
  }
}
