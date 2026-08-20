import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/theme/app_theme.dart';
import 'package:nanoai/features/desktop/presentation/screens/desktop_launch_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpAt(WidgetTester tester, Widget screen, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.dark, home: screen),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('pantalla de conexión no solapa componentes a 320x568', (
    tester,
  ) async {
    await pumpAt(tester, const DesktopLaunchScreen(), const Size(320, 568));

    expect(tester.takeException(), isNull);
    expect(find.text('Escritorio Linux'), findsOneWidget);
  });

  testWidgets('pantalla de conexión no solapa la barra a 640x360', (
    tester,
  ) async {
    await pumpAt(tester, const DesktopLaunchScreen(), const Size(640, 360));

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.text('Escritorio Linux'), findsOneWidget);
  });
}
