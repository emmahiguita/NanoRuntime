import 'dart:convert';
import '../domain/personal_agenda_day.dart';
import 'persona_repository.dart';

/// Serializa cambios de Identidad/Agenda para conservar las demás claves del perfil.
abstract final class PersonalOwnerProfileEditor {
  static Future<void> _tail = Future.value();

  /// Fusiona solo la fecha editada dentro de la misma cola que Identidad.
  static Future<void> updateAgendaDay(
    String date,
    PersonalAgendaDay day, {
    bool? repeatWeekly,
  }) {
    final future = _tail.then((_) async {
      final repo = PersonaRepository.instance;
      final profiles = await repo.listPersonas(rethrowFailures: true);
      final owner = profiles.where((p) => p.personaKey == 'owner').firstOrNull;
      final facts = {...?owner?.facts};
      final calendar = PersonalAgendaDay.calendar(facts);
      calendar[date] = day.toJson();
      final weekly = Map<String, dynamic>.from(
        jsonDecode(facts['agendaWeekly'] ?? '{}') as Map,
      );
      final weekday = DateTime.parse(date).weekday.toString();
      if (repeatWeekly == true) weekly[weekday] = day.toJson();
      if (repeatWeekly == false) weekly.remove(weekday);
      final nextFacts = {
        ...facts,
        'agendaCalendar': jsonEncode(calendar),
        'agendaWeekly': jsonEncode(weekly),
      };
      if (jsonEncode(nextFacts).length > 20000) {
        throw StateError(
          'El calendario alcanzó el límite del perfil. Reduce notas o actividades antiguas.',
        );
      }
      final saved = await repo.upsertPersona(
        'owner',
        owner?.displayName ?? '',
        nextFacts,
      );
      if (!saved) throw StateError('No se pudo guardar el calendario');
    });
    _tail = future.then<void>((_) {}, onError: (Object _) {});
    return future;
  }

  // Un bool false de SQLite es un fallo real, no se muestra «guardado».
  static Future<void> update(Map<String, String> patch, {String? name}) {
    final future = _tail.then((_) async {
      final repo = PersonaRepository.instance;
      final profiles = await repo.listPersonas(rethrowFailures: true);
      final owner = profiles.where((p) => p.personaKey == 'owner').firstOrNull;
      final saved = await repo.upsertPersona(
        'owner',
        name ?? owner?.displayName ?? '',
        {...?owner?.facts, ...patch},
      );
      if (!saved) throw StateError('No se pudo guardar el perfil personal');
    });
    _tail = future.then<void>((_) {}, onError: (Object _) {});
    return future;
  }
}
