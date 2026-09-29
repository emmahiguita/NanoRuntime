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
import 'package:nanoai/core/widgets/navigation/nano_navigation_panel.dart';
import 'package:nanoai/features/settings/presentation/widgets/device_permissions_section.dart';
import 'package:nanoai/features/settings/presentation/widgets/floating_assistant_section.dart';
import 'package:nanoai/features/settings/presentation/widgets/account_settings_card.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';
import 'package:nanoai/core/widgets/glass_surface.dart';

/// Modo claro/sistema pendiente hasta completar sus superficies y contrastes.
const _themeOptions = [
  ChoiceOption('Oscuro', 'Oscuro', Icons.dark_mode_rounded),
];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final colors = NanoThemeExtension.of(context).colors;

    // PERFORMANCE: Render directo sin fade retardado de opacidad 0.
    // Que hace: muestra el contenido inmediatamente al conmutar a la pestaña.
    // Como funciona: elimina el retardo de 180ms del TweenAnimationBuilder.
    // Por que: hace que el cambio a Ajustes sea 100% instantáneo.
    return Stack(
      fit: StackFit.expand,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final useColumns = constraints.maxWidth >= 600;
            final pagePadding = constraints.maxWidth >= 900
                ? NanoSpacing.xl
                : NanoSpacing.md;
            final primary = <Widget>[
              _themeSection(colors),
              _glassSurfaceSection(context, state, notifier, colors),
            ];
            final secondary = <Widget>[
              _inferenceSection(state, notifier, colors),
              const SizedBox(height: NanoSpacing.md),
              _voiceSection(state, notifier, colors),
            ];

            return ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                pagePadding,
                NanoSpacing.md,
                pagePadding,
                kNanoBarScrollReserve,
              ),
              children: [
                _SettingsIntro(colors: colors, themeMode: 'Oscuro'),
                const SizedBox(height: NanoSpacing.md),
                const AccountSettingsSection(),
                const SizedBox(height: NanoSpacing.md),
                if (useColumns)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            ...primary,
                            const SizedBox(height: NanoSpacing.md),
                            const FloatingAssistantSection(),
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
                  const FloatingAssistantSection(),
                  const SizedBox(height: NanoSpacing.md),
                  const DevicePermissionsSection(),
                  const SizedBox(height: NanoSpacing.md),
                  const _DesktopSection(),
                ],
              ],
            );
          },
        ),
      ],
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AutomationSectionLabel(title),
        AutomationSurfaceCard(child: child),
      ],
    ),
  );

  Widget _themeSection(NanoColors colors) => _section(
    title: 'Apariencia',
    icon: Icons.palette_rounded,
    colors: colors,
    child: Padding(
      padding: const EdgeInsets.all(NanoSpacing.md),
      child: ChoiceGroup(
        label: 'Tema de la interfaz',
        description: 'Modo oscuro fijo mientras se finaliza el tema claro.',
        options: _themeOptions,
        selectedValue: 'Oscuro',
        onSelected: (_) {},
        colors: colors,
      ),
    ),
  );

  Widget _glassSurfaceSection(
    BuildContext context,
    SettingsState state,
    SettingsNotifier notifier,
    NanoColors colors,
  ) => _section(
    title: 'Superficie de Vidrio iOS (GlassSurface)',
    icon: Icons.auto_awesome_rounded,
    colors: colors,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                      'Vidrio Líquido iOS (GlassSurface)',
                      style: NanoType.body(colors.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.glassEnabled
                          ? 'Transparencia, opacidad y refracción hiperrealista activas.'
                          : 'Efectos de vidrio óptico desactivados.',
                      style: NanoType.caption(colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: NanoSpacing.sm),
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
        if (state.glassEnabled) ...[
          const Divider(
            height: 1,
            indent: NanoSpacing.md,
            endIndent: NanoSpacing.md,
          ),
          _SliderRow(
            label: 'Transparencia y Claridad (Clarity)',
            value: state.glassClarity,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            fractionDigits: 2,
            onChanged: notifier.setGlassClarity,
            colors: colors,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: NanoSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Esmerilado (Frosted)',
                  style: NanoType.caption(colors.onSurfaceVariant),
                ),
                Text(
                  'Cristalino (Clear)',
                  style: NanoType.caption(colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: NanoSpacing.xs),
          _SliderRow(
            label: 'Opacidad del sustrato',
            value: state.glassOpacity,
            min: 0.10,
            max: 1.00,
            divisions: 18,
            fractionDigits: 2,
            onChanged: notifier.setGlassOpacity,
            colors: colors,
          ),
          _SliderRow(
            label: 'Desenfoque óptico (Blur)',
            value: state.glassBlur,
            min: 5.0,
            max: 35.0,
            divisions: 30,
            fractionDigits: 0,
            unit: 'px',
            onChanged: notifier.setGlassBlur,
            colors: colors,
          ),
          const SizedBox(height: NanoSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: NanoSpacing.md),
            child: Text(
              'Previsualización interactiva:',
              style: NanoType.caption(colors.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: NanoSpacing.xs),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              NanoSpacing.md,
              0,
              NanoSpacing.md,
              NanoSpacing.md,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 165,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF007AFF), // iOS Blue
                      Color(0xFF5856D6), // iOS Indigo
                      Color(0xFFFF2D55), // iOS Pink
                      Color(0xFFFF9500), // iOS Orange
                    ],
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 18,
                      left: 28,
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      right: 32,
                      child: Container(
                        width: 80,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.yellowAccent.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: NanoSpacing.md,
                        vertical: NanoSpacing.sm,
                      ),
                      child: GlassSurface(
                        opacity: state.glassOpacity,
                        clarity: state.glassClarity,
                        blur: state.glassBlur,
                        interactive: true,
                        radius: 18,
                        padding: const EdgeInsets.all(NanoSpacing.md),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.25),
                                  ),
                                  child: const Icon(
                                    Icons.touch_app_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: NanoSpacing.sm),
                                Text(
                                  'iOS GlassSurface Live',
                                  style: NanoType.subtitle(Colors.white),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Arrastra el dedo para probar el tilt 3D y el reflejo especular dinámico.',
                              style: NanoType.caption(
                                Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.black.withValues(alpha: 0.25),
                                  ),
                                  child: Text(
                                    'Opacidad: ${(state.glassOpacity * 100).toInt()}%',
                                    style: NanoType.caption(Colors.white),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.black.withValues(alpha: 0.25),
                                  ),
                                  child: Text(
                                    'Claridad: ${(state.glassClarity * 100).toInt()}%',
                                    style: NanoType.caption(Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
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
  Widget _voiceSection(
    SettingsState state,
    SettingsNotifier notifier,
    NanoColors colors,
  ) => _section(
    title: 'Voz',
    icon: Icons.record_voice_over_rounded,
    colors: colors,
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
                      ? 'Nano habla las respuestas tras un mensaje de voz.'
                      : 'Nano no hablará las respuestas (solo texto).',
                  style: NanoType.caption(colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: NanoSpacing.sm),
          Switch(
            value: state.voiceEnabled,
            onChanged: notifier.setVoiceEnabled,
            activeThumbColor: colors.primary,
            inactiveTrackColor: colors.outlineVariant.withValues(alpha: 0.3),
          ),
        ],
      ),
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
                colors.primary.withValues(alpha: 0.10),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AutomationSectionLabel('Escritorio Linux'),
        AutomationSurfaceCard(
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
      padding: const EdgeInsets.symmetric(
        horizontal: NanoSpacing.md,
        vertical: NanoSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: NanoType.body(colors.onSurface),
                  softWrap: true,
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
