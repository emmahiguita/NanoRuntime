import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/personal_agent/domain/personal_agenda_day.dart';
import 'package:nanoai/features/automation/personal_agent/domain/personal_daily_agenda.dart';
import 'package:nanoai/features/automation/presentation/personal/nano_personal_agenda_dialog.dart';

void main() {
  const work = PersonalAgendaEntry('Trabajo', 420, 1320);
  const meals = [
    PersonalAgendaEntry('Desayuno', 480, 510),
    PersonalAgendaEntry('Almuerzo', 720, 780),
    PersonalAgendaEntry('Cena', 1140, 1200),
  ];

  test('Cada comida interrumpe el trabajo y este se retoma al terminar', () {
    final day = PersonalAgendaDay(entries: [work, ...meals]);
    expect(day.segmentsFor(work).map((e) => [e.start, e.end]).toList(), [
      [420, 480],
      [510, 720],
      [780, 1140],
      [1200, 1320],
    ]);
    for (final meal in meals) {
      expect(work.conflictsWith(meal), isFalse);
      expect(meal.conflictsWith(work), isFalse);
      final now = DateTime(2026, 10, 17, meal.start ~/ 60, meal.start % 60);
      expect(
        day.effectiveEntries.where((e) => e.contains(now)).single.title,
        meal.title,
      );
    }
    expect(day.entries.first.end, 1320);
    expect(
      day.effectiveEntries
          .where((e) => e.contains(DateTime(2026, 10, 17, 13)))
          .single
          .title,
      'Trabajo',
    );
  });

  test('No permite comidas duplicadas ni cruce con otras actividades', () {
    expect(
      meals[1].conflictsWith(
        const PersonalAgendaEntry(
          'Comida',
          750,
          800,
          kind: PersonalAgendaKind.lunch,
        ),
      ),
      isTrue,
    );
    expect(
      meals[1].conflictsWith(const PersonalAgendaEntry('Reunión', 750, 800)),
      isTrue,
    );
    expect(
      work.conflictsWith(
        const PersonalAgendaEntry(
          'Otro trabajo',
          600,
          700,
          kind: PersonalAgendaKind.work,
        ),
      ),
      isTrue,
    );
  });

  test('Pausas en límites, turno cubierto y títulos personalizados', () {
    final day = PersonalAgendaDay(
      entries: [
        const PersonalAgendaEntry(
          'Oficina',
          480,
          780,
          kind: PersonalAgendaKind.work,
        ),
        const PersonalAgendaEntry(
          'Comer',
          420,
          540,
          kind: PersonalAgendaKind.breakfast,
        ),
        const PersonalAgendaEntry(
          'Con familia',
          720,
          840,
          kind: PersonalAgendaKind.lunch,
        ),
      ],
    );
    expect(
      day.segmentsFor(day.entries[1]).map((e) => [e.start, e.end]).toList(),
      [
        [540, 720],
      ],
    );
    final covered = PersonalAgendaDay(
      entries: [const PersonalAgendaEntry('Trabajo', 720, 780), meals[1]],
    );
    expect(covered.effectiveEntries.single.title, 'Almuerzo');
    expect(
      PersonalAgendaEntry.parse(day.entries[1].toJson())?.resolvedKind,
      PersonalAgendaKind.work,
    );
    expect(
      PersonalAgendaEntry.parse({
        'title': 'Almuerzo',
        'start': 720,
        'end': 780,
      })?.isMeal,
      isTrue,
    );
  });

  test(
    'Contexto usa pausa actual y turnos divididos, sin inventar comidas',
    () {
      final day = PersonalAgendaDay(entries: [work, ...meals]);
      final facts = {
        'agendaCalendar': jsonEncode({'2026-10-17': day.toJson()}),
      };
      final prompt = PersonalDailyAgenda.promptBlock(
        facts,
        DateTime(2026, 10, 17, 12, 30),
      );
      expect(prompt, contains('Ahora, según el horario declarado: Almuerzo.'));
      expect(prompt, contains('13:00–19:00: Trabajo'));
      expect(prompt, isNot(contains('07:00–22:00: Trabajo')));
      expect(PersonalAgendaDay(entries: [work]).effectiveEntries.single, work);
      final restored = PersonalAgendaDay.forDate(facts, '2026-10-17');
      expect(restored.segmentsFor(restored.entries.first).length, 4);
    },
  );

  testWidgets('Editor permite reservar comida dentro del turno existente', (
    tester,
  ) async {
    PersonalAgendaEntry? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showPersonalAgendaEntryDialog(
                  context,
                  others: [work],
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Desayuno');
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(result?.isMeal, isTrue);
    expect(result?.start, 480);
    expect(tester.takeException(), isNull);
  });
}
