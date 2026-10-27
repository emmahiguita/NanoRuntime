import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/personal_agent/domain/personal_agenda_day.dart';
import 'package:nanoai/features/automation/presentation/personal/nano_personal_agenda_dialog.dart';
import 'package:nanoai/features/automation/presentation/personal/nano_personal_agenda_view.dart';

void main() {
  testWidgets('Edita una actividad y abre el reloj sin perder los datos', (
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
                  existing: const PersonalAgendaEntry('Trabajo', 480, 720),
                );
              },
              child: const Text('Editar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desde 08:00'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Trabajo desde casa');
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(result?.title, 'Trabajo desde casa');
    expect(result?.start, 480);
    expect(result?.end, 720);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Rechaza cruces dentro del editor sin borrar la actividad escrita',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showPersonalAgendaEntryDialog(
                  context,
                  others: [const PersonalAgendaEntry('Trabajo', 480, 720)],
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Reunión');
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(
        find.text('Ese horario se cruza con otra actividad.'),
        findsOneWidget,
      );
      expect(find.text('Reunión'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Agenda cabe en teléfono estrecho y horizontal con texto ampliado',
    (tester) async {
      final notes = TextEditingController();
      addTearDown(notes.dispose);
      for (final size in [const Size(320, 640), const Size(740, 360)]) {
        tester.view.resetPhysicalSize();
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: const TextScaler.linear(1.3),
                ),
                child: SingleChildScrollView(
                  child: NanoPersonalAgendaView(
                    date: DateTime(2026, 10, 17),
                    entries: const [
                      PersonalAgendaEntry('Almuerzo con la familia', 720, 780),
                    ],
                    notes: notes,
                    enabled: true,
                    saving: false,
                    dirty: false,
                    status: null,
                    onDate: () {},
                    onDateSelected: (_) {},
                    repeatWeekly: true,
                    onRepeatWeekly: (_) {},
                    onAdd: () {},
                    onEdit: (_) {},
                    onDelete: (_) {},
                    onEnabled: (_) {},
                    onNotes: (_) {},
                    onSave: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}
