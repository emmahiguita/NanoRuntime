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
      case RepairCase.liveStateQuestionMirror:
      case RepairCase.liveStateAffirmed:
        final u = userText?.trim().toLowerCase() ?? '';
        final isActivityOrPlans =
            u.contains('hacer') ||
            u.contains('haces') ||
            u.contains('haciendo') ||
            u.contains('haras') ||
            u.contains('planes') ||
            u.contains('pensado') ||
            u.contains('estas en') ||
            u.contains('en que andas') ||
            u.contains('que cuentas') ||
            u.contains('que hay de nuevo');
        if (isActivityOrPlans) {
          return _pick(safeRepairActivityOptions, userText);
        }

        final isGoingOrOut =
            u.contains('vas a ir') ||
            u.contains('vas ir') ||
            u.contains('iras') ||
            u.contains('vas a salir') ||
            u.contains('vas a caer') ||
            u.contains('vas a venir') ||
            u.contains('sales hoy') ||
            u.contains('salir') ||
            u.contains('caer') ||
            (u.contains('ir') && !u.contains('decir'));
        if (isGoingOrOut) {
          return _pick(safeRepairGoingOptions, userText);
        }

        return _pick(safeRepairGeneralLiveStateOptions, userText);

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
        r'¿?(?:en qué|en que|cómo|como)\s+(?:te|le|nos)?\s*(?:puedo|podemos|te puedo|le puedo)\s+(?:ayudar|colaborar|asistir)(?:te|le|les|nos)?(?:\s+hoy|\s+en algo)?\??',
        caseSensitive: false,
      ),
      RegExp(
        r'¿?(?:en qué|en que)\s+(?:te|le)\s+(?:ayudo|colaboro)\??',
        caseSensitive: false,
      ),
      RegExp(
        r'¿?(?:puedo|te puedo|le puedo)\s+(?:ayudar|colaborar|asistir)(?:te|le|les|nos)?(?:\s+en algo|\s+hoy)?\??',
        caseSensitive: false,
      ),
      RegExp(
        r'¿?(?:que|qué)\s+(?:puedo\s+)?hacer\s+por\s+(?:ti|usted|vos)\??',
        caseSensitive: false,
      ),
      RegExp(
        r'puedo\s+hacer\s+por\s+(?:ti|usted|vos)',
        caseSensitive: false,
      ),
      RegExp(
        r'hacer\s+por\s+(?:ti|usted|vos)',
        caseSensitive: false,
      ),
      RegExp(
        r'¿?(?:que|qué)\s+necesitas\??',
        caseSensitive: false,
      ),
      RegExp(
        r'¿?(?:deseas|necesitas)\s+algo\??',
        caseSensitive: false,
      ),
      RegExp(
        r'¿?(?:en qué|en que)\s+m[aá]s\??',
        caseSensitive: false,
      ),
      RegExp(
        r'¿?algo\s+m[aá]s\??',
        caseSensitive: false,
      ),
      RegExp(
        r'a\s+(?:su|tu)\s+disposici[oó]n',
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
      RegExp(
        r'¿?(?:en qué|en que|cómo|como)\s+puedo\s+ser(?:te)?\s+[uú]til\??',
        caseSensitive: false,
      ),
      RegExp(
        r'ser(?:te)?\s+[uú]til',
        caseSensitive: false,
      ),
    ];

    var cleaned = reply;
    for (final p in phrases) {
      cleaned = cleaned.replaceAll(p, '');
    }
    for (final phrase in [
      'puedo ayudarte',
      'en que te ayudo',
      'en que mas',
      'algo mas',
      'deseas algo',
      'necesitas algo',
      'ser util',
      'que necesitas',
      'puedo hacer por',
      'hacer por ti',
      'hacer por usted',
      'puedo ayudarte en',
      'como puedo ayudarte',
      'como puedo ayudar',
      'en que puedo ayudarte',
      'en que puedo ayudar',
      'a su disposicion',
      'a tu disposicion',
      'soy nano',
    ]) {
      cleaned = cleaned.replaceAll(
        RegExp(RegExp.escape(phrase), caseSensitive: false),
        '',
      );
    }
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    cleaned = cleaned.replaceAll(RegExp(r'[,.\s]+$'), '').trim();

    final lower = cleaned.toLowerCase();
    if (lower == 'hola' ||
        lower == '¡hola!' ||
        lower == 'hola!' ||
        cleaned.isEmpty ||
        cleaned.length < 2) {
      return _pick(safeRepairCallCenterGreetingOptions, userText);
    }

    return cleaned;
  }
}

const safeConversationRepair = SafeConversationRepair();
