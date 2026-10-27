import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';

part 'appearance_theme_tile.part.dart';

/// Selector ejecutivo de tema visual iOS Glassed Metálico:
/// - Oscuro (Obsidian & Cosmic Blue)
/// - Grisáceo (Space Gray / Titanio Pizarra Mate)
/// - Claro (Blanco Frost y verde)
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
                            'Oscuro Obsidian, Grisáceo Mate, Claro blanco y verde o Sistema.',
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
                      ('Claro', 'Blanco y verde', Icons.wb_sunny_rounded),
                      ('Sistema', 'Automático', Icons.brightness_auto_rounded),
                    ];

                    Widget buildTile(
                      (String, String, IconData) opt,
                      bool compact,
                    ) {
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2.5,
                            ),
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
