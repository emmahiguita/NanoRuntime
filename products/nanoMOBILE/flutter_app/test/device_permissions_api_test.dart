import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/core/theme/app_theme.dart';
import 'package:nanoai/features/settings/presentation/widgets/device_permissions_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.nanoai/device_permissions');
  final calls = <String>[];
  final api = NanoRuntimeApi();

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'status') {
            return {
              'microphone': true,
              'media': false,
              'accessibility': true,
              'notificationAccess': false,
              'allFiles': true,
            };
          }
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('devuelve el estado real reportado por Android', () async {
    final status = await api.devicePermissionStatus();
    expect(status['microphone'], isTrue);
    expect(status['media'], isFalse);
    expect(status['accessibility'], isTrue);
    expect(status['notificationAccess'], isFalse);
    expect(status['allFiles'], isTrue);
  });

  test('cada acción usa el panel Android correspondiente', () async {
    expect(await api.requestRuntimePermissions(), isTrue);
    expect(await api.openAccessibilitySettings(), isTrue);
    expect(await api.openNotificationAccessSettings(), isTrue);
    expect(await api.openAllFilesAccessSettings(), isTrue);
    expect(await api.openAppPermissionSettings(), isTrue);
    expect(calls, [
      'requestRuntime',
      'openAccessibility',
      'openNotificationAccess',
      'openAllFilesAccess',
      'openAppDetails',
    ]);
  });

  testWidgets('muestra estado real y solicita permisos pendientes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: DevicePermissionsSection()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3/5 accesos habilitados'), findsOneWidget);
    expect(find.text('Micrófono para dictado'), findsOneWidget);
    expect(find.text('Conceder pendientes'), findsOneWidget);

    await tester.tap(find.text('Conceder pendientes'));
    await tester.pumpAndSettle();
    expect(calls, contains('requestRuntime'));
    expect(calls, contains('openNotificationAccess'));
  });
}
