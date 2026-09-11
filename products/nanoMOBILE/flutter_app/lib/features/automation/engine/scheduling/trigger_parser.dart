/// TriggerParser (T3.0) — parsea lenguaje natural → Trigger + goal.
///
/// Determinista, 0 LLM. Cubre los patrones de T3:
///   "todos los días a las 8 abre Chrome"      → TimeTrigger(8:00) + "abre Chrome"
///   "a las 8:30 abre YouTube"                  → TimeTrigger(8:30) + "abre YouTube"
///   "cuando Juan me escriba, avísame"          → NotificationTrigger(juan) + "avísame"
///   "cuando llegue un mensaje de Pedro, …"     → NotificationTrigger(pedro) + resto
///
/// PACKAGE-SCOPE-01 — packageName SIEMPRE explícito en NotificationTrigger:
///   - "de whatsapp business" / "de business"   → MessagingPackage.whatsappBusiness
///   - "de telegram"                            → MessagingPackage.telegram
///   - "cualquier app" / "cualquier aplicación" → null (opt-in consciente del usuario)
///   - sin mención de app                       → MessagingPackage.whatsapp (default)
///
/// Devuelve null si no reconoce un disparo (no inventa). El goal NO se ejecuta
/// aquí: solo se devuelve como string para que el motor T2 lo procese.
library;

import '../messaging/messaging_package.dart';
import 'trigger.dart';

/// Trigger + objetivo parseados de una orden persistente.
class ParsedSchedule {
  final Trigger trigger;
  final String goal;
  const ParsedSchedule(this.trigger, this.goal);
}

class TriggerParser {
  const TriggerParser();

  static final _timeRe = RegExp(
    r'a\s+las\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?',
    caseSensitive: false,
  );

  /// Calificadores de frecuencia que NO son el goal ("todos los días", "cada día").
  static final _frequencyPrefix = RegExp(
    r'^(todos los días|todos los dias|cada día|cada dia|diario|diariamente)\s+',
    caseSensitive: false,
  );

  /// "cuando Juan me escriba" / "si Juan me escribe" / "cuando me digan hola".
  /// `dig[ao]` cubre diga/digas/digan/digo sin matchear "dime".
  static final _notifyWriteRe = RegExp(
    r'(?:cuando|si)\s+(.+?)\s+(?:me\s+)?(?:escrib|dig[ao])',
    caseSensitive: false,
  );

  /// "mensaje de X" (dentro de una cláusula "cuando/si"). La captura para en
  /// comilla, coma o fin: el texto tras el remitente es el filtro, no parte
  /// del nombre ("mensaje de Pedro 'hola'" → Pedro + hola).
  /// (String normal con escapes: la raw del plan se rompía — " dentro de r"".)
  static final _notifyMessageRe = RegExp(
    "mensaje\\s+de\\s+(.+?)(?=\\s+['\"]|,|\$)",
    caseSensitive: false,
  );

  /// Disparo directo por palabra clave / contenido (ej: "si dice hola", "con palabra clave precio", "keyword noche").
  static final _notifyKeywordRe = RegExp(
    r'^(?:cuando|si)?\s*(?:el\s+mensaje\s+)?(?:con\s+(?:la\s+)?)?(?:palabra\s+clave|keyword|contenga|contiene|dice|diga|digan)\s+([^\s,]+|[\x22\x27][^\x22\x27]+[\x22\x27])',
    caseSensitive: false,
  );

  /// Verbos de acción conocidos para partir trigger y objetivo sin depender de comas obligatorias.
  static final _actionVerbsRe = RegExp(
    r'\b(respóndele|respondele|responde|responder|contéstale|contestale|contesta|contestar|avísame|avisame|avisar|notifícame|notificame|notificar|envíale|enviale|envía|envia|mándale|mandale|manda)\b',
    caseSensitive: false,
  );

  // PACKAGE-SCOPE-01 — detectores de app en la cláusula completa del goal.
  static final _wabRe = RegExp(
    r'\bde\s+(?:whatsapp\s+business|business|whatsapp\.w4b)\b',
    caseSensitive: false,
  );
  static final _waRe = RegExp(
    r'\bde\s+whatsapp\b',
    caseSensitive: false,
  );
  static final _telegramRe = RegExp(
    r'\bde\s+telegram\b',
    caseSensitive: false,
  );
  static final _anyAppRe = RegExp(
    r'\b(?:cualquier\s+app|cualquier\s+aplicaci[oó]n|de\s+cualquier\s+app)\b',
    caseSensitive: false,
  );

  /// PACKAGE-SCOPE-01 — resuelve el packageName a partir del texto completo
  /// del goal. null = "cualquier app" (intención consciente, no default).
  /// Sin mención de app → default WhatsApp (cierra bug packageName=null → eligible_packages=*).
  static String? _resolvePackage(String g) {
    if (_anyAppRe.hasMatch(g)) return null; // opt-in consciente del usuario
    if (_wabRe.hasMatch(g)) return MessagingPackage.whatsappBusiness;
    if (_telegramRe.hasMatch(g)) return MessagingPackage.telegram;
    // "de whatsapp" sin business → WhatsApp estándar.
    // Sin mención de app → default WhatsApp (no null).
    if (_waRe.hasMatch(g)) return MessagingPackage.whatsapp;
    return MessagingPackage.whatsapp; // default seguro
  }

