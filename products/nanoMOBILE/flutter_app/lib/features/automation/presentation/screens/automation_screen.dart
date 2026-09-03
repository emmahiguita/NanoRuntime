import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/theme/nano_transitions.dart';

import '../automation_visual_theme.dart';
import '../widgets/automation_bottom_navigation.dart';
import '../widgets/automation_dashboard.dart';
import 'automation_dev_screen.dart';
import 'automation_settings_screen.dart';

/// El centro de control operativo de NanoAutomation.
///
/// NO es una consola de debugging: es el dashboard del asistente. Muestra
/// estado + composer + quick actions + capacidades + ejecuciones recientes.
/// Las herramientas técnicas viven en la pantalla Dev (icono en el header).
/// Solo un botón atrás (NanoScreenShell, auto) — sin panel de navegación.
class AutomationScreen extends ConsumerWidget {
  const AutomationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visualMode = AutomationVisual.modeFromSetting(
      ref.watch(settingsProvider.select((settings) => settings.themeMode)),
    );
    return AnimatedTheme(
      data: AutomationVisual.theme(context, mode: visualMode),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: Builder(
        builder: (context) {
          final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
          return Scaffold(
            resizeToAvoidBottomInset: true,
            // UI-REV-03: fondo compartido de Dev en el dashboard también.
            backgroundColor: Colors.transparent,
            body: Stack(
              fit: StackFit.expand,
              children: [
                const AutomationBackdrop(),
                SafeArea(
                  child: AutomationNavigationFrame(
                    hidden: keyboardOpen,
                    child: AutomationDashboard(
                      onSettingsTap: () => _openSettings(context),
                      onMessagesTap: () => context.push('/automation/messages'),
                      // Acceso directo a las herramientas del agente desde la
                      // pantalla principal (misma puerta de debug que Ajustes).
                      onDevTap: kDebugMode ? () => _openDev(context) : null,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      nanoGlassPageRoute<void>(
        builder: (_) => AutomationSettingsScreen(
          onDevTap: kDebugMode ? () => _openDev(context) : null,
        ),
      ),
    );
  }

  static void _openDev(BuildContext context) {
    Navigator.of(context).push(
      nanoGlassPageRoute<void>(builder: (_) => const AutomationDevScreen()),
    );
  }
}
