import 'personal_agenda_day.dart';

/// Proyecta la fecha actual del calendario al contexto real del modelo.
abstract final class PersonalDailyAgenda {
  // Fecha local explícita: una nota de ayer no describe el estado actual.
  static String dateKey(DateTime now) =>
      '${now.year}-'
      '${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  static bool isActiveToday(Map<String, String> facts, DateTime now) {
    final day = _today(facts, now);
    return day.enabled && day.hasContent;
  }

  static PersonalAgendaDay _today(Map<String, String> facts, DateTime now) {
    try {
      return PersonalAgendaDay.forDate(facts, dateKey(now));
    } on FormatException {
      return PersonalAgendaDay(enabled: false);
    }
  }

  static String promptBlock(
    Map<String, String> facts,
    DateTime now, {
    DateTime? date,
  }) {
    final target = date ?? now;
    final day = _today(facts, target);
    if (!day.enabled || !day.hasContent) return '';
    final text = day.notes.trim();
    final bounded = text.length <= 1000 ? text : text.substring(0, 1000);
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final schedule = day.effectiveEntries;
    final active = schedule.where((entry) => entry.contains(now));
    return [
      'CRONOGRAMA DECLARADO DEL DUEÑO para ${dateKey(target)} (hoy ${dateKey(now)}, hora actual $hh:$mm):',
      for (final entry in schedule)
        '${PersonalAgendaEntry.clock(entry.start)}–${PersonalAgendaEntry.clock(entry.end)}: ${entry.title}',
      if (bounded.isNotEmpty) 'Notas del día: $bounded',
      if (day.entries.isNotEmpty && dateKey(target) == dateKey(now))
        active.isEmpty
            ? 'Ahora: sin actividad declarada en este tramo.'
            : 'Ahora, según el horario declarado: ${active.map((e) => e.title).join('; ')}.',
      'Distingue actividades pasadas, actuales y futuras usando la hora actual. '
          'El horario declarado no es una comprobación de ubicación. '
          'Un tramo vacío no demuestra disponibilidad, dinero ni intención de salir. '
          'No aceptes invitaciones ni compromisos por el dueño solo por tener un hueco. '
          'Si preguntan por un horario o dato que NO aparece aquí, di con naturalidad que no lo sabes.',
    ].join('\n');
  }
}
