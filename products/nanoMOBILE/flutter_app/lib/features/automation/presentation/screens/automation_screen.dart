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
import 'business_studio_screen.dart';
import 'mcp_skills_hub_screen.dart';
import 'personal_agent_screen.dart';
import '../bot_studio/bot_studio_screen.dart';

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
            // KEYBOARD-FIX-01: false aquí es crítico — NanoShellBarScope usa
            // un Stack + AnimatedPositioned para la barra. Si el Scaffold
            // encoge el body al aparecer el teclado, la barra salta.
            // El frame ya maneja el espacio mediante totalBottomPad.
            resizeToAvoidBottomInset: false,
            // NanoShellBarScope provee el fondo líquido unificado (AutomationBackdrop)
            // y la protección superior de barra de estado (protectTop: true).
            // Evitamos doble pintado de blur y doble desplazamiento superior.
            body: NanoShellBarScope(
              child: AutomationDashboard(
                onSettingsTap: () => _openSettings(context),
                onMessagesTap: () => context.push('/automation/messages'),
                // RULES-CREATE-02: Reglas alcanzables desde el dashboard.
                onRulesTap: () => _openRules(context),
                onBusinessTap: () => _openBusiness(context),
                onPersonalAgentTap: () => _openPersonalAgent(context),
                onBotStudioTap: () => _openBotStudio(context),
                onSkillsMcpTap: () => _openSkillsMcp(context),
                // WA-DEV-ACCESS-01 — acceso directo siempre visible.
                onDevTap: () => _openDev(context),
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

  static void _openSkillsMcp(BuildContext context) {
    Navigator.of(context).push(
      nanoGlassPageRoute<void>(builder: (_) => const McpSkillsHubScreen()),
    );
  }

  static void _openRules(BuildContext context) {
    Navigator.of(context).push(
      nanoGlassPageRoute<void>(builder: (_) => const AutomationRulesScreen()),
    );
  }

  static void _openBusiness(BuildContext context) {
    Navigator.of(context).push(
      nanoGlassPageRoute<void>(builder: (_) => const BusinessStudioScreen()),
    );
  }

  static void _openPersonalAgent(BuildContext context) {
    Navigator.of(context).push(
      nanoGlassPageRoute<void>(builder: (_) => const PersonalAgentScreen()),
    );
  }

  static void _openBotStudio(BuildContext context) {
    Navigator.of(context).push(
      nanoGlassPageRoute<void>(builder: (_) => const BotStudioScreen()),
    );
  }
}
