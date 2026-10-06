import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';

/// QUÉ HACE: Selector de tema visual para Nano AI (Oscuro, Claro Blanco/Verde, o Sistema).
/// CÓMO FUNCIONA: Muestra opciones Material Expressive táctiles que disparan [onThemeChanged].
/// POR QUÉ: Permite al usuario alternar entre Obsidian Esmeralda y el nuevo tema Claro Blanco y Verde.
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
    return AutomationSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(NanoSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.palette_outlined, color: colors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tema y apariencia', style: NanoType.body(colors.onSurface).copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('Alterna entre Oscuro, Claro (Blanco y Verde), Clásico (Blanco y Azul) o Sistema.', style: NanoType.caption(colors.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                const options = [
                  ('Oscuro', 'Obsidian', Icons.dark_mode_rounded),
                  ('Claro', 'Blanco & Verde', Icons.eco_rounded),
                  ('Clásico', 'Blanco & Azul', Icons.palette_rounded),
                  ('Sistema', 'Auto', Icons.brightness_auto_rounded),
                ];

                Widget buildTile((String, String, IconData) opt, bool compact) {
                  final isSelected = currentThemeMode == opt.$1;
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

                final isNarrow = constraints.maxWidth < 420;
                if (isNarrow) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: buildTile(options[0], false)),
                          const SizedBox(width: 8),
                          Expanded(child: buildTile(options[1], false)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: buildTile(options[2], false)),
                          const SizedBox(width: 8),
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
                        padding: const EdgeInsets.symmetric(horizontal: 3),
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
    );
  }
}

/// QUÉ HACE: Botón interactivo de opción de tema con estilo Material Expressive.
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
    final activeBg = colors.primary.withValues(alpha: 0.15);
    final inactiveBg = colors.surface.withValues(alpha: 0.30);
    final borderColor = isSelected ? colors.primary : colors.outline.withValues(alpha: 0.40);
    final tint = isSelected ? colors.primary : colors.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: isSelected ? 1.6 : 1.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: tint),
            const SizedBox(height: 5),
            Text(
              id,
              style: NanoType.caption(isSelected ? colors.primary : colors.onSurface).copyWith(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (!isCompact) ...[
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: NanoType.overline(colors.onSurfaceVariant).copyWith(fontSize: 9),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}