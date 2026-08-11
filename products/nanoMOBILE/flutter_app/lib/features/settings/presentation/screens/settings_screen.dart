import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/app_providers.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';

/// Opciones disponibles para el modo de tema.
const _themeOptions = ['Sistema', 'Oscuro', 'Claro'];

/// Modos de ahorro de batería.
const _batteryModes = ['Eco', 'Balanced', 'Survival'];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final colors = NanoThemeExtension.of(context).colors;
    final shadow = NanoShadows.card(colors);

    return ListView(
      padding: const EdgeInsets.all(NanoSpacing.lg),
      children: [
        _SectionHeader('General', Icons.tune, colors: colors),
        _Card(
          shadow: shadow,
          colors: colors,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.brightness_6,
                    size: NanoIcons.small,
                    color: colors.primary,
                  ),
                  const SizedBox(width: NanoSpacing.sm),
                  Text('Tema', style: NanoType.body(colors.onSurface)),
                ],
              ),
              const SizedBox(height: NanoSpacing.md),
              Row(
                children: _themeOptions
                    .map(
                      (o) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: NanoSpacing.sm),
                          child: ChoiceChip(
                            label: Text(
                              o,
                              style: NanoType.caption(colors.onSurface),
                            ),
                            selected: state.themeMode == o,
                            onSelected: (_) => notifier.setThemeMode(o),
                            selectedColor: colors.primaryContainer,
                            side: BorderSide.none,
                            shape: const RoundedRectangleBorder(
                              borderRadius: NanoShapes.full,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: NanoSpacing.md),
        _SectionHeader('Memoria RAM', Icons.memory, colors: colors),
        _Card(
          shadow: shadow,
          colors: colors,
          child: Column(
            children: [
              _SwitchRow(
                title: 'madvise Layer Streaming',
                subtitle: 'Descarga por capa (VMA < 1GB)',
                value: state.madvise,
                onChanged: notifier.toggleMadvise,
                colors: colors,
              ),
              const Divider(height: 1),
              _SwitchRow(
                title: 'OOM Guard System',
                subtitle: 'Modo supervivencia pre-crash',
                value: state.oomGuard,
                onChanged: notifier.toggleOom,
                colors: colors,
              ),
            ],
          ),
        ),
        const SizedBox(height: NanoSpacing.md),
        _SectionHeader('Control Térmico', Icons.thermostat, colors: colors),
        _Card(
          shadow: shadow,
          colors: colors,
          child: _SliderRow(
            label: 'Límite Temperatura Max',
            value: state.thermalLimit,
            min: 35,
            max: 50,
            unit: '°C',
            onChanged: notifier.setThermalLimit,
            colors: colors,
          ),
        ),
        const SizedBox(height: NanoSpacing.md),
        _SectionHeader('Inferencia LLM', Icons.psychology, colors: colors),
        _Card(
          shadow: shadow,
          colors: colors,
          child: Column(
            children: [
              _SliderRow(
                label: 'Temperatura (Creatividad)',
                value: state.temperature,
                min: 0.1,
                max: 1.5,
                onChanged: notifier.setTemperature,
                colors: colors,
              ),
              _SliderRow(
                label: 'Top-P Sampling',
                value: state.topP,
                min: 0.1,
                max: 1.0,
                onChanged: notifier.setTopP,
                colors: colors,
              ),
              _SliderRow(
                label: 'Tokens máximos',
                value: state.maxTokens.toDouble(),
                min: 64,
                max: 2048,
                onChanged: (v) => notifier.setMaxTokens(v.round()),
                colors: colors,
              ),
            ],
          ),
        ),
        const SizedBox(height: NanoSpacing.md),
        _SectionHeader('Batería', Icons.battery_std, colors: colors),
        _Card(
          shadow: shadow,
          colors: colors,
          child: Row(
            children: _batteryModes
                .map(
                  (o) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: NanoSpacing.sm),
                      child: ChoiceChip(
                        label: Text(
                          o,
                          style: NanoType.caption(colors.onSurface),
                        ),
                        selected: state.batteryMode == o,
                        onSelected: (_) => notifier.setBatteryMode(o),
                        selectedColor: colors.primaryContainer,
                        side: BorderSide.none,
                        shape: const RoundedRectangleBorder(
                          borderRadius: NanoShapes.full,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: NanoSpacing.xxxl),
      ],
    );
  }
}

// ── Section Header ──
class _SectionHeader extends StatelessWidget {
  final String text;
  final IconData icon;
  final NanoColors colors;
  const _SectionHeader(this.text, this.icon, {required this.colors});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: NanoSpacing.sm),
    child: Row(
      children: [
        Icon(icon, size: NanoIcons.small, color: colors.primary),
        const SizedBox(width: NanoSpacing.sm),
        Text(
          text.toUpperCase(),
          style: NanoType.overline(colors.onSurfaceVariant),
        ),
      ],
    ),
  );
}

// ── Card Wrapper ──
class _Card extends StatelessWidget {
  final Widget child;
  final List<BoxShadow> shadow;
  final NanoColors colors;
  const _Card({
    required this.child,
    required this.shadow,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(NanoSpacing.lg),
    decoration: BoxDecoration(
      color: colors.surface,
      borderRadius: NanoShapes.large,
      border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
      boxShadow: shadow,
    ),
    child: child,
  );
}

// ── Switch Row ──
class _SwitchRow extends StatelessWidget {
  final String title, subtitle;
  final bool value;
  final Function(bool) onChanged;
  final NanoColors colors;
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: NanoSpacing.sm),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: NanoType.body(colors.onSurface)),
              Text(subtitle, style: NanoType.caption(colors.onSurfaceVariant)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: colors.primary.withValues(alpha: 0.4),
        ),
      ],
    ),
  );
}

// ── Slider Row ──
class _SliderRow extends StatelessWidget {
  final String label;
  final double value, min, max;
  final String? unit;
  final Function(double) onChanged;
  final NanoColors colors;
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.unit,
    required this.onChanged,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final display =
        '${value.toStringAsFixed(1)}${unit != null ? ' $unit' : ''}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NanoSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: NanoType.body(colors.onSurface)),
              Text(display, style: NanoType.subtitle(colors.primary)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: colors.primary,
            inactiveColor: colors.outlineVariant.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}
