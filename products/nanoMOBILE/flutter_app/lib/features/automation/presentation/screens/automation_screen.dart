import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_transitions.dart';
import 'package:nanoai/core/theme/nano_hero_source.dart';
import 'package:nanoai/core/theme/nano_hero_zoom_route.dart';
import 'package:nanoai/core/widgets/navigation/nano_navigation_panel.dart';

import '../automation_visual_theme.dart';
import '../business/nano_business_screen.dart';
import '../system/nano_system_screen.dart';
import '../widgets/automation_dashboard.dart';
import 'automation_dev_screen.dart';
import 'automation_rules_screen.dart';
import '../personal/nano_personal_screen.dart';

/// El centro de control operativo de NanoAutomation.
///
/// Presenta el dashboard del asistente con diseño Adaptive Glass y Intelligent Motion.
/// Soporta tema claro (blanco hielo) y tema oscuro (grafito profundo) con materiales premium.
class AutomationScreen extends ConsumerWidget {
  final bool isEmbeddedInShell;

  const AutomationScreen({super.key, this.isEmbeddedInShell = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visualMode = AutomationVisual.modeFromSetting(
      ref.watch(settingsProvider.select((settings) => settings.themeMode)),
    );
    final colors = NanoThemeExtension.of(context).colors;
    final dashboardContent = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
      ),
      child: AutomationDashboard(
        onSettingsTap: () => _openSettings(context),
        onMessagesTap: () => context.push('/automation/messages'),
        onRulesTap: () => _openRules(context),
        onBusinessTap: _openBusiness,
        onPersonalAgentTap: _openPersonalAgent,
        onDevTap: () => _openDev(context),
      ),
    );

    return AnimatedTheme(
      data: AutomationVisual.theme(context, mode: visualMode),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: Builder(
        builder: (context) {
          if (isEmbeddedInShell) {
            return SafeArea(bottom: false, child: dashboardContent);
          }
          return Scaffold(
            backgroundColor: colors.backgroundPrimary,
            resizeToAvoidBottomInset: false,
            body: NanoShellBarScope(
              child: SafeArea(
                top: true,
                bottom: false,
                child: dashboardContent,
              ),
            ),
          );
        },
      ),
    );
  }

  static void _openSettings(BuildContext context) {
    Navigator.of(
      context,
    ).push(nanoGlassPageRoute<void>(builder: (_) => const NanoSystemScreen()));
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

  static void _openBusiness(BuildContext context) {
    Navigator.of(context).push(
      nanoHeroZoomRoute<void>(
        originContext: context,
        tag: nanoBusinessHeroTag,
        builder: (_) => const NanoBusinessScreen(),
      ),
    );
  }

  static void _openPersonalAgent(BuildContext context) {
    Navigator.of(context).push(
      nanoHeroZoomRoute<void>(
        originContext: context,
        tag: nanoPersonalHeroTag,
        builder: (_) => const NanoPersonalScreen(),
      ),
    );
  }
}
