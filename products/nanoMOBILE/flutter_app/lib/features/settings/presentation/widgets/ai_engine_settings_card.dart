import 'package:flutter/material.dart';
import 'package:nanoai/core/providers/app_providers.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';
import 'settings_slider_tile.dart';

/// QUÉ HACE:
/// Tarjeta de configuración para los parámetros del motor de inferencia IA
/// local/remoto (Temperatura, Top-P, Longitud máxima de tokens) y síntesis de voz.
///
/// CÓMO FUNCIONA:
/// Conecta sliders adaptados con [SettingsNotifier] para guardar en tiempo real
/// las preferencias del modelo sin reiniciar la sesión del chat.
///
/// POR QUÉ:
/// Permite al usuario calibrar el balance entre respuestas deterministas vs creativas,
/// optimizando el consumo de batería y la velocidad de respuesta.
class AiEngineSettingsCard extends StatelessWidget {
  final SettingsState state;
  final SettingsNotifier notifier;
  final NanoColors colors;

  const AiEngineSettingsCard({
    super.key,
    required this.state,
    required this.notifier,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AutomationSectionLabel('Generación de IA'),
        AutomationSurfaceCard(
          child: Column(
            children: [
              SettingsSliderTile(
                label: 'Creatividad (Temperature)',
                value: state.temperature,
                min: 0.1,
                max: 1.5,
                divisions: 14,
                fractionDigits: 2,
                onChanged: notifier.setTemperature,
                colors: colors,
              ),
              SettingsSliderTile(
                label: 'Diversidad de respuesta (Top-P)',
                value: state.topP,
                min: 0.1,
                max: 1.0,
                divisions: 9,
                fractionDigits: 2,
                onChanged: notifier.setTopP,
                colors: colors,
              ),
              SettingsSliderTile(
                label: 'Longitud máxima',
                value: state.maxTokens.toDouble(),
                min: 64,
                max: 4096,
                divisions: 63,
                fractionDigits: 0,
                unit: 'tokens',
                onChanged: (v) => notifier.setMaxTokens(v.round()),
                colors: colors,
              ),
            ],
          ),
        ),
        const SizedBox(height: NanoSpacing.md),
        const AutomationSectionLabel('Voz y Audio'),
        AutomationSurfaceCard(
          child: Padding(
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
                    color: state.voiceEnabled
                        ? colors.primary.withValues(alpha: 0.12)
                        : colors.outlineVariant.withValues(alpha: 0.18),
                  ),
                  child: Icon(
                    state.voiceEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    size: 18,
                    color: state.voiceEnabled
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
                        'Respuestas de voz',
                        style: NanoType.body(colors.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.voiceEnabled
                            ? 'Nano habla las respuestas tras un mensaje de audio.'
                            : 'Solo respuestas en texto.',
                        style: NanoType.caption(colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: state.voiceEnabled,
                  onChanged: notifier.setVoiceEnabled,
                  activeThumbColor: colors.primary,
                  inactiveTrackColor: colors.outlineVariant.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
