import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/design_tokens.dart';
import 'nano_destination.dart';
import 'nano_multi_use_nav_bar.dart';

typedef NavTabSpec = ({IconData icon, IconData sel, String label});

enum NanoNavigationDock { topLeft, topRight, bottomLeft, bottomRight }

@immutable
class NanoFloatingNavigationStyle {
  const NanoFloatingNavigationStyle({
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.text,
    required this.textMuted,
    required this.surfaceStart,
    required this.surfaceEnd,
    required this.border,
    required this.shadow,
  });

  factory NanoFloatingNavigationStyle.fromTheme(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return NanoFloatingNavigationStyle(
      accent: colors.primary,
      onAccent: colors.onAccent,
      accentSoft: colors.primary.withValues(alpha: isDark ? 0.18 : 0.12),
      text: colors.textPrimary,
      textMuted: colors.textSecondary,
      surfaceStart: isDark
          ? colors.glass100.withValues(alpha: 0.90)
          : Colors.white.withValues(alpha: 0.88),
      surfaceEnd: isDark
          ? colors.glassBlue.withValues(alpha: 0.72)
          : colors.glassSecondary.withValues(alpha: 0.68),
      border: isDark ? colors.borderAccentColor : colors.borderPrimaryColor,
      shadow: Colors.black.withValues(alpha: isDark ? 0.34 : 0.14),
    );
  }

  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color text;
  final Color textMuted;
  final Color surfaceStart;
  final Color surfaceEnd;
  final Color border;
  final Color shadow;
}

/// Marco de navegación principal de Nano AI.
///
/// Integra el nuevo dock cósmico multifunción (avatar con punto online,
/// barra de búsqueda/prompt interactiva y 6 pestañas de navegación con
/// indicador de punto cian brillante).
class NanoFloatingNavigationFrame extends StatelessWidget {
  const NanoFloatingNavigationFrame({
    super.key,
    required this.child,
    required this.tabs,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.style,
    this.hidden = false,
    this.onSearch,
    this.onVoice,
    this.onAvatarTap,
    this.searchHint = 'Describe qué quieres automatizar...',
    this.initialDock = NanoNavigationDock.bottomRight,
  });

  final Widget child;
  final List<NavTabSpec> tabs;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final NanoFloatingNavigationStyle? style;
  final bool hidden;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onVoice;
  final VoidCallback? onAvatarTap;
  final String searchHint;
  final NanoNavigationDock initialDock;

  @override
  Widget build(BuildContext context) {
    final destination = NanoDestination.fromIndex(selectedIndex);
    final brightness = Theme.of(context).brightness;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isCompact = screenWidth < 520;
        final maxDockWidth = math.min(screenWidth - 20, 620.0);

        return Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: Padding(
                padding: EdgeInsets.only(bottom: hidden ? 0 : 105),
                child: child,
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              left: 0,
              right: 0,
              bottom: hidden ? -220 : 10,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: hidden ? 0.0 : 1.0,
                curve: Curves.easeInOut,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxDockWidth),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: NanoMultiUseNavBar(
                        selected: destination,
                        compact: isCompact,
                        brightness: brightness,
                        searchHint: searchHint,
                        onDestinationSelected: (d) {
                          onDestinationSelected(d.index);
                        },
                        onSearch: onSearch ??
                            (query) {
                              context.push('/automation');
                            },
                        onVoice: onVoice ??
                            () {
                              context.push('/automation');
                            },
                        onAvatarTap: onAvatarTap ??
                            () {
                              context.push('/automation');
                            },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
