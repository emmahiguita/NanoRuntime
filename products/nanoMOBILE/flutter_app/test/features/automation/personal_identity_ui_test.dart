import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/presentation/personal/nano_personal_identity_tab.dart';
import 'package:nanoai/features/automation/presentation/personal/nano_personal_agenda_card.dart';
import 'package:nanoai/features/automation/presentation/personal/nano_personal_contact_dialog.dart';
import 'package:nanoai/features/automation/personal_agent/application/persona_context.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.nanoai/automation_store');
  var facts = <String, String>{};
  setUp(() {
    facts = {'notas': 'Descripción anterior'};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'personaList':
              return [
                {
                  'personaKey': 'owner',
                  'displayName': 'Emmanuel',
                  'factsJson': jsonEncode(facts),
                },
              ];
            case 'personaUpsert':
              facts = Map<String, String>.from(
                jsonDecode((call.arguments as Map)['factsJson'] as String)
                    as Map,
              );
              return 1;
            case 'relationshipList':
            case 'exampleList':
            case 'exampleSearch':
            case 'personalMemoryList':
              return [];
            default:
              return null;
          }
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  testWidgets(
    'Identidad guarda campos separados que llegan al contexto del modelo',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: NanoPersonalIdentityTab())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Apodo'), 'Emma');
      await tester.enterText(
        find.widgetWithText(TextField, 'Empleo u ocupación'),
        'Desarrollador',
      );
      await tester.ensureVisible(
        find.widgetWithText(
          TextField,
          'Otras etiquetas para mencionarme en grupos',
        ),
      );
      await tester.enterText(
        find.widgetWithText(
          TextField,
          'Otras etiquetas para mencionarme en grupos',
        ),
        '573001234567',
      );
      await tester.ensureVisible(find.text('Guardar identidad'));
      await tester.tap(find.text('Guardar identidad'));
      await tester.pumpAndSettle();
      expect(facts['nickname'], 'Emma');
      expect(facts['occupation'], 'Desarrollador');
      expect(facts['groupMentionAliases'], '573001234567');
      expect(facts['notas'], 'Descripción anterior');
      final context = PersonaContext();
      await context.load();
      expect(
        context.allowsGroupReply(isGroup: true, text: '@573001234567 hola'),
        isTrue,
      );
      expect(
        context.allowsGroupReply(isGroup: true, text: '@Emma hola'),
        isTrue,
      );
      expect(
        context.allowsGroupReply(isGroup: true, text: 'Hola a todos'),
        isFalse,
      );
      expect(context.allowsGroupReply(isGroup: false, text: 'Hola'), isTrue);
      final prompt = await context.personaBlockFor(
        'Hola',
        'Juan',
        conversationId: 'juan',
      );
      expect(prompt, contains('Emma'));
      expect(prompt, contains('Desarrollador'));
      expect(find.textContaining('Groq API Keys'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Agregar contactos permite varios grupos y selección individual',
    (tester) async {
      PersonalContactEdit? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('Abrir'),
                onPressed: () async {
                  result = await showPersonalContactEditor(
                    context,
                    conversations: {'a': 'Juan', 'b': 'Ana'},
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amigos cercanos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clientes'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Juan'));
      await tester.tap(find.text('Juan'));
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(result?.groups, containsAll(['Amigos cercanos', 'Clientes']));
      expect(result?.conversations, ['a']);
      expect(result?.autoReply, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Cancelar un cambio de fecha conserva el día y las notas sin guardar',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: NanoPersonalAgendaCard()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = tester.widget<CalendarDatePicker>(
        find.byType(CalendarDatePicker),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Notas para esta fecha'),
        'Mi nota pendiente',
      );
      before.onDateChanged(before.initialDate!.add(const Duration(days: 1)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      final after = tester.widget<CalendarDatePicker>(
        find.byType(CalendarDatePicker),
      );
      expect(after.initialDate, before.initialDate);
      expect(after.key, isNot(before.key));
      expect(find.text('Mi nota pendiente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
