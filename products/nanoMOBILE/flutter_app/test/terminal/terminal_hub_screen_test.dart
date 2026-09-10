import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/router/app_router.dart';
import 'package:nanoai/core/theme/app_theme.dart';
import 'package:nanoai/features/terminal/presentation/screens/terminal_hub_screen.dart';

void main() {
  Future<void> pumpHub(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          home: const TerminalHubScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('muestra los tres accesos del módulo', (tester) async {
    await pumpHub(tester, const Size(390, 844));

    expect(find.text('Terminal'), findsWidgets);
    expect(find.text('Nano Linux'), findsOneWidget);
    expect(find.text('Visor Linux'), findsOneWidget);
    expect(find.byIcon(Icons.terminal_rounded), findsOneWidget);
    expect(find.byIcon(Icons.hub_rounded), findsOneWidget);
    expect(find.byIcon(Icons.desktop_windows_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no desborda en horizontal compacto', (tester) async {
    await pumpHub(tester, const Size(640, 360));

    expect(find.text('Nano Linux'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Visor Linux'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Visor Linux'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('/terminal abre el centro dentro del shell principal', (
    tester,
  ) async {
    AppRouter.init('/terminal');
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          routerConfig: AppRouter.router,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Sistemas locales'), findsOneWidget);
    expect(find.text('Nano Linux'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('al tocar una tarjeta se abre la ficha expandida con Hero', (
    tester,
  ) async {
    await pumpHub(tester, const Size(390, 844));

    // Tap en Nano Linux (tarjeta central)
    await tester.tap(find.text('Nano Linux'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    // Debe mostrar la vista de detalle con sus capacidades y botón de acción
    expect(find.text('CAPACIDADES INTEGRADAS'), findsOneWidget);
    expect(find.text('Administrar Entornos'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // Cerrar detalle
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Debe volver al carrusel
    expect(find.text('Sistemas locales'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
