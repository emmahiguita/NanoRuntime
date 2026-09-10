import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/core/theme/app_theme.dart';
import 'package:nanoai/features/automation/application/automation_coordinator_provider.dart';
import 'package:nanoai/features/automation/engine/scheduling/time_tick_scheduler.dart';
import 'package:nanoai/features/automation/presentation/screens/whatsapp_onboarding_screen.dart';
import 'package:nanoai/features/automation/presentation/screens/automation_rules_screen.dart';
import 'package:nanoai/features/automation/presentation/screens/automation_settings_screen.dart';
import 'package:nanoai/features/automation/presentation/widgets/automation_dashboard.dart';

Widget _testWrapper({required Widget child}) {
  return ProviderScope(
    overrides: [
      timeTickSchedulerProvider.overrideWith(
        (ref) => TimeTickScheduler(onMinute: (_) async {}),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.nanoai/automation_store'),
      (call) async {
        if (call.method == 'personaList') {
          return <Map<String, dynamic>>[];
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.nanoai/automation_store'),
      null,
    );
  });

  const landscapeSizes = [
    ('phone 800x360', Size(2400, 1080), 3.0),
    ('phone 640x360', Size(1920, 1080), 3.0),
    ('compact 480x320', Size(1440, 960), 3.0),
    ('tablet 1280x800', Size(1280, 800), 1.0),
  ];

  for (final (label, size, dpr) in landscapeSizes) {
    testWidgets('WhatsAppOnboardingScreen renders without overflow in $label', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = dpr;
      addTearDown(() {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
      });

      await tester.pumpWidget(
        _testWrapper(
          child: const WhatsAppOnboardingScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('AutomationSettingsScreen renders without overflow in $label', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = dpr;
      addTearDown(() {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
      });

      final errors = <FlutterErrorDetails>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);
      try {
        await tester.pumpWidget(
          _testWrapper(
            child: const AutomationSettingsScreen(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpWidget(const SizedBox());
        expect(errors.where((e) => e.toString().contains('overflowed')), isEmpty);
      } finally {
        FlutterError.onError = oldHandler;
      }
    });

    testWidgets('AutomationRulesScreen renders without overflow in $label', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = dpr;
      addTearDown(() {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
      });

      final errors = <FlutterErrorDetails>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        debugPrint('CAPTURED FLUTTER ERROR: ${details.exceptionAsString()}');
        debugPrint('SUMMARY: ${details.summary}');
      };
      try {
        await tester.pumpWidget(
          _testWrapper(
            child: const AutomationRulesScreen(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(errors.where((e) => e.toString().contains('overflowed')), isEmpty);
      } finally {
        FlutterError.onError = oldHandler;
      }
    });

    testWidgets('AutomationDashboard renders without overflow in $label', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = dpr;
      addTearDown(() {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
      });

      await tester.pumpWidget(
        _testWrapper(
          child: const Scaffold(
            body: AutomationDashboard(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  }
}
