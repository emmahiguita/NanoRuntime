import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/core/router/scaffold_shell.dart';
import 'package:nanoai/core/theme/app_theme.dart';

void main() {
  testWidgets('dock vertical no desborda en una pantalla horizontal baja', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(480, 240);
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/one',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, __, shell) => ScaffoldShell(shell: shell),
          branches: [
            for (final route in const [
              '/one',
              '/two',
              '/three',
              '/four',
              '/five',
            ])
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: route,
                    builder: (_, __) => const ColoredBox(
                      color: Colors.transparent,
                      child: SizedBox.expand(),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.byType(ScaffoldShell), findsOneWidget);
  });
}
