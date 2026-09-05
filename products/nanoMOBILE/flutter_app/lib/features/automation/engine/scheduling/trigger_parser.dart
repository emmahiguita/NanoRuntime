/// TriggerParser (T3.0) — parsea lenguaje natural → Trigger + goal.
///
/// Determinista, 0 LLM. Cubre los patrones de T3:
///   "todos los días a las 8 abre Chrome"      → TimeTrigger(8:00) + "abre Chrome"
///   "a las 8:30 abre YouTube"                  → TimeTrigger(8:30) + "abre YouTube"
///   "cuando Juan me escriba, avísame"          → NotificationTrigger(juan) + "avísame"
///   "cuando llegue un mensaje de Pedro, …"     → NotificationTrigger(pedro) + resto
///
/// Devuelve null si no reconoce un disparo (no inventa). El goal NO se ejecuta
/// aquí: solo se devuelve como string para que el motor T2 lo procese.
library;

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
  static final _notifyMessageRe = RegExp(
    r"mensaje\s+de\s+(.+?)(?=\s+['\"]|,|$)",
    caseSensitive: false,
  );

  ParsedSchedule? parse(String goal) {
    final g = goal.trim();
    if (g.isEmpty) return null;

    // 1. Disparo por hora.
    final t = _timeRe.firstMatch(g);
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
          senderMatch: sender.isEmpty ? null : sender,
          textMatch: textMatch,
        ),
        goalRest,
      );
    }

    return null;
  }

  /// El objetivo es la cláusula tras la coma (si la hay); si no, el resto
  /// quitando la cláusula de disparo. Sin coma = sin goal explícito.
  bool _hasTriggerMarker(String g) =>
      g.toLowerCase().startsWith('cuando') || g.toLowerCase().startsWith('si');

  /// Del resto tras el verbo extrae (textMatch, goal): el texto antes de la
  /// coma (sin coma → todo) y el goal tras la coma. Comillas → contenido
  /// entre comillas. Vacío → textMatch null (no se inventa un filtro).
  (String?, String) _textAndGoal(String rest) {
    final r = rest.trim();
    final comma = r.indexOf(',');
    final textPart = (comma >= 0 ? r.substring(0, comma) : r).trim();
    final goalRest = comma >= 0 ? r.substring(comma + 1).trim() : '';
    if (textPart.isEmpty) return (null, goalRest);
    final quoted = RegExp(r'''['"](.+?)['"]''').firstMatch(textPart);
    if (quoted != null) {
      final inner = quoted.group(1)!.trim();
      return (inner.isEmpty ? null : inner, goalRest);
    }
    return (textPart, goalRest);
  }
}
