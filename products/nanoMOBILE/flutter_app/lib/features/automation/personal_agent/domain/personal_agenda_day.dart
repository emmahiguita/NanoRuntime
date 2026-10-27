import 'dart:convert';

enum PersonalAgendaKind { automatic, activity, work, breakfast, lunch, dinner }

/// Horarios locales declarados por el dueño; no implican aceptación de planes.
class PersonalAgendaEntry {
  const PersonalAgendaEntry(
    this.title,
    this.start,
    this.end, {
    this.kind = PersonalAgendaKind.automatic,
  });
  final PersonalAgendaKind kind;
  final String title;
  final int start;
  final int end;

  PersonalAgendaKind get resolvedKind {
    if (kind != PersonalAgendaKind.automatic) return kind;
    final name = title.trim().toLowerCase();
    for (final pair in {
      'trabajo': PersonalAgendaKind.work,
      'desayuno': PersonalAgendaKind.breakfast,
      'almuerzo': PersonalAgendaKind.lunch,
      'cena': PersonalAgendaKind.dinner,
    }.entries) {
      if (name == pair.key || name.startsWith('${pair.key} ')) {
        return pair.value;
      }
    }
    return PersonalAgendaKind.activity;
  }

  bool get isMeal => const {
    PersonalAgendaKind.breakfast,
    PersonalAgendaKind.lunch,
    PersonalAgendaKind.dinner,
  }.contains(resolvedKind);

  // Las comidas reservan una pausa laboral en cualquier orden de edición.
  bool conflictsWith(PersonalAgendaEntry other) =>
      overlaps(other) &&
      !((isMeal && other.resolvedKind == PersonalAgendaKind.work) ||
          (other.isMeal && resolvedKind == PersonalAgendaKind.work));

  static String clock(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';

  bool contains(DateTime now) =>
      start <= now.hour * 60 + now.minute && now.hour * 60 + now.minute < end;
  bool overlaps(PersonalAgendaEntry other) =>
      start < other.end && other.start < end;
  Map<String, Object> toJson() => {
    'title': title,
    'start': start,
    'end': end,
    'kind': kind.name,
  };

  static PersonalAgendaEntry? parse(Object? value) {
    if (value is! Map) return null;
    final title = value['title'], start = value['start'], end = value['end'];
    if (title is! String ||
        title.trim().isEmpty ||
        start is! int ||
        end is! int ||
        start < 0 ||
        end > 1439 ||
        start >= end) {
      return null;
    }
    return PersonalAgendaEntry(
      title.trim(),
      start,
      end,
      kind:
          PersonalAgendaKind.values
              .where((k) => k.name == value['kind'])
              .firstOrNull ??
          PersonalAgendaKind.automatic,
    );
  }
}

/// Cada fecha conserva sus notas y permiso de uso; acepta perfiles antiguos.
class PersonalAgendaDay {
  PersonalAgendaDay({
    this.enabled = true,
    this.notes = '',
    List<PersonalAgendaEntry>? entries,
  }) : entries = [...?entries]..sort((a, b) => a.start.compareTo(b.start));
  final bool enabled;
  final String notes;
  final List<PersonalAgendaEntry> entries;

  /// Proyección sin modificar el turno original: tras comer, se retoma trabajo.
  List<PersonalAgendaEntry> segmentsFor(PersonalAgendaEntry entry) {
    if (entry.resolvedKind != PersonalAgendaKind.work) return [entry];
    var segments = [entry];
    for (final meal in entries.where((e) => e.isMeal)) {
      segments = [
        for (final segment in segments)
          if (!segment.overlaps(meal))
            segment
          else ...[
            if (segment.start < meal.start)
              PersonalAgendaEntry(
                entry.title,
                segment.start,
                meal.start,
                kind: entry.kind,
              ),
            if (meal.end < segment.end)
              PersonalAgendaEntry(
                entry.title,
                meal.end,
                segment.end,
                kind: entry.kind,
              ),
          ],
      ];
    }
    return segments;
  }

  List<PersonalAgendaEntry> get effectiveEntries =>
      [for (final entry in entries) ...segmentsFor(entry)]
        ..sort((a, b) => a.start.compareTo(b.start));
  bool get hasContent => notes.trim().isNotEmpty || entries.isNotEmpty;
  Map<String, Object> toJson() => {
    'enabled': enabled,
    'notes': notes,
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  static Map<String, dynamic> calendar(Map<String, String> facts) {
    final raw = facts['agendaCalendar'];
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Calendario inválido');
    }
    return decoded;
  }

  static PersonalAgendaDay forDate(Map<String, String> facts, String date) {
    final weekday = DateTime.tryParse(date)?.weekday.toString();
    final weekly = jsonDecode(facts['agendaWeekly'] ?? '{}');
    final stored =
        calendar(facts)[date] ??
        (facts['agendaDate'] != date && weekly is Map ? weekly[weekday] : null);
    if (stored is Map) {
      return PersonalAgendaDay(
        enabled: stored['enabled'] == true,
        notes: stored['notes'] is String ? stored['notes'] as String : '',
        entries: (stored['entries'] is List ? stored['entries'] as List : [])
            .map(PersonalAgendaEntry.parse)
            .whereType<PersonalAgendaEntry>()
            .toList(),
      );
    }
    return PersonalAgendaDay(
      enabled: facts['agendaDate'] == date
          ? facts['agendaEnabled'] == 'true'
          : true,
      notes: facts['agendaDate'] == date ? facts['agendaToday'] ?? '' : '',
    );
  }
}
