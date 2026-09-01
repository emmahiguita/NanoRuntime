import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../automation_visual_theme.dart';

/// Navegación real del módulo. Cada destino usa las rutas existentes; no
/// replica pantallas ni mantiene un segundo estado de pestañas.
class AutomationBottomNavigation extends StatelessWidget {
  const AutomationBottomNavigation({super.key, this.onAutomationTap});

  final VoidCallback? onAutomationTap;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AutomationVisual.surface,
      border: Border(top: BorderSide(color: AutomationVisual.line)),
    ),
    child: SafeArea(
      top: false,
      child: NavigationBar(
        height: 70,
        selectedIndex: 0,
        backgroundColor: AutomationVisual.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AutomationVisual.accentSoft,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(
              Icons.smart_toy_rounded,
              color: AutomationVisual.accent,
            ),
            label: 'Automatización',
          ),
          NavigationDestination(
            icon: Icon(Icons.terminal_outlined),
            label: 'Terminal',
          ),
          NavigationDestination(icon: Icon(Icons.chat_outlined), label: 'Chat'),
          NavigationDestination(
            icon: Icon(Icons.view_in_ar_outlined),
            label: 'Modelos',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Ajustes',
          ),
        ],
      ),
    ),
  );
}
