import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/providers/app_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // La carga persistida se realiza en main.dart (NanoPlatformApp.initState)
  // para que el tema aplica desde el arranque. Nada que hacer aquí.

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final colors = NanoThemeExtension.of(context).colors;
    final shadow = NanoShadows.card(colors);

    void onTheme(String m) => notifier.setThemeMode(m);

    Widget card(Widget child) => Container(
      width: double.infinity, padding: const EdgeInsets.all(NanoSpacing.lg),
      decoration: BoxDecoration(color: colors.surface, borderRadius: NanoShapes.large, border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)), boxShadow: shadow), child: child);

    return ListView(padding: const EdgeInsets.all(NanoSpacing.lg), children: [
        _h('General', Icons.tune, colors),
        card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.brightness_6, size: 18, color: colors.primary), const SizedBox(width: NanoSpacing.sm), Text('Tema', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.onSurface))]),
          const SizedBox(height: NanoSpacing.md),
          Row(children: ['Sistema', 'Oscuro', 'Claro'].map((o) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(o, style: const TextStyle(fontSize: 11)), selected: state.themeMode == o, onSelected: (_) => onTheme(o), selectedColor: colors.primaryContainer, side: BorderSide.none, shape: RoundedRectangleBorder(borderRadius: NanoShapes.full))))).toList()),
        ])),
        const SizedBox(height: NanoSpacing.md),
        _h('Memoria RAM', Icons.memory, colors),
        card(Column(children: [_sw('madvise Layer Streaming', 'Descarga por capa (VMA < 1GB)', state.madvise, notifier.toggleMadvise, colors), const Divider(height: 1), _sw('OOM Guard System', 'Modo supervivencia pre-crash', state.oomGuard, notifier.toggleOom, colors)])),
        const SizedBox(height: NanoSpacing.md),
        _h('Control Térmico', Icons.thermostat, colors),
        card(_sl('Límite Temperatura Max', state.thermalLimit, 35, 50, '°C', notifier.setThermalLimit, colors)),
        const SizedBox(height: NanoSpacing.md),
        _h('Inferencia LLM', Icons.psychology, colors),
        card(Column(children: [_sl('Temperatura (Creatividad)', state.temperature, 0.1, 1.5, '', notifier.setTemperature, colors), _sl('Top-P Sampling', state.topP, 0.1, 1.0, '', notifier.setTopP, colors)])),
        const SizedBox(height: NanoSpacing.md),
        _h('Batería', Icons.battery_std, colors),
        card(Row(children: ['Eco', 'Balanced', 'Survival'].map((o) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(o, style: const TextStyle(fontSize: 11)), selected: state.batteryMode == o, onSelected: (_) => notifier.setBatteryMode(o), selectedColor: colors.primaryContainer, side: BorderSide.none, shape: RoundedRectangleBorder(borderRadius: NanoShapes.full))))).toList())),
        const SizedBox(height: NanoSpacing.xxxl),
      ],
    );
  }

  Widget _h(String t, IconData i, NanoColors c) => Padding(padding: const EdgeInsets.only(bottom: NanoSpacing.sm), child: Row(children: [Icon(i, size: 16, color: c.primary), const SizedBox(width: NanoSpacing.sm), Text(t.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.onSurfaceVariant, letterSpacing: 0.8))]));
  Widget _sw(String t, String s, bool v, Function(bool) cb, NanoColors c) => Padding(padding: const EdgeInsets.symmetric(vertical: NanoSpacing.sm), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.onSurface)), Text(s, style: TextStyle(fontSize: 11, color: c.onSurfaceVariant))])), Switch(value: v, onChanged: cb, activeTrackColor: c.primary.withValues(alpha: 0.4))]));
  Widget _sl(String t, double v, double min, double max, String u, Function(double) cb, NanoColors c) => Padding(padding: const EdgeInsets.symmetric(vertical: NanoSpacing.sm), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.onSurface)), Text('${v.toStringAsFixed(1)} $u', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.primary))]), Slider(value: v, min: min, max: max, onChanged: cb, activeColor: c.primary, inactiveColor: c.outlineVariant.withValues(alpha: 0.5))]));
}
