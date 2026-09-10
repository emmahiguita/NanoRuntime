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
        return 'Todavía no lo tengo decidido.';

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
      return '¡Hola!';
    }

    if (cleaned.isNotEmpty && cleaned.length >= 2) {
      return cleaned;
    }

    final u = userText?.trim().toLowerCase() ?? '';
    if (u.contains('hola') || u.contains('buenas') || u.contains('buenos')) {
      return '¡Hola!';
    }

    return null;
  }
}

const safeConversationRepair = SafeConversationRepair();
