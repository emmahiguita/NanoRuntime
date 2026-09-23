import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/theme/nano_transitions.dart';
import 'package:nanoai/core/widgets/navigation/nano_navigation_panel.dart';

import '../automation_visual_theme.dart';
import '../business/nano_business_screen.dart';
import '../system/nano_system_screen.dart';
import '../widgets/automation_dashboard.dart';
import 'automation_dev_screen.dart';
import 'automation_rules_screen.dart';
import 'mcp_skills_hub_screen.dart';
import '../personal/nano_personal_screen.dart';
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
          return Scaffold(
            resizeToAvoidBottomInset: false,
            body: NanoShellBarScope(
              child: AutomationDashboard(
                onSettingsTap: () => _openSettings(context),
                onMessagesTap: () => context.push('/automation/messages'),
                onRulesTap: () => _openRules(context),
                onBusinessTap: () => _openBusiness(context),
                onPersonalAgentTap: () => _openPersonalAgent(context),
                onBotStudioTap: () => _openBotStudio(context),
                onSkillsMcpTap: () => _openSkillsMcp(context),
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
        builder: (_) => const NanoSystemScreen(),
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
      nanoGlassPageRoute<void>(builder: (_) => const NanoBusinessScreen()),
    );
  }

  static void _openPersonalAgent(BuildContext context) {
    Navigator.of(context).push(
      nanoGlassPageRoute<void>(builder: (_) => const NanoPersonalScreen()),
    );
  }

  static void _openBotStudio(BuildContext context) {
    Navigator.of(context).push(
      nanoGlassPageRoute<void>(builder: (_) => const BotStudioScreen()),
    );
  }
}
