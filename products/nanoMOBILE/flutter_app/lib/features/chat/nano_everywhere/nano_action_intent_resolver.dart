/// Acciones reconocidas del flotante; una intención desconocida pide aclaración.
enum NanoActionIntent {
  directCommand,
  readScreen,
  whatsApp,
  telegram,
  messenger,
  navBack,
  navHome,
  navRecents,
  tapElement,
  typeText,
  openApp,
  unknown,
}

/// Clasifica órdenes explícitas antes de entregarlas al coordinador existente.
/// No convierte hechos personales ni frases ambiguas en lectura de pantalla.
abstract final class NanoActionIntentResolver {
  /// Prioriza mensajería contextual y exige un objeto en acciones con argumentos.
  static NanoActionIntent resolve(String clean) {
    final lower = clean.toLowerCase().trim();
    if (lower.startsWith('@')) return NanoActionIntent.directCommand;
    if (const ['atrás', 'volver', 'back', 'vuelve atrás'].contains(lower)) {
      return NanoActionIntent.navBack;
    }
    if (const ['inicio', 'home', 'ir al inicio'].contains(lower)) {
      return NanoActionIntent.navHome;
    }
    if (const ['recientes', 'apps abiertas'].contains(lower)) {
      return NanoActionIntent.navRecents;
    }
    if (_hasToken(lower, 'telegram|tg')) return NanoActionIntent.telegram;
    if (_hasToken(lower, 'messenger|facebook|fb')) {
      return NanoActionIntent.messenger;
    }
    if (_hasToken(lower, 'whatsapp|wpp') ||
        RegExp(
          r'^(?:env[ií]a(?:le)?|manda(?:le)?|escr[ií]be(?:le)?)\s+'
          r'(?:a\s+)?\S.+(?:\s+que\s+|\s+diciendo\s+|:\s*).+',
        ).hasMatch(lower)) {
      return NanoActionIntent.whatsApp;
    }
    if (RegExp(
      r'^(?:(?:lee|leer|analiza|analizar|describe)\s+(?:la\s+)?pantalla'
      r'|(?:qué|que)\s+(?:hay|ves)\s+en\s+(?:la\s+)?pantalla)[.!?]?$',
    ).hasMatch(lower)) {
      return NanoActionIntent.readScreen;
    }
    if (RegExp(r'^(?:toca|pulsa|click|presiona)\s+\S').hasMatch(lower)) {
      return NanoActionIntent.tapElement;
    }
    if (RegExp(r'^(?:escribe|escribir|teclea)\s+\S').hasMatch(lower)) {
      return NanoActionIntent.typeText;
    }
    if (RegExp(r'^(?:abre|abrir|lanza|lanzar)\s+\S').hasMatch(lower)) {
      return NanoActionIntent.openApp;
    }
    return NanoActionIntent.unknown;
  }

  /// Usa palabras completas para que un nombre parecido no elija otra aplicación.
  static bool _hasToken(String text, String alternatives) =>
      RegExp('\\b(?:$alternatives)\\b').hasMatch(text);
}