  ParsedSchedule? parse(String goal) {
    final g = goal.trim();
    if (g.isEmpty) return null;

    // 1. Disparo por hora (solo si no es una cláusula de notificación "cuando/si/con/keyword").
    final t = !_hasTriggerMarker(g) ? _timeRe.firstMatch(g) : null;
    if (t != null) {
      var hour = int.tryParse(t.group(1)!);
      final minute = int.tryParse(t.group(2) ?? '') ?? 0;
      if (hour == null) return null;
      if (t.group(3)?.toLowerCase() == 'pm' && hour < 12) hour += 12;
      if (t.group(3)?.toLowerCase() == 'am' && hour == 12) hour = 0;
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
      final goalRest = g
          .replaceFirst(_timeRe, '')
          .replaceAll(',', '')
          .replaceFirst(_frequencyPrefix, '')
          .trim();
      return ParsedSchedule(
        TimeTrigger(hour: hour, minute: minute),
        goalRest,
      );
    }

    // 2. Disparo por notificación ("cuando X me escriba, …").
    final w = _notifyWriteRe.firstMatch(g);
    if (w != null && _hasTriggerMarker(g)) {
      var sender = w.group(1)!.trim();
      // "me" es reflexivo ("cuando me digan hola"), no un remitente.
      if (sender.toLowerCase() == 'me') sender = '';
      final (textMatch, goalRest) = _textAndGoal(g.substring(w.end));
      if (sender.isEmpty && textMatch == null) return null;
      return ParsedSchedule(
        NotificationTrigger(
          packageName: _resolvePackage(g), // PACKAGE-SCOPE-01: siempre explícito
          senderMatch: sender.isEmpty ? null : sender,
          textMatch: textMatch,
        ),
        goalRest,
      );
    }

    // 3. "mensaje de X" (dentro de una cláusula "cuando/si").
    final m = _notifyMessageRe.firstMatch(g);
    if (m != null && _hasTriggerMarker(g)) {
      final sender = m.group(1)!.trim();
      final (textMatch, goalRest) = _textAndGoal(g.substring(m.end));
      if (sender.isEmpty && textMatch == null) return null;
      return ParsedSchedule(
        NotificationTrigger(
          packageName: _resolvePackage(g), // PACKAGE-SCOPE-01: siempre explícito
          senderMatch: sender.isEmpty ? null : sender,
          textMatch: textMatch,
        ),
        goalRest,
      );
    }

    // 4. Disparo directo por palabra clave / contenido ("si dice hola", "con palabra clave precio", "keyword noche").
    final kw = _notifyKeywordRe.firstMatch(g);
    if (kw != null) {
      final rawKw = kw.group(1)!.replaceAll(RegExp(r'''['"]'''), '').trim();
      final rest = g.substring(kw.end).trim();
      final (_, goalRest) = _textAndGoal(rest);
      if (rawKw.isNotEmpty) {
        return ParsedSchedule(
          NotificationTrigger(
            packageName: _resolvePackage(g),
            senderMatch: null,
            textMatch: rawKw,
          ),
          goalRest.isEmpty ? rest.replaceFirst(RegExp(r'^,\s*'), '') : goalRest,
        );
      }
    }

    return null;
  }

  /// El objetivo es la cláusula tras la coma (si la hay); si no, el resto
  /// quitando la cláusula de disparo. Sin coma = sin goal explícito.
  bool _hasTriggerMarker(String g) {
    final lower = g.toLowerCase();
    return lower.startsWith('cuando') ||
        lower.startsWith('si') ||
        lower.startsWith('con ') ||
        lower.startsWith('palabra ') ||
        lower.startsWith('keyword');
  }

  /// Del resto tras el verbo extrae (textMatch, goal): el texto antes de la
  /// coma o verbo de acción y el goal a partir de la coma o verbo.
  (String?, String) _textAndGoal(String rest) {
    final r = rest.trim();
    int splitIdx = r.indexOf(',');
    if (splitIdx < 0) {
      final m = _actionVerbsRe.firstMatch(r);
      if (m != null && m.start > 0) {
        splitIdx = m.start;
      }
    }
    final textPart = (splitIdx >= 0 ? r.substring(0, splitIdx) : r).trim();
    final goalRest = (splitIdx >= 0 ? r.substring(splitIdx) : '')
        .replaceFirst(RegExp(r'^,\s*'), '')
        .trim();
    if (textPart.isEmpty) return (null, goalRest);
    final quoted = RegExp(r'''['"](.+?)['"]''').firstMatch(textPart);
    if (quoted != null) {
      final inner = quoted.group(1)!.trim();
      return (inner.isEmpty ? null : inner, goalRest);
    }
    final cleaned = textPart.replaceFirst(
      RegExp(
        r'^(?:con\s+(?:la\s+)?)?(?:palabra\s+clave|keyword|dice|diga|contenga|contiene)\s+',
        caseSensitive: false,
      ),
      '',
    ).trim();
    return (cleaned.isEmpty ? null : cleaned, goalRest);
  }
}
