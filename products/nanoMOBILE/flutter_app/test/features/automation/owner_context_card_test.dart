import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/presentation/personal/nano_personal_owner_context_card.dart';
import 'package:nanoai/features/automation/personal_agent/domain/personal_daily_agenda.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.nanoai/automation_store');
  var facts = <String, String>{};
  setUp(() {
    facts = {
      'dailyStatus': 'Ayer ocupado',
      'dailyStatusDate': '2020-01-01',
      'nickname': 'Emma',
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'personaList') {
            return [
              {
                'personaKey': 'owner',
                'displayName': 'Emmanuel',
                'factsJson': jsonEncode(facts),
              },
            ];
          }
          if (call.method == 'personaUpsert') {
            facts = Map<String, String>.from(
              jsonDecode((call.arguments as Map)['factsJson'] as String),
            );
            return 1;
          }
          return [];
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  testWidgets(
    'Preferencias se guardan sin revivir estado anterior; editar estado sí lo fecha hoy',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: NanoPersonalOwnerContextCard(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Preferencias para responder'),
        'Prefiero coordinar primero',
      );
      await tester.ensureVisible(find.text('Guardar preferencias y estado'));
      await tester.tap(find.text('Guardar preferencias y estado'));
      await tester.pumpAndSettle();
      expect(facts['dailyStatusDate'], '2020-01-01');
      expect(facts['preferences'], 'Prefiero coordinar primero');
      expect(facts['nickname'], 'Emma');
      await tester.ensureVisible(
        find.widgetWithText(TextField, 'Estado que declaro para hoy'),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Estado que declaro para hoy'),
        'Hoy no puedo salir',
      );
      await tester.ensureVisible(find.text('Guardar preferencias y estado'));
      await tester.tap(find.text('Guardar preferencias y estado'));
      await tester.pumpAndSettle();
      expect(
        facts['dailyStatusDate'],
        PersonalDailyAgenda.dateKey(DateTime.now()),
      );
      expect(facts['dailyStatus'], 'Hoy no puedo salir');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Formulario usable en horizontal y teléfono estrecho con texto grande',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      for (final size in [const Size(320, 640), const Size(740, 360)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    textScaler: const TextScaler.linear(1.3),
                  ),
                  child: const SingleChildScrollView(
                    child: NanoPersonalOwnerContextCard(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Guardar preferencias y estado'));
        expect(tester.takeException(), isNull);
      }
    },
  );
}
