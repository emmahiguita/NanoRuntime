import 'personal_agenda_day.dart';
import 'personal_daily_agenda.dart';

/// QUÉ: proyecta preferencias y estado declarado con su vigencia real.
/// CÓMO: el estado vence al cambiar de fecha; la agenda usa tramos efectivos.
/// POR QUÉ: guardar «ocupado» ayer no debe describir automáticamente hoy.
abstract final class OwnerDeclaredContext {
  static String preferences(Map<String, String> facts, {int maxChars = 600}) {
    final text = (facts['preferences'] ?? '').trim();
    return text.isEmpty
        ? ''
        : 'Preferencias declaradas: ${_limit(text, maxChars)}';
  }

  static String status(Map<String, String> facts, DateTime now) =>
      facts['dailyStatusDate'] == PersonalDailyAgenda.dateKey(now)
      ? (facts['dailyStatus'] ?? '').trim()
      : '';

  static List<String> activeLabels(Map<String, String> facts, DateTime now) {
    final state = status(facts, now);
    try {
      final day = PersonalAgendaDay.forDate(
        facts,
        PersonalDailyAgenda.dateKey(now),
      );
      return [
        if (state.isNotEmpty) state,
        if (day.enabled)
          ...day.effectiveEntries
              .where((e) => e.contains(now))
              .map((e) => e.title),
      ];
    } on FormatException {
      return [if (state.isNotEmpty) state];
    }
  }

  static String currentBlock(Map<String, String> facts, DateTime now) {
    final state = status(facts, now);
    final active = activeLabels(facts, now);
    return [
      if (state.isNotEmpty)
        'Estado declarado hoy por el dueño: ${_limit(state, 250)}.',
      if (active.isNotEmpty)
        'Actividad declarada en este momento: ${active.join('; ')}.',
      if (active.isNotEmpty)
        'Fuente: declaración y horario, no ubicación observada. No demuestra pagos ni aceptación de planes.',
    ].join('\n');
  }

  static String _limit(String text, int max) =>
      text.length > max ? text.substring(0, max) : text;
}
