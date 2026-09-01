import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    return Theme(
      data: AutomationVisual.theme(),
      child: Builder(
        builder: (context) {
          final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
          return Scaffold(
            resizeToAvoidBottomInset: true,
            backgroundColor: AutomationVisual.canvas,
            bottomNavigationBar: keyboardOpen
                ? null
                : const AutomationBottomNavigation(),
            body: SafeArea(
              bottom: false,
              child: AutomationDashboard(
                onSettingsTap: () => _openSettings(context),
                onMessagesTap: () => context.push('/automation/messages'),
              ),
            ),
          );
        },
      ),
    );
  }

  static void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AutomationSettingsScreen(
          onDevTap: kDebugMode ? () => _openDev(context) : null,
        ),
      ),
    );
  }

  static void _openDev(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => const AutomationDevScreen(),
        // Transición completa: fade + escala (glass morph) + slide lateral.
        transitionsBuilder: (_, anim, __, child) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(curved),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}
