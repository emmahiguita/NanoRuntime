import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/providers/app_providers.dart';
import 'package:nanoai/core/theme/app_theme.dart';
import 'package:nanoai/features/settings/presentation/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpSettings(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: _SettingsTestApp()));
    await tester.pumpAndSettle();
  }

  testWidgets('renders without overflow on a compact portrait screen', (
    tester,
  ) async {
    await pumpSettings(tester, const Size(320, 568));

    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('APARIENCIA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adapts to landscape and applies dark theme without errors', (
    tester,
  ) async {
    await pumpSettings(tester, const Size(640, 360));

    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(SettingsScreen));
    expect(Theme.of(context).brightness, Brightness.dark);
    // El selector de nivel de automatización ("Manual") vive ahora en
    // /automation, no en Ajustes.
    expect(find.text('Autónomo'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _SettingsTestApp extends ConsumerWidget {
  const _SettingsTestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      home: const Scaffold(body: SettingsScreen()),
    );
  }
}
