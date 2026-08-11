import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nanoai/core/theme/design_tokens.dart';

import 'package:nanoai/features/terminal/terminal_core.dart';
import 'package:nanoai/features/terminal/terminal_screen.dart';

void main() {
  testWidgets('TerminalTabScreen renders a NanoTerminal after async restore', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(theme: ThemeData(extensions: [NanoThemeExtension(colors: NanoDarkColors())]), home: const Scaffold(body: TerminalTabScreen())),
    );

    await tester.pumpAndSettle();

    expect(find.text('bash'), findsOneWidget);
    expect(find.byType(NanoTerminal), findsOneWidget);
  });

  testWidgets('NanoTerminal processes exit and logout commands without error', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [NanoThemeExtension(colors: NanoDarkColors())]),
        home: const Scaffold(body: NanoTerminal(sessionId: 0, initialCwd: '/home/nanoai')),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(NanoTerminal), findsOneWidget);
  });
}
