import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/theme/nano_transitions.dart';
import 'package:nanoai/core/widgets/navigation/nano_navigation_panel.dart';

import '../automation_visual_theme.dart';
import '../widgets/automation_dashboard.dart';
import 'automation_dev_screen.dart';
import 'automation_rules_screen.dart';
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
          // NAV-BAR-FIX-03 — barra global (escritura + navegación) también
          // en las visuales fuera del shell: la cáscara
          // La barra universal (NanoShellBarScope) es la única navegación
          // aquí; el dock inferior antiguo salió por completo.
          return Scaffold(
            resizeToAvoidBottomInset: true,
            backgroundColor: Colors.transparent,
            body: NanoShellBarScope(
              child: SafeArea(
                child: AutomationDashboard(
                  onSettingsTap: () => _openSettings(context),
                  onMessagesTap: () => context.push('/automation/messages'),
                  // RULES-CREATE-02: Reglas alcanzable desde el dashboard,
                  // ya no escondida dentro de Configuración.
                  onRulesTap: () => _openRules(context),
                  // WA-DEV-ACCESS-01 — acceso directo a las herramientas
                  // del agente SIEMPRE visible (antes solo kDebugMode:
                  // en release el icono robot desaparecía).
                  onDevTap: () => _openDev(context),
                ),
              ),
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
          // WA-DEV-ACCESS-01 — misma puerta, sin gate de debug.
          onDevTap: () => _openDev(context),
        ),
      ),
    );
  }

  static void _openDev(BuildContext context) {
    Navigator.of(context).push(
      nanoGlassPageRoute<void>(builder: (_) => const AutomationDevScreen()),
    );
  }

  static void _openRules(BuildContext context) {
    Navigator.of(context).push(
      nanoGlassPageRoute<void>(builder: (_) => const AutomationRulesScreen()),
    );
  }
}
