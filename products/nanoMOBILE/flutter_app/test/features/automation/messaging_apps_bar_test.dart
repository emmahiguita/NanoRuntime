import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/domain/messaging_platform.dart';
import 'package:nanoai/features/automation/presentation/messaging_center/messaging_apps_bar.dart';
import 'package:nanoai/features/automation/presentation/messaging_center/messaging_center_providers.dart';

void main() {
  testWidgets(
    'Personal y Negocio siguen legibles en ancho pequeño y texto grande',
    (tester) async {
      tester.view.physicalSize = const Size(280, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(
        overrides: [platformUnreadCountsProvider.overrideWithValue(const {})],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
                child: const MessagingAppsBar(),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Personal'), findsOneWidget);
      expect(find.text('Negocio'), findsOneWidget);
      await tester.tap(find.text('Negocio'));
      await tester.pumpAndSettle();
      expect(
        container.read(selectedPlatformFilterProvider),
        MessagingPlatform.whatsappBusiness,
      );
      await tester.tap(find.text('Personal'));
      await tester.pumpAndSettle();
      expect(
        container.read(selectedPlatformFilterProvider),
        MessagingPlatform.whatsapp,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
