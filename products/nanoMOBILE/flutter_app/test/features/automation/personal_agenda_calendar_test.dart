import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/personal_agent/domain/personal_agenda_day.dart';
import 'package:nanoai/features/automation/personal_agent/domain/personal_daily_agenda.dart';
import 'package:nanoai/features/automation/personal_agent/application/personal_owner_profile_editor.dart';
import 'package:nanoai/features/automation/engine/language/runtime_personal_live_context.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 17, 12, 30);
  final today = PersonalDailyAgenda.dateKey(now);
  final lunch = PersonalAgendaDay(
    entries: [const PersonalAgendaEntry('Almuerzo', 720, 780)],
  );

  test('La repetición semanal respeta una excepción desactivada por fecha', () {
    final stored = {
      'agendaWeekly': jsonEncode({'6': lunch.toJson()}),
      'agendaCalendar': jsonEncode({
        '2026-10-24': PersonalAgendaDay(enabled: false).toJson(),
      }),
    };
    expect(
      PersonalDailyAgenda.promptBlock(stored, DateTime(2026, 10, 17, 12, 30)),
      contains('Almuerzo'),
    );
    expect(
      PersonalDailyAgenda.promptBlock(stored, DateTime(2026, 10, 18, 12, 30)),
      isEmpty,
    );
    expect(
      PersonalDailyAgenda.promptBlock(stored, DateTime(2026, 10, 24, 12, 30)),
      isEmpty,
    );
  });

  test(
    'Consultar mañana usa la fecha pedida sin presentarla como actividad actual',
    () async {
      final stored = {
        'agendaCalendar': jsonEncode({'2026-10-18': lunch.toJson()}),
      };
      final context = RuntimePersonalLiveContext(
        clock: () => now,
        allowDeclaredAgenda: true,
        ownerFactsFor: () async => stored,
      );
      final evidence = await context.resolve('¿Qué haces mañana?', []);
      expect(evidence.block, contains('para 2026-10-18'));
      expect(evidence.block, isNot(contains('Ahora, según')));
    },
  );
  Map<String, String> facts(PersonalAgendaDay day) => {
    'agendaCalendar': jsonEncode({
      today: day.toJson(),
      '2026-10-18': PersonalAgendaDay(
        entries: [
          const PersonalAgendaEntry('Actividad privada de mañana', 480, 540),
        ],
      ).toJson(),
    }),
  };

  test('El reloj selecciona el tramo actual sin incluir otras fechas', () {
    final block = PersonalDailyAgenda.promptBlock(facts(lunch), now);
    expect(block, contains('12:00–13:00: Almuerzo'));
    expect(block, contains('Ahora, según el horario declarado: Almuerzo'));
    expect(block, isNot(contains('Actividad privada de mañana')));
    expect(block, contains('No aceptes invitaciones'));
  });

  test('El fin es exclusivo y los huecos no prueban disponibilidad', () {
    final block = PersonalDailyAgenda.promptBlock(
      facts(lunch),
      DateTime(2026, 10, 17, 13),
    );
    expect(block, contains('Ahora: sin actividad declarada'));
    expect(block, contains('Un tramo vacío no demuestra disponibilidad'));
    expect(lunch.entries.single.contains(DateTime(2026, 10, 17, 12)), isTrue);
  });

  test('Desactivar o vaciar una fecha no revive la agenda antigua', () {
    for (final day in [
      PersonalAgendaDay(enabled: false, entries: lunch.entries),
      PersonalAgendaDay(),
    ]) {
      final stored = {
        ...facts(day),
        'agendaEnabled': 'true',
        'agendaDate': today,
        'agendaToday': 'Dato antiguo',
      };
      expect(PersonalDailyAgenda.isActiveToday(stored, now), isFalse);
      expect(PersonalDailyAgenda.promptBlock(stored, now), isEmpty);
    }
  });

  test(
    'Mantiene notas antiguas solo en su fecha y falla cerrado ante JSON dañado',
    () {
      final old = {
        'agendaEnabled': 'true',
        'agendaDate': today,
        'agendaToday': 'Trabajo por la tarde',
      };
      expect(
        PersonalDailyAgenda.promptBlock(old, now),
        contains('Trabajo por la tarde'),
      );
      expect(
        PersonalDailyAgenda.promptBlock(old, now.add(const Duration(days: 1))),
        isEmpty,
      );
      expect(
        PersonalDailyAgenda.promptBlock({'agendaCalendar': '{'}, now),
        isEmpty,
      );
    },
  );

  test(
    'Horarios adyacentes son válidos; cruces y registros inválidos se detectan',
    () {
      const work = PersonalAgendaEntry('Trabajo', 480, 720);
      expect(work.overlaps(lunch.entries.single), isFalse);
      expect(
        work.overlaps(const PersonalAgendaEntry('Otra', 710, 730)),
        isTrue,
      );
      expect(
        PersonalAgendaEntry.parse({'title': 'Mal', 'start': 800, 'end': 700}),
        isNull,
      );
    },
  );

  test('Guardar dos fechas y la identidad conserva todos los datos', () async {
    var stored = <String, String>{
      'notas': 'Mi perfil',
      'agendaToday': 'Nota anterior',
    };
    const channel = MethodChannel('com.nanoai/automation_store');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'personaList') {
        return [
          {
            'personaKey': 'owner',
            'displayName': 'Emmanuel',
            'factsJson': jsonEncode(stored),
          },
        ];
      }
      if (call.method == 'personaUpsert') {
        stored = Map<String, String>.from(
          jsonDecode((call.arguments as Map)['factsJson'] as String) as Map,
        );
        return 1;
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await Future.wait([
      PersonalOwnerProfileEditor.updateAgendaDay(today, lunch),
      PersonalOwnerProfileEditor.update({'notas': 'Perfil editado'}),
      PersonalOwnerProfileEditor.updateAgendaDay('2026-10-18', lunch),
    ]);
    expect(stored['notas'], 'Perfil editado');
    expect(stored['agendaToday'], 'Nota anterior');
    expect(
      PersonalAgendaDay.calendar(stored).keys,
      containsAll([today, '2026-10-18']),
    );
  });

  test(
    'Una invitación recibe la agenda habilitada, sin leer otros chats',
    () async {
      var storeReads = 0;
      const channel = MethodChannel('com.nanoai/automation_store');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        storeReads++;
        return [];
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final context = RuntimePersonalLiveContext(
        clock: () => now,
        allowDeclaredAgenda: true,
        ownerFactsFor: () async => facts(lunch),
      );
      final evidence = await context.resolve(
        'O nos vamos de fiesta',
        [],
        scopeId: 'juan',
      );
      expect(evidence.block, contains('Almuerzo'));
      expect(evidence.block, isNot(contains('Actividad privada de mañana')));
      expect(storeReads, 0);
      final disabled = RuntimePersonalLiveContext(
        clock: () => now,
        allowDeclaredAgenda: true,
        ownerFactsFor: () async =>
            facts(PersonalAgendaDay(enabled: false, entries: lunch.entries)),
      );
      expect(
        (await disabled.resolve('O nos vamos de fiesta', [])).block,
        isNot(contains('Almuerzo')),
      );
    },
  );
}
