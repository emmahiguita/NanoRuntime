import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/core/widgets/navigation/nano_navigation_panel.dart';

import '../automation_visual_theme.dart';

/// Adaptador de rutas de Automatización sobre el FAB global compartido.
/// La geometría, animación y gestos tienen un solo dueño en `core/navigation`.
class AutomationNavigationFrame extends StatelessWidget {
  const AutomationNavigationFrame({
    super.key,
    required this.child,
    this.onAutomationTap,
    this.hidden = false,
  });

  final Widget child;
  final VoidCallback? onAutomationTap;
  final bool hidden;

  static const List<NavTabSpec> _tabs = [
    (
      icon: Icons.smart_toy_outlined,
      sel: Icons.smart_toy_rounded,
      label: 'Automatización',
    ),
    (
      icon: Icons.terminal_outlined,
      sel: Icons.terminal_rounded,
      label: 'Terminal',
    ),
    (
      icon: Icons.chat_bubble_outline_rounded,
      sel: Icons.chat_bubble_rounded,
      label: 'Chat',
    ),
    (
      icon: Icons.view_in_ar_outlined,
      sel: Icons.view_in_ar_rounded,
      label: 'Modelos',
    ),
    (
      icon: Icons.settings_outlined,
      sel: Icons.settings_rounded,
      label: 'Ajustes',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return NanoFloatingNavigationFrame(
      hidden: hidden,
      tabs: _tabs,
      selectedIndex: 0,
      style: NanoFloatingNavigationStyle(
        accent: visual.accent,
        onAccent: visual.onAccent,
        accentSoft: visual.accentSoft,
        text: visual.text,
        textMuted: visual.textMuted,
        surfaceStart: visual.cardStart,
        surfaceEnd: visual.cardEnd,
        border: visual.cardBorder,
        shadow: visual.shadow,
      ),
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            onAutomationTap?.call();
          case 1:
            context.go('/terminal');
          case 2:
            context.go('/chat');
          case 3:
            context.go('/models');
          case 4:
            context.go('/settings');
        }
      },
      child: child,
    );
  }
}
