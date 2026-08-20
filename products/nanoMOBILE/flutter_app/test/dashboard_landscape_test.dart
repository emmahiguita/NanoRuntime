import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/core/providers/dashboard_provider.dart';
import 'package:nanoai/core/providers/rootfs_provider.dart';
import 'package:nanoai/core/providers/kali_provider.dart';
import 'package:nanoai/core/services/rootfs_manager.dart';
import 'package:nanoai/core/theme/app_theme.dart';
import 'package:nanoai/features/dashboard/presentation/screens/dashboard_screen.dart';

/// Landscape del launcher: el diseño horizontal debe llenar la pantalla
/// en dos columnas sin scroll y sin overflows por píxeles a ningún tamaño.

void main() {
  for (final (label, size, dpr) in [
    ('landscape phone 800x360', const Size(2400, 1080), 3.0),
    ('landscape phone 640x360', const Size(1920, 1080), 3.0),
    ('landscape small 480x320', const Size(1440, 960), 3.0),
    ('landscape tablet 1280x800', const Size(1280, 800), 1.0),
  ]) {
    testWidgets('no overflow: $label', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = dpr;
      addTearDown(() {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
      });
      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardProvider.overrideWith(
              (ref) => DashboardNotifier.fixed(ref, const DashboardState(
                ramFreeGb: 3.9, ramTotalGb: 8.0, cpuCores: 8,
                tempC: 35, storageTotalGb: 256, storageFreeGb: 209,
                batteryPct: 100, isLive: true,
              )),
            ),
            rootfsProvider.overrideWithValue(RootfsManager()),
            kaliProvider.overrideWithValue(null),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            // La pantalla lee la extensión NanoThemeExtension del tema
            // (colores reales); sin theme el null check crashea.
            theme: AppTheme.light,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(tester.takeException(), isNull,
          reason: 'landscape sin overflow ni excepción');
      // La home es un carousel: solo la tarjeta central (Terminal) y sus
      // adyacentes se construyen; el resto se alcanza deslizando. Lo que
      // debe estar presente en todo layout: identidad, estado Kali y la
      // tarjeta central.
      expect(find.text('Terminal'), findsOneWidget);
      expect(find.text('Kali'), findsOneWidget);
      expect(find.text('nanoai'), findsOneWidget);
    });
  }
}
