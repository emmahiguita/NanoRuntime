import 'package:flutter/material.dart';
import 'package:nanoai/core/providers/app_providers.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';
import 'settings_slider_tile.dart';

/// Parámetros del motor de inferencia IA (Temperatura, Top-P, Longitud máxima) y voz.
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
              const SizedBox(height: 4),
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
                label: 'Diversidad (Top-P)',
                value: state.topP,
                min: 0.1,
                max: 1.0,
                divisions: 9,
                fractionDigits: 2,
                onChanged: notifier.setTopP,
                colors: colors,
              ),
              SettingsSliderTile(
                label: 'Límite de tokens',
                value: state.maxTokens.toDouble(),
                min: 64,
                max: 4096,
                divisions: 63,
                fractionDigits: 0,
                unit: 'tk',
                onChanged: (v) => notifier.setMaxTokens(v.round()),
                colors: colors,
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const AutomationSectionLabel('Voz y Audio'),
        AutomationSurfaceCard(
          child: Padding(
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
                    color: state.voiceEnabled
                        ? colors.primary.withValues(alpha: 0.12)
                        : colors.outlineVariant.withValues(alpha: 0.18),
                  ),
                  child: Icon(
                    state.voiceEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    size: 16,
                    color: state.voiceEnabled
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
                        'Respuestas de voz',
                        style: NanoType.body(colors.onSurface).copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        state.voiceEnabled
                            ? 'Locución automática de síntesis de voz activa.'
                            : 'Solo texto en pantalla.',
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
                    value: state.voiceEnabled,
                    onChanged: notifier.setVoiceEnabled,
                    activeThumbColor: colors.primary,
                    inactiveTrackColor: colors.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
