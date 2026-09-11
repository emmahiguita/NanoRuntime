import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/theme/app_theme.dart';
import 'package:nanoai/features/automation/presentation/screens/personal_agent_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpPersonalAgent(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const PersonalAgentScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders PersonalAgentScreen with all sections and controls', (
    tester,
  ) async {
    await pumpPersonalAgent(tester);

    expect(find.text('Agente Personal WPP'), findsOneWidget);
    expect(find.text('Respuestas privadas, identidad y estilo de comunicación'), findsOneWidget);
    expect(find.text('MODO DE ATENCIÓN PERSONAL'), findsOneWidget);
    expect(find.text('MI IDENTIDAD Y PREFERENCIAS'), findsOneWidget);
    expect(find.text('TRATO Y ESTILO DE EXPRESIÓN'), findsOneWidget);
    expect(find.text('HORARIOS PERSONALES'), findsOneWidget);
    expect(find.text('APRENDIZAJE Y MEMORIA'), findsOneWidget);

    expect(find.text('Supervisado'), findsOneWidget);
    expect(find.text('Autónomo'), findsOneWidget);
    expect(find.text('Tu nombre'), findsOneWidget);
    expect(find.text('Preferencias clave sobre ti'), findsOneWidget);
    expect(find.text('Guardar identidad'), findsOneWidget);
    expect(find.text('Estilo automático de respuestas'), findsOneWidget);
    expect(find.text('Aprender de mis conversaciones'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('renders cleanly on compact screen (320px width)', (
    tester,
  ) async {
    await pumpPersonalAgent(tester, size: const Size(320, 600));

    expect(find.text('Agente Personal WPP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
