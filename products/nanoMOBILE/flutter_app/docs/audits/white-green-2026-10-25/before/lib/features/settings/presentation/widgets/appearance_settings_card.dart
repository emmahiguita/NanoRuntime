import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';

/// Selector ejecutivo de tema visual iOS Glassed Metálico:
/// - Oscuro (Obsidian & Cosmic Blue)
/// - Grisáceo (Space Gray / Titanio Pizarra Mate)
/// - Claro (Pure Frost & Ice Silver)
/// - Sistema (Detección automática del dispositivo)
class AppearanceSettingsCard extends StatelessWidget {
  final NanoColors colors;
  final String currentThemeMode;
  final ValueChanged<String> onThemeChanged;

  const AppearanceSettingsCard({
    super.key,
    required this.colors,
    required this.currentThemeMode,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AutomationSectionLabel('Apariencia'),
        AutomationSurfaceCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Icon(
                        Icons.palette_outlined,
                        color: colors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tema del sistema',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: colors.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Oscuro Obsidian, Grisáceo Mate, Claro Frost o Sistema.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: colors.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const options = [
                      ('Oscuro', 'Obsidiana', Icons.dark_mode_rounded),
                      ('Grisáceo', 'Gris Espacial', Icons.layers_rounded),
                      ('Claro', 'Blanco Puro', Icons.wb_sunny_rounded),
                      ('Sistema', 'Automático', Icons.brightness_auto_rounded),
                    ];

                    Widget buildTile((String, String, IconData) opt, bool compact) {
                      final isSelected =
                          currentThemeMode == opt.$1 ||
                          (opt.$1 == 'Grisáceo' &&
                              (currentThemeMode == 'Opaco' ||
                                  currentThemeMode == 'Clásico'));
                      return _ThemeTile(
                        id: opt.$1,
                        sublabel: opt.$2,
                        icon: opt.$3,
                        isSelected: isSelected,
                        isCompact: compact,
                        colors: colors,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onThemeChanged(opt.$1);
                        },
                      );
                    }

                    final isNarrow = constraints.maxWidth < 380;
                    if (isNarrow) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: buildTile(options[0], false)),
                              const SizedBox(width: 6),
                              Expanded(child: buildTile(options[1], false)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(child: buildTile(options[2], false)),
                              const SizedBox(width: 6),
                              Expanded(child: buildTile(options[3], false)),
                            ],
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: options.map((opt) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.5),
                            child: buildTile(opt, false),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Botón interactivo táctil de opción de tema estilo iOS Segmented Item sobrio.
class _ThemeTile extends StatelessWidget {
  final String id, sublabel;
  final IconData icon;
  final bool isSelected, isCompact;
  final NanoColors colors;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.id,
    required this.sublabel,
    required this.icon,
    required this.isSelected,
    required this.isCompact,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isDark
        ? colors.surfaceVariant.withValues(alpha: 0.80)
        : colors.surface;
    final inactiveBg = isDark
        ? colors.surfaceVariant.withValues(alpha: 0.25)
        : colors.backgroundElevated.withValues(alpha: 0.50);
    final borderColor = isSelected
        ? colors.primary.withValues(alpha: 0.45)
        : colors.outlineVariant.withValues(alpha: isDark ? 0.20 : 0.35);
    final tint = isSelected ? colors.primary : colors.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: colors.primary.withValues(alpha: 0.08),
        highlightColor: colors.primary.withValues(alpha: 0.04),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : inactiveBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 1.0 : 0.7,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colors.onSurface.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: tint),
              const SizedBox(height: 4),
              Text(
                id,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: isSelected ? colors.primary : colors.onSurface,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 11.5,
                  decoration: TextDecoration.none,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (!isCompact) ...[
                const SizedBox(height: 1),
                Text(
                  sublabel,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: isSelected
                        ? colors.primary.withValues(alpha: 0.85)
                        : colors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
