/// WA-LIVE-STATE-REPAIR-01 — Motor de reparación determinista sin LLM.
///
/// Corrige fallos de calidad comunes (live-state afirmado o espejado,
/// muletillas de call-center en turnos personales) devolviendo un reemplazo
/// seguro y honesto para evitar silenciar la conversación con un hold innecesario.
library;

enum RepairCase {
  echoReply,
  callCenterPhrase,
  wrongTurnGreeting,
  liveStateAffirmed,
  liveStateQuestionMirror,
  redundantQuestion,
}

final class SafeConversationRepair {
  const SafeConversationRepair();

  static const defaultInstance = SafeConversationRepair();

  /// Intenta reparar el texto según el tipo de fallo de calidad.
  /// Devuelve null si no hay reparación segura posible (se debe retener).
  String? repair(
    RepairCase cause, {
    required String reply,
    String? userText,
    String? senderName,
  }) {
    switch (cause) {
      case RepairCase.liveStateAffirmed:
      case RepairCase.liveStateQuestionMirror:
        // En preguntas sobre la actividad o estado presente/futuro del dueño
        // donde no hay fuente viva, responder honestamente sin inventar.
        final u = userText?.toLowerCase() ?? '';
        if (u.contains('vas') ||
            u.contains('iras') ||
            u.contains('planeas') ||
            u.contains('ir') ||
            u.contains('salir')) {
          return _pick([
            'Todavía no sé si voy a ir hoy.',
            'Aún no confirmo si salgo más tarde.',
            'No estoy seguro todavía si voy.',
          ], userText);
        }
        if (u.contains('haces') ||
            u.contains('haciendo') ||
            u.contains('estas en') ||
            u.contains('en que andas')) {
          return _pick([
            'Por acá tranquilo por ahora.',
            'Aquí pendiente.',
            'Bien, por acá ocupado un rato.',
            'Todo en orden por aquí.',
          ], userText);
        }
        return _pick([
          'Todavía no lo tengo decidido.',
          'Aún no lo sé con certeza.',
          'Todavía no defino eso bien.',
        ], userText);

      case RepairCase.redundantQuestion:
        return _repairRedundantQuestion(reply, userText: userText);

      case RepairCase.callCenterPhrase:
        return _repairCallCenter(reply, userText: userText);

      case RepairCase.wrongTurnGreeting:
        // Saludo fuera de turno: si no fue saludo, no podemos adivinar la intención
        return null;

      case RepairCase.echoReply:
        // El modelo repitió textualmente al cliente: no hay reparación segura sin LLM
        return null;
    }
  }

  static String _pick(List<String> options, String? seed) {
    if (seed == null || seed.isEmpty) return options.first;
    final idx = seed.codeUnits.fold(0, (a, b) => a + b) % options.length;
    return options[idx];
  }

  static String? _repairRedundantQuestion(String reply, {String? userText}) {
    final redundantRegexes = [
      RegExp(
        r'¿?(?:y\s+)?(?:que|qué)\s+tal(?:\s+(?:tu|el|su))?\s+d[ií]a\??',
        caseSensitive: false,
      ),
      RegExp(
        r'¿?(?:cómo|como)\s+(?:te\s+ha\s+ido|te\s+fue|va\s+tu\s+d[ií]a)\??',
        caseSensitive: false,
      ),
      RegExp(
        r'¿?(?:y\s+)?(?:t[uú]|usted)\s+(?:que|qué)\s+tal\??',
        caseSensitive: false,
      ),
    ];

    var cleaned = reply;
    for (final r in redundantRegexes) {
      cleaned = cleaned.replaceAll(r, '');
    }
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    cleaned = cleaned.replaceAll(RegExp(r'[,.\s]+$'), '').trim();

    if (cleaned.isNotEmpty && cleaned.length >= 2) {
      return cleaned;
    }

    return _pick([
      'Por acá todo bien también.',
      'Todo en orden por acá.',
      'Bien, todo tranquilo.',
    ], userText);
  }

  static String? _repairCallCenter(String reply, {String? userText}) {
    final phrases = [
      RegExp(
        r'¿?(?:en qué|en que|cómo|como)\s+(?:te|le|nos)?\s*(?:puedo|podemos|te puedo|le puedo)\s+(?:ayudar|colaborar|asistir)(?:te|le|les|nos)?(?:\s+hoy)?\??',
        caseSensitive: false,
      ),
      RegExp(
        r'soy nano,?\s*(?:el asistente(?: de este negocio)?)?\.?',
        caseSensitive: false,
      ),
      RegExp(
        r'¿?(?:cómo|como)\s+estás\??\s*¿?(?:cómo|como)\s+puedo\s+ayudar(?:te)?(?:\s+hoy)?\??',
        caseSensitive: false,
      ),
    ];

    var cleaned = reply;
    for (final p in phrases) {
      cleaned = cleaned.replaceAll(p, '');
    }
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    cleaned = cleaned.replaceAll(RegExp(r'[,.\s]+$'), '').trim();

    final lower = cleaned.toLowerCase();
    if (lower == 'hola' || lower == '¡hola!' || lower == 'hola!') {
      return _pick(['¡Hola!', 'Hola, ¿cómo estás?', '¡Buenas! ¿Todo bien?', 'Hola, ¿qué tal?'], userText);
    }

    if (cleaned.isNotEmpty && cleaned.length >= 2) {
      return cleaned;
    }

    final u = userText?.trim().toLowerCase() ?? '';
    if (u.contains('hola') || u.contains('buenas') || u.contains('buenos')) {
      return _pick(['¡Hola!', 'Hola, ¿cómo estás?', '¡Buenas! ¿Todo bien?', 'Hola, ¿qué tal?'], userText);
    }

    return null;
  }
}

const safeConversationRepair = SafeConversationRepair();
