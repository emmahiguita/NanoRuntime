import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/theme/app_theme.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_autonomy_mode.dart';
import 'package:nanoai/features/automation/presentation/screens/personal_agent_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storeChannel = MethodChannel('com.nanoai/automation_store');
  final storeCalls = <MethodCall>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storeCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storeChannel, (MethodCall call) async {
      storeCalls.add(call);
      if (call.method == 'personaList') {
        return [
          {
            'personaKey': 'owner',
            'displayName': 'Emmanuel',
            'factsJson': jsonEncode({'notas': 'Prefiero respuestas directas.'}),
          },
        ];
      }
      if (call.method == 'personaUpsert') {
        return 1;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storeChannel, null);
  });

  Future<ProviderContainer> pumpPersonalAgent(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    String? initialWaAutonomyMode,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    final container = ProviderContainer();
    if (initialWaAutonomyMode != null) {
      container
          .read(settingsProvider.notifier)
          .setWaAutonomyMode(initialWaAutonomyMode);
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const PersonalAgentScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('renders PersonalAgentScreen with all sections and controls', (
    tester,
  ) async {
    await pumpPersonalAgent(tester);

    expect(find.text('Agente Personal WPP'), findsOneWidget);
    expect(
      find.text('Respuestas privadas, identidad y estilo de comunicación'),
      findsOneWidget,
    );
    expect(find.text('MODO DE ATENCIÓN PERSONAL'), findsOneWidget);
    expect(find.text('MI IDENTIDAD Y PREFERENCIAS'), findsOneWidget);
    expect(find.text('TRATO Y ESTILO DE EXPRESIÓN'), findsOneWidget);
    expect(find.text('HORARIOS PERSONALES'), findsOneWidget);
    expect(find.text('DIÁLOGOS, MEMORIAS Y APRENDIZAJE'), findsOneWidget);

    expect(find.text('Supervisado'), findsOneWidget);
    expect(find.text('Auto seguro'), findsOneWidget);
    expect(find.text('Autónomo'), findsOneWidget);

    // Campos de identidad precargados por el repositorio real
    expect(find.text('Tu nombre'), findsOneWidget);
    expect(find.text('Emmanuel'), findsOneWidget);
    expect(find.text('Preferencias clave sobre ti'), findsOneWidget);
    expect(find.text('Prefiero respuestas directas.'), findsOneWidget);
    expect(find.text('Guardar identidad'), findsOneWidget);

    expect(find.text('Estilo automático de respuestas'), findsOneWidget);
    expect(find.text('Mis frases y diálogos personalizados'), findsOneWidget);
    expect(find.text('Memorias y datos sobre mí'), findsOneWidget);
    expect(find.text('Importar chat de WhatsApp'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('switching autonomy modes updates waAutonomyMode and styles with high contrast', (
    tester,
  ) async {
    final container = await pumpPersonalAgent(
      tester,
      initialWaAutonomyMode: 'suggestions',
    );

    // Estado inicial en Supervisado
    expect(find.text('BORRADOR'), findsOneWidget);
    expect(container.read(settingsProvider).waAutonomyMode, 'suggestions');

    // Cambiar a Autónomo
    await tester.tap(find.text('Autónomo'));
    await tester.pumpAndSettle();

    expect(find.text('AUTÓNOMO'), findsOneWidget);
    expect(container.read(settingsProvider).waAutonomyMode, 'autonomous');

    // Cambiar a Auto seguro
    await tester.tap(find.text('Auto seguro'));
    await tester.pumpAndSettle();

    expect(find.text('AUTO SEGURO'), findsOneWidget);
    expect(container.read(settingsProvider).waAutonomyMode, 'safeAuto');

    // Cambiar de vuelta a Supervisado
    await tester.tap(find.text('Supervisado'));
    await tester.pumpAndSettle();

    expect(find.text('BORRADOR'), findsOneWidget);
    expect(container.read(settingsProvider).waAutonomyMode, 'suggestions');

    // Verificar estilo del SegmentedButton: estilo explícito y no nulo
    final segmentedBtn = tester.widget<SegmentedButton<ConversationAutonomyMode>>(
      find.byType(typeOf<SegmentedButton<ConversationAutonomyMode>>()),
    );
    expect(segmentedBtn.style, isNotNull);

    // Resolver color de texto para el estado seleccionado (debe ser blanco de alto contraste, no oscuro)
    final fgColor = segmentedBtn.style!.foregroundColor?.resolve({WidgetState.selected});
    expect(fgColor, equals(Colors.white));

    final iconColor = segmentedBtn.style!.iconColor?.resolve({WidgetState.selected});
    expect(iconColor, equals(Colors.white));

    expect(tester.takeException(), isNull);
  });

  testWidgets('saving personal identity invokes upsert on repository', (
    tester,
  ) async {
    await pumpPersonalAgent(tester);

    final nameField = find.widgetWithText(TextField, 'Tu nombre');
    await tester.enterText(nameField, 'Emmanuel Higuita');

    final saveButton = find.text('Guardar identidad');
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    final upsertCall = storeCalls.where((c) => c.method == 'personaUpsert').firstOrNull;
    expect(upsertCall, isNotNull);
    expect(upsertCall!.arguments['personaKey'], 'owner');
    expect(upsertCall.arguments['displayName'], 'Emmanuel Higuita');
  });

  testWidgets('renders cleanly on compact screen (320px width) without overflows', (
    tester,
  ) async {
    await pumpPersonalAgent(tester, size: const Size(320, 600));

    expect(find.text('Agente Personal WPP'), findsOneWidget);
    expect(find.text('MODO DE ATENCIÓN PERSONAL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Type typeOf<T>() => T;
