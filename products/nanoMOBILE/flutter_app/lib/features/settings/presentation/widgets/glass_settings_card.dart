import 'package:flutter/material.dart';
import 'package:nanoai/core/providers/app_providers.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';
import 'package:nanoai/core/widgets/glass_surface.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';
import 'settings_slider_tile.dart';

/// Configuración para efectos de transparencia óptica (iOS GlassSurface).
class GlassSettingsCard extends StatelessWidget {
  final SettingsState state;
  final SettingsNotifier notifier;
  final NanoColors colors;

  const GlassSettingsCard({
    super.key,
    required this.state,
    required this.notifier,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AutomationSectionLabel('Efectos visuales'),
        AutomationSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Fila principal del Switch de activación
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: state.glassEnabled
                            ? colors.primary.withValues(alpha: 0.12)
                            : colors.outlineVariant.withValues(alpha: 0.18),
                      ),
                      child: Icon(
                        Icons.blur_on_rounded,
                        size: 18,
                        color: state.glassEnabled
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transparencia de la interfaz',
                            style: NanoType.body(colors.onSurface).copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            state.glassEnabled
                                ? 'Vidrio translúcido y desenfoque óptico activos.'
                                : 'Efectos desactivados para máximo rendimiento.',
                            style: NanoType.caption(colors.onSurfaceVariant).copyWith(
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Transform.scale(
                      scale: 0.85,
                      child: Switch(
                        value: state.glassEnabled,
                        onChanged: notifier.setGlassEnabled,
                        activeThumbColor: colors.primary,
                        inactiveTrackColor: colors.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Controles avanzados si está activo el motor de vidrio
              if (state.glassEnabled) ...[
                Divider(
                  height: 1,
                  indent: 12,
                  endIndent: 12,
                  color: colors.outlineVariant.withValues(alpha: 0.25),
                ),
                const SizedBox(height: 4),
                SettingsSliderTile(
                  label: 'Claridad óptica',
                  value: state.glassClarity,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  fractionDigits: 2,
                  onChanged: notifier.setGlassClarity,
                  colors: colors,
                ),
                SettingsSliderTile(
                  label: 'Opacidad',
                  value: state.glassOpacity,
                  min: 0.05,
                  max: 1.00,
                  divisions: 19,
                  fractionDigits: 2,
                  onChanged: notifier.setGlassOpacity,
                  colors: colors,
                ),
                SettingsSliderTile(
                  label: 'Desenfoque (Blur)',
                  value: state.glassBlur,
                  min: 0.0,
                  max: 40.0,
                  divisions: 40,
                  fractionDigits: 0,
                  unit: 'px',
                  onChanged: notifier.setGlassBlur,
                  colors: colors,
                ),
                // Previsualizador dinámico interactivo
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: isLandscape ? 70 : 85,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF2563EB),
                            Color(0xFF6366F1),
                            Color(0xFFEC4899),
                            Color(0xFFF97316),
                          ],
                        ),
                      ),
                      child: Center(
                        child: GlassSurface(
                          opacity: state.glassOpacity,
                          clarity: state.glassClarity,
                          blur: state.glassBlur,
                          interactive: true,
                          radius: 10,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.touch_app_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Vista previa Glass',
                                style: NanoType.caption(Colors.white).copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
