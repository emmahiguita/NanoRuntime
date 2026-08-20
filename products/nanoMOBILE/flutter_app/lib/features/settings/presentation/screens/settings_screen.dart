import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/app_providers.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_motion.dart';
  import 'package:nanoai/core/theme/nano_type.dart';
  import 'package:nanoai/core/widgets/nano_choice_group.dart';
  import 'package:nanoai/core/widgets/nano_components.dart';
  import 'package:nanoai/core/widgets/nano_section.dart';
  import 'package:nanoai/features/settings/presentation/widgets/device_permissions_section.dart';

/// Opciones disponibles para el modo de tema.
const _themeOptions = [
  ChoiceOption('Sistema', 'Sistema', Icons.brightness_auto_rounded),
  ChoiceOption('Oscuro', 'Oscuro', Icons.dark_mode_rounded),
  ChoiceOption('Claro', 'Claro', Icons.light_mode_rounded),
];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final colors = NanoThemeExtension.of(context).colors;
    
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduceMotion ? Duration.zero : NanoMotionDurations.navigation,
      curve: NanoMotionCurves.standardDecel,
      builder: (context, t, child) {
        return Transform.translate(
          offset: Offset(0, 10 * (1 - t)),
          child: Opacity(opacity: t, child: child),
        );
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useColumns = constraints.maxWidth >= 600;
          final pagePadding = constraints.maxWidth >= 900
              ? NanoSpacing.xl
              : NanoSpacing.md;
          final primary = <Widget>[
            _themeSection(state, notifier, colors),
          ];
          final secondary = <Widget>[
            _inferenceSection(state, notifier, colors),
          ];

          return ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              pagePadding,
              NanoSpacing.md,
              pagePadding,
              NanoSpacing.xxxl,
            ),
            children: [
              _SettingsIntro(colors: colors, themeMode: state.themeMode),
              // En wide: 2x2 balanceado (Apariencia|Generación, Permisos|
              // Escritorio) — las 4 cards aprovechan el ancho en vez de
              // apilarse dejando la mitad vacía. En compact: columna única
              // con gaps reducidos (antes xl=24, desperdiciaba vertical).
              if (useColumns)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          ...primary,
                          const SizedBox(height: NanoSpacing.md),
                          const DevicePermissionsSection(),
                        ],
                      ),
                    ),
                    const SizedBox(width: NanoSpacing.lg),
                    Expanded(
                      child: Column(
                        children: [
                          ...secondary,
                          const SizedBox(height: NanoSpacing.md),
                          const _DesktopSection(),
                        ],
                      ),
                    ),
                  ],
                )
              else ...[
                ...primary,
                const SizedBox(height: NanoSpacing.md),
                ...secondary,
                const SizedBox(height: NanoSpacing.md),
                const DevicePermissionsSection(),
                const SizedBox(height: NanoSpacing.md),
                const _DesktopSection(),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required NanoColors colors,
        required Widget child,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: NanoSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title, icon, colors: colors),
          NanoCard(padding: EdgeInsets.zero, child: child),
      ],
    ),
  );

  Widget _themeSection(
    SettingsState state,
    SettingsNotifier notifier,
    NanoColors colors,
      ) => _section(
    title: 'Apariencia',
    icon: Icons.palette_rounded,
    colors: colors,
        child: ChoiceGroup(
      label: 'Tema de la interfaz',
      description: 'Se aplica al instante y respeta el modo del sistema.',
      options: _themeOptions,
      selectedValue: state.themeMode,
      onSelected: notifier.setThemeMode,
      colors: colors,
    ),
  );

  Widget _inferenceSection(
    SettingsState state,
    SettingsNotifier notifier,
    NanoColors colors,
      ) => _section(
    title: 'Generación de IA',
    icon: Icons.psychology_rounded,
    colors: colors,
        child: Column(
      children: [
        _SliderRow(
          label: 'Creatividad',
          value: state.temperature,
          min: 0.1,
          max: 1.5,
          divisions: 14,
          onChanged: notifier.setTemperature,
          colors: colors,
        ),
        _SliderRow(
          label: 'Diversidad de respuesta',
          value: state.topP,
          min: 0.1,
          max: 1.0,
          divisions: 9,
          onChanged: notifier.setTopP,
          colors: colors,
        ),
        _SliderRow(
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
  );

}

class _SettingsIntro extends StatelessWidget {
  const _SettingsIntro({required this.colors, required this.themeMode});

  final NanoColors colors;
  final String themeMode;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.primary.withValues(alpha: 0.24),
                colors.accentCyan.withValues(alpha: 0.10),
              ],
            ),
            border: Border.all(color: colors.primary.withValues(alpha: 0.22)),
          ),
          child: Icon(Icons.tune_rounded, color: colors.primary),
        ),
        const SizedBox(width: NanoSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ajustes', style: NanoType.title(colors.onSurface)),
              const SizedBox(height: NanoSpacing.xs),
              Text(
                'Personaliza el rendimiento, la IA y la apariencia.',
                style: NanoType.caption(colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        AnimatedSwitcher(
          duration: NanoMotion.adapt(context, NanoMotionDurations.standard),
          child: Container(
            key: ValueKey(themeMode),
            padding: const EdgeInsets.symmetric(
              horizontal: NanoSpacing.md,
              vertical: NanoSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.10),
              borderRadius: NanoShapes.full,
            ),
            child: Text(themeMode, style: NanoType.caption(colors.primary)),
          ),
        ),
      ],
    ),
  );
}

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
        final vncProtected = ref.watch(settingsProvider).vncPassword.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Escritorio Linux',
          Icons.desktop_windows,
          colors: colors,
        ),
          NanoCard(
            padding: EdgeInsets.zero,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _pwController,
                  obscureText: true,
                  maxLength: 8,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\x20-\x7E]')),
                  ],
                  onChanged: _applyPassword,
                  decoration: InputDecoration(
                    labelText: 'Contraseña de VNC (opcional, máx. 8)',
                    helperText: vncProtected
                        ? 'Protección activa; se aplica al iniciar el escritorio.'
                        : 'Sin contraseña, VNC inicia sin protección.',
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              Divider(height: 1, color: colors.outlineVariant),
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
                    OutlinedButton.icon(
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

// â”€â”€ Slider Row â”€â”€
class _SliderRow extends StatelessWidget {
  final String label;
  final double value, min, max;
  final String? unit;
  final int? divisions;
  final int fractionDigits;
  final Function(double) onChanged;
  final NanoColors colors;
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.unit,
    this.divisions,
    this.fractionDigits = 1,
    required this.onChanged,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(min, max).toDouble();
    final display =
        '${safeValue.toStringAsFixed(fractionDigits)}${unit != null ? ' $unit' : ''}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NanoSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: NanoType.body(colors.onSurface),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: NanoSpacing.sm),
              Text(display, style: NanoType.subtitle(colors.primary)),
            ],
          ),
          Slider(
            value: safeValue,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            activeColor: colors.primary,
            inactiveColor: colors.outlineVariant.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}
