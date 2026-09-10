import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/theme/app_theme.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/features/terminal/domain/terminal_hub_card.dart';
import 'package:nanoai/features/terminal/presentation/widgets/interactive_3d_turntable_box.dart';
import 'package:nanoai/features/terminal/presentation/widgets/terminal_coverflow_card.dart';

void main() {
  final testCard = TerminalHubCard(
    id: 'terminal',
    title: 'Terminal',
    eyebrow: 'CONSOLA PTY',
    description: 'Sesiones interactivas persistentes para Bash, Python, etc.',
    icon: Icons.terminal_rounded,
    accent: const Color(0xFF00FF9D),
    route: '/terminal/shell',
    highlights: const ['Soporte VT100', 'PTY desacoplado'],
    actionLabel: 'Abrir Consola PTY',
  );

  testWidgets('TerminalCover adopta colores claros en Light Mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: TerminalCover(card: testCard),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    final context = tester.element(find.byType(TerminalCover));
    final colors = NanoThemeExtension.of(context).colors;
    expect(colors, isA<NanoLightColors>());

    // Textos deben usar los colores semánticos
    final titleText = tester.widget<Text>(find.text('TERMINAL'));
    expect(titleText.style?.color, colors.textPrimary);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TerminalCover adopta colores oscuros en Dark Mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: TerminalCover(card: testCard),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    final context = tester.element(find.byType(TerminalCover));
    final colors = NanoThemeExtension.of(context).colors;
    expect(colors, isA<NanoDarkColors>());

    final titleText = tester.widget<Text>(find.text('TERMINAL'));
    expect(titleText.style?.color, colors.textPrimary);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Interactive3DTurntableBox y controles rotan y cambian en Light Mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: Interactive3DTurntableBox(
              card: testCard,
              width: 200,
              height: 275,
              depth: 26,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('FRENTE'), findsOneWidget);
    expect(find.text('DORSO'), findsOneWidget);
    expect(find.text('• Desliza 360° •'), findsOneWidget);

    // Tocar DORSO para voltear a la cara trasera
    await tester.tap(find.text('DORSO'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('MANUAL TÉCNICO'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TerminalHubDetailCard hereda jerárquicamente el tema claro', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: TerminalHubDetailCard(card: testCard),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final context = tester.element(find.byType(TerminalHubDetailCard));
    final colors = NanoThemeExtension.of(context).colors;
    expect(colors, isA<NanoLightColors>());

    expect(find.text('CAPACIDADES INTEGRADAS'), findsOneWidget);
    expect(find.text('Standard Nano AI Case'), findsOneWidget);
    expect(find.text('Abrir Consola PTY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
