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

  /// "cuando Juan me escriba" / "si Juan me escribe".
  static final _notifyWriteRe = RegExp(
    r'(?:cuando|si)\s+(.+?)\s+(?:me\s+)?escrib',
    caseSensitive: false,
  );

  /// "cuando llegue (un) mensaje de X" / "mensaje de X".
  static final _notifyMessageRe = RegExp(
    r'mensaje\s+de\s+([\wáéíóúñÁÉÍÓÚÑ ]+)',
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
      final sender = w.group(1)!.trim();
      final goalRest = _goalAfterClause(g);
      if (sender.isEmpty) return null;
      return ParsedSchedule(
        NotificationTrigger(senderMatch: sender),
        goalRest,
      );
    }

    // 3. "mensaje de X" (dentro de una cláusula "cuando/si").
    final m = _notifyMessageRe.firstMatch(g);
    if (m != null && _hasTriggerMarker(g)) {
      final sender = m.group(1)!.trim();
      final goalRest = _goalAfterClause(g);
      if (sender.isEmpty) return null;
      return ParsedSchedule(
        NotificationTrigger(senderMatch: sender),
        goalRest,
      );
    }

    return null;
  }

  /// El objetivo es la cláusula tras la coma (si la hay); si no, el resto
  /// quitando la cláusula de disparo. Sin coma = sin goal explícito.
  bool _hasTriggerMarker(String g) =>
      g.toLowerCase().startsWith('cuando') || g.toLowerCase().startsWith('si');

  String _goalAfterClause(String g) {
    final comma = g.indexOf(',');
    if (comma >= 0) return g.substring(comma + 1).trim();
    return '';
  }
}
