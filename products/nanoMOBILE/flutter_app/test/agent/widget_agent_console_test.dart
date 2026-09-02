import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/theme/app_theme.dart';
import 'package:nanoai/features/automation/presentation/agent_console_section.dart';

import 'fixtures.dart';

/// Test de integración de la consola: canal `com.nanoai/agent` mockeado,
/// verificación de feedback real (ok / errorCode en español) en la UI.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.nanoai/agent');

  var dumpProvider = snapshotAjustes;

  /// Simula el foco real: tras un tapAt, el EditText queda enfocado.
  var focusedAfterTap = false;

  Map<String, dynamic> dump() {
    final raw = dumpProvider();
    if (focusedAfterTap) {
      ((raw['nodes'] as List)[5] as Map)['focused'] = true;
    }
    return raw;
  }

  Future<void> pumpConsole(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SingleChildScrollView(child: AgentConsoleSection()),
          ),
        ),
      ),
    );
  }

  setUp(() {
    dumpProvider = snapshotAjustes;
    focusedAfterTap = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'dumpSnapshot':
              return dump();
            case 'tapAt':
              focusedAfterTap = true;
              return true;
            case 'inputText':
              return true;
            case 'globalAction':
            case 'launchPackage':
            case 'swipe':
              return true;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('probe muestra package y nodos con depth', (tester) async {
    await pumpConsole(tester);
    expect(find.text('Sin consultar'), findsOneWidget);

    await tester.tap(find.text('Leer pantalla actual'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.textContaining('Conectado — com.android.settings · 7 nodos'),
      findsOneWidget,
    );
    // Preview con depth del primer visible.
    expect(find.textContaining('d3 Ajustes @(40,140)'), findsOneWidget);
  });

  testWidgets('resolver muestra top-5 y motivo', (tester) async {
    await pumpConsole(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Selector (mini-DSL)'),
      'text=Bluetooth',
    );
    await tester.tap(find.text('Resolver'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.textContaining('Resuelto: "Bluetooth" (75 pts)'),
      findsOneWidget,
    );
    expect(find.textContaining('75 pts [textExact:+75]'), findsOneWidget);
  });

  testWidgets('tap seguro → feedback ok con coordenadas', (tester) async {
    await pumpConsole(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Selector (mini-DSL)'),
      'text=Bluetooth',
    );
    await tester.tap(find.text('Tap seguro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.textContaining('ok: tap en "Bluetooth" @(540,340)'),
      findsOneWidget,
    );
  });

  testWidgets('tap ambiguo → FAIL [ambiguousTarget]', (tester) async {
    dumpProvider = snapshotDobleAceptar;
    await pumpConsole(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Selector (mini-DSL)'),
      'text=Aceptar',
    );
    await tester.tap(find.text('Tap seguro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('FAIL [ambiguousTarget]'), findsOneWidget);
  });

  testWidgets('setText escribe en el campo con foco', (tester) async {
    await pumpConsole(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Selector (mini-DSL)'),
      'editable=true',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Texto a escribir'),
      'wifi',
    );
    await tester.tap(find.text('Escribir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('ok: "wifi" en'), findsOneWidget);
  });

  testWidgets('selector inválido → feedback de error', (tester) async {
    await pumpConsole(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Selector (mini-DSL)'),
      'foo=bar',
    );
    await tester.tap(find.text('Resolver'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Selector inválido'), findsOneWidget);
  });
}
