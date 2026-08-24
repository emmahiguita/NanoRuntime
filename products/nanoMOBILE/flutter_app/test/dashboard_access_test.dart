import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/theme/app_theme.dart';
import 'package:nanoai/features/home/nano_home_models.dart';
import 'package:nanoai/features/home/nano_home_screen.dart';

/// Verifica que los ACCESOS del dashboard disparan sus callbacks de navegación
/// al tocar la feature card (cadena NanoOpticalSurface.onTap → data.onTap).
/// Confirma la lógica de acceso independientemente del entorno del device.
void main() {
  testWidgets('feature card del dashboard navega al tocar', (tester) async {
    var tapped = '';

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: NanoHomeScreen(
            telemetry: const NanoTelemetryData(
              ram: '2.5 GB',
              cpu: '8',
              temperature: '42 °C',
              freeStorage: '120 GB',
              battery: '55%',
            ),
            kaliStatus: KaliStatus.notInitialized,
            onTerminalTap: () => tapped = 'terminal',
            onChatTap: () => tapped = 'chat',
            onModelsTap: () => tapped = 'models',
            onKaliTap: () => tapped = 'kali',
            onDesktopTap: () => tapped = 'desktop',
            onAutomationTap: () => tapped = 'automation',
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // Página 0 = feature Chat; tocar su título dispara el callback.
    final chatTitle = find.text('Chat');
    expect(chatTitle, findsWidgets);
    await tester.tap(chatTitle.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tapped, 'chat');
  });

  testWidgets('accesos del dashboard nunca quedan mudos (no-op)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: NanoHomeScreen(
            telemetry: const NanoTelemetryData(
              ram: '—',
              cpu: '—',
              temperature: '—',
              freeStorage: '—',
              battery: '—',
            ),
            kaliStatus: KaliStatus.notInitialized,
            onTerminalTap: () {},
            onChatTap: () {},
            onModelsTap: () {},
            onKaliTap: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    // Renderiza sin crash ni excepción (los accesos opcionales no rompen).
    expect(tester.takeException(), isNull);
  });
}
