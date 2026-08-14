import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/app_providers.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';
import 'package:nanoai/features/settings/presentation/widgets/agent_console_section.dart';
import 'package:nanoai/features/settings/presentation/widgets/settings_widgets.dart';

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

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 560),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Transform.translate(
          offset: Offset(0, 10 * (1 - t)),
          child: Opacity(opacity: t, child: child),
        );
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: NanoSpacing.md, vertical: NanoSpacing.md),
        children: [
          SectionHeader('General', Icons.tune, colors: colors),
          SettingsCard(
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
                Wrap(
                  spacing: NanoSpacing.sm,
                  runSpacing: NanoSpacing.sm,
                  children: [
                    for (final o in _themeOptions)
                      ChoiceChip(
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
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: NanoSpacing.md),
          SectionHeader('Memoria RAM', Icons.memory, colors: colors),
          SettingsCard(
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
          SectionHeader('Control Térmico', Icons.thermostat, colors: colors),
          SettingsCard(
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
          SectionHeader('Inferencia LLM', Icons.psychology, colors: colors),
          SettingsCard(
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
          SectionHeader('Batería', Icons.battery_std, colors: colors),
          SettingsCard(
            shadow: shadow,
            colors: colors,
            child: Wrap(
              spacing: NanoSpacing.sm,
              runSpacing: NanoSpacing.sm,
              children: [
                for (final o in _batteryModes)
                  ChoiceChip(
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
              ],
            ),
          ),
          const SizedBox(height: NanoSpacing.xxxl),
          const AgentConsoleSection(),
          const _DesktopSection(),
          const SizedBox(height: NanoSpacing.xxxl),
        ],
      ),
    );
  }
}

// â”€â”€ Escritorio Linux (protección VNC + almacenamiento compartido) â”€â”€
class _DesktopSection extends ConsumerStatefulWidget {
  const _DesktopSection();

  @override
  ConsumerState<_DesktopSection> createState() => _DesktopSectionState();
}

class _DesktopSectionState extends ConsumerState<_DesktopSection> {
  late final TextEditingController _pwController;
  bool _permBusy = false;
  String? _permResult;

  @override
  void initState() {
    super.initState();
    _pwController = TextEditingController(
      text: ref.read(settingsProvider).vncPassword,
    );
  }

  @override
  void dispose() {
    _pwController.dispose();
    super.dispose();
  }

  /// Recorta al límite de 8 bytes del protocolo VNC y persiste.
  void _applyPassword(String v) {
    var trimmed = v;
    // Bytes UTF-8 (los caracteres multibyte cuentan por bytes, no por
    // codeUnits UTF-16): recortar de atrás hasta caber en 8 bytes.
    while (utf8.encode(trimmed).length > 8 && trimmed.isNotEmpty) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (trimmed != v) {
      _pwController.value = TextEditingValue(
        text: trimmed,
        selection: TextSelection.collapsed(offset: trimmed.length),
      );
    }
    ref.read(settingsProvider.notifier).setVncPassword(trimmed);
  }

  Future<void> _requestStorage() async {
    setState(() {
      _permBusy = true;
      _permResult = null;
    });
    final ok = await NanoRuntimeApi.instance.requestStoragePermission();
    if (!mounted) return;
    setState(() {
      _permBusy = false;
      _permResult = ok
          ? 'Concedido — pcmanfm verá tus fotos, vídeos y audio'
          : 'No se pudo conceder (¿denegado en ajustes del sistema?)';
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final shadow = NanoShadows.card(colors);
    final vncEnabled = ref.watch(settingsProvider).vncPassword.isNotEmpty;
    final notifier = ref.read(settingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Escritorio Linux',
          Icons.desktop_windows,
          colors: colors,
        ),
        SettingsCard(
          shadow: shadow,
          colors: colors,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                value: vncEnabled,
                onChanged: (on) {
                  if (on) {
                    // Activar con el contenido actual del campo (si vacío,
                    // la auth queda pendiente hasta escribirla).
                    notifier.setVncPassword(_pwController.text);
                  } else {
                    _pwController.clear();
                    notifier.setVncPassword('');
                  }
                },
                title: Text(
                  'Protección por contraseña',
                  style: NanoType.body(colors.onSurface),
                ),
                subtitle: Text(
                  'VNC Auth al conectarse al escritorio',
                  style: NanoType.caption(colors.onSurfaceVariant),
                ),
                activeTrackColor: colors.primary,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              if (vncEnabled) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _pwController,
                    obscureText: true,
                    maxLength: 8,
                    inputFormatters: [
                      // ASCII imprimible únicamente: el DES del cliente y el
                      // archivo vncpasswd operan sobre BYTES, y Dart codeUnits
                      // (UTF-16) â‰  bytes UTF-8 para caracteres no ASCII → claves
                      // divergentes entre app y servidor. Con ASCII ambos
                      // coinciden byte a byte.
                      FilteringTextInputFormatter.allow(RegExp(r'[\x20-\x7E]')),
                    ],
                    onChanged: _applyPassword,
                    decoration: InputDecoration(
                      labelText: 'Contraseña (máx. 8 caracteres)',
                      helperText:
                          'Se aplica al iniciar el escritorio; reinícialo si lo cambias.',
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: NanoSpacing.sm),
              ],
              const Divider(height: 1, color: Colors.white12),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Almacenamiento compartido',
                      style: NanoType.body(colors.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'El gestor de archivos (pcmanfm) del escritorio necesita '
                      'este permiso para ver tus fotos, vídeos y audio.',
                      style: NanoType.caption(colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: NanoSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _permBusy ? null : _requestStorage,
                        icon: const Icon(Icons.folder_rounded, size: 18),
                        label: Text(
                          _permBusy
                              ? 'Solicitando…'
                              : 'Permitir acceso a archivos',
                          style: NanoType.body(colors.onSurface),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.primary,
                          side: BorderSide(
                            color: colors.primary.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                    if (_permResult != null) ...[
                      const SizedBox(height: NanoSpacing.sm),
                      Text(
                        _permResult!,
                        style: NanoType.caption(
                          _permResult!.startsWith('Concedido')
                              ? colors.primary
                              : colors.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
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

// â”€â”€ Slider Row â”€â”€
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
