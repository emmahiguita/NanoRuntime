import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import 'nano_dock_controller.dart';
import 'nano_navigation_panel.dart';

/// Adaptador visual legado. La aplicación ya navega mediante
/// [NanoFloatingNavigationFrame]; se conserva este contrato para consumidores
/// externos mientras migran, sin controladores ni estado persistente.
@Deprecated('Usa NanoFloatingNavigationFrame.')
class NanoSelectionMorphBar extends StatelessWidget {
  const NanoSelectionMorphBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.colors,
    required this.onTabSelected,
    required this.position,
    required this.isMinimized,
  });

  final List<NavTabSpec> tabs;
  final int selectedIndex;
  final NanoColors colors;
  final ValueChanged<int> onTabSelected;
  final NavPosition position;
  final bool isMinimized;

  @override
  Widget build(BuildContext context) {
    final horizontal = position == NavPosition.top;
    final children = [
      for (var index = 0; index < tabs.length; index++)
        _LegacyDestination(
          spec: tabs[index],
          selected: index == selectedIndex,
          iconOnly: isMinimized,
          colors: colors,
          onTap: () => onTabSelected(index),
        ),
    ];
    return horizontal
        ? Row(mainAxisSize: MainAxisSize.min, children: children)
        : Column(mainAxisSize: MainAxisSize.min, children: children);
  }
}

class _LegacyDestination extends StatelessWidget {
  const _LegacyDestination({
    required this.spec,
    required this.selected,
    required this.iconOnly,
    required this.colors,
    required this.onTap,
  });

  final NavTabSpec spec;
  final bool selected;
  final bool iconOnly;
  final NanoColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? colors.primary : colors.textSecondary;
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(99),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? spec.sel : spec.icon,
                  size: 19,
                  color: foreground,
                ),
                if (!iconOnly) ...[
                  const SizedBox(width: 7),
                  Text(
                    spec.label,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
