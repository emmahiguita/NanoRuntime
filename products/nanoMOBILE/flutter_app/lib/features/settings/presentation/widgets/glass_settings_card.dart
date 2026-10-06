import 'package:flutter/material.dart';
import 'package:nanoai/core/providers/app_providers.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';
import 'package:nanoai/core/widgets/glass_surface.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';
import 'settings_slider_tile.dart';

/// QUÉ HACE:
/// Tarjeta de configuración para el efectos de transparencia (GlassSurface).
///
/// CÓMO FUNCIONA:
/// Permite activar/desactivar los efectos visuales y ajustar en la interfaz
/// la opacidad, claridad y radio de desenfoque, mostrando una previsualización interactiva.
///
/// POR QUÉ:
/// Ofrece al usuario control táctil granular sobre el rendimiento visual y consumo de GPU.
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
                  horizontal: NanoSpacing.md,
                  vertical: NanoSpacing.sm,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: state.glassEnabled
                            ? colors.primary.withValues(alpha: 0.12)
                            : colors.outlineVariant.withValues(alpha: 0.18),
                      ),
                      child: Icon(
                        Icons.blur_on_rounded,
                        size: 20,
                        color: state.glassEnabled
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: NanoSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transparencia de la interfaz',
                            style: NanoType.body(colors.onSurface),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            state.glassEnabled
                                ? 'Transparencia y desenfoque activos.'
                                : 'Efectos desactivados.',
                            style: NanoType.caption(colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: state.glassEnabled,
                      onChanged: notifier.setGlassEnabled,
                      activeThumbColor: colors.primary,
                      inactiveTrackColor: colors.outlineVariant.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              // Controles avanzados si está activo el motor de vidrio
              if (state.glassEnabled) ...[
                const Divider(
                  height: 1,
                  indent: NanoSpacing.md,
                  endIndent: NanoSpacing.md,
                ),
                SettingsSliderTile(
                  label: 'Claridad',
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
                  label: 'Desenfoque',
                  value: state.glassBlur,
                  min: 0.0,
                  max: 40.0,
                  divisions: 40,
                  fractionDigits: 0,
                  unit: 'px',
                  onChanged: notifier.setGlassBlur,
                  colors: colors,
                ),
                // Previsualizador dinámico interactivo adaptado para horizontal
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    NanoSpacing.md,
                    NanoSpacing.xs,
                    NanoSpacing.md,
                    NanoSpacing.md,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: isLandscape ? 95 : 120,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF007AFF),
                            Color(0xFF5856D6),
                            Color(0xFFFF2D55),
                            Color(0xFFFF9500),
                          ],
                        ),
                      ),
                      child: Center(
                        child: GlassSurface(
                          opacity: state.glassOpacity,
                          clarity: state.glassClarity,
                          blur: state.glassBlur,
                          interactive: true,
                          radius: 12,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            children: [
                              const Icon(
                                Icons.touch_app_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Vista previa',
                                style: NanoType.caption(Colors.white),
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
