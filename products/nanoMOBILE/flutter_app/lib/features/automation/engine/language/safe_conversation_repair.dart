/// WA-LIVE-STATE-REPAIR-01 — Motor de reparación determinista sin LLM.
///
/// **QUÉ HACE:**
/// Corrige muletillas de call-center y preguntas redundantes con reemplazos seguros.
///
/// **CÓMO FUNCIONA:**
/// Clasifica el tipo de fallo (RepairCase), extrae intenciones del texto de entrada
/// y selecciona deterministamente un candidato de los catálogos en safe_repair_options.dart.
///
/// **POR QUÉ:**
/// Evita silenciar la conversación con un hold innecesario y garantiza que nunca se
/// afirmen estados no verificables ni se use lenguaje robótico/corporativo.
library;

import 'safe_repair_options.dart';

enum RepairCase {
  echoReply,
  callCenterPhrase,
  wrongTurnGreeting,
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
      case RepairCase.redundantQuestion:
        return _repairRedundantQuestion(reply, userText: userText);

      case RepairCase.callCenterPhrase:
        return _repairCallCenter(reply, userText: userText);

      case RepairCase.wrongTurnGreeting:
        return null;

      case RepairCase.echoReply:
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

    return _pick(safeRepairRedundantOptions, userText);
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
    final u = userText?.trim().toLowerCase() ?? '';
    if (lower == 'hola' || lower == '¡hola!' || lower == 'hola!') {
      return _pick(safeRepairCallCenterGreetingOptions, userText);
    }

    if (cleaned.isNotEmpty && cleaned.length >= 2) {
      return cleaned;
    }

    if (u.contains('hola') || u.contains('buenas') || u.contains('buenos')) {
      return _pick(safeRepairCallCenterGreetingOptions, userText);
    }

    return null;
  }
}

const safeConversationRepair = SafeConversationRepair();
