import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_transitions.dart';
import 'package:nanoai/features/automation/domain/automation_policy.dart';
import 'package:nanoai/features/automation/engine/model/automation_model.dart';

import '../automation_visual_theme.dart';
import '../widgets/automation_bottom_navigation.dart';
import '../widgets/capability_status_card.dart';
import 'automation_rules_screen.dart';

/// Configuración del agente basada exclusivamente en estados persistidos y
/// capacidades reales. No presenta toggles que el runtime no consuma.
class AutomationSettingsScreen extends ConsumerWidget {
  const AutomationSettingsScreen({super.key, this.onDevTap});

  final VoidCallback? onDevTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final visualMode = AutomationVisual.modeFromSetting(settings.themeMode);

    return AnimatedTheme(
      data: AutomationVisual.theme(context, mode: visualMode),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: Builder(
        builder: (context) => Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: AutomationVisual.of(context).canvas,
          body: SafeArea(
            child: AutomationNavigationFrame(
              hidden: keyboardOpen,
              onAutomationTap: () => Navigator.of(context).maybePop(),
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 48),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720), // UI-REV-02: ancho Dev
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const AutomationBackHeader(),
                          const SizedBox(height: 20),
                          // UI-REV-02: título 22px — jerarquía Dev.
                          Text(
                            'Configuración',
                            style: TextStyle(
                              color: AutomationVisual.of(context).text,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Personaliza cómo Nano ejecuta tus automatizaciones.',
                            style: TextStyle(
                              color: AutomationVisual.of(context).textMuted,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const AutomationSectionLabel('General'),
                          _SettingsCard(
                            children: [
                              _SettingsRow(
                                icon: Icons.bolt_rounded,
                                title: 'Modo de automatización',
                                subtitle:
                                    settings.agentAutomationMode.description,
                                trailing: _ValueBadge(
                                  label: settings.agentAutomationMode.label
                                      .toUpperCase(),
                                ),
                                onTap: () => _pickMode(context, ref),
                              ),
                              _SettingsRow(
                                icon: Icons.psychology_outlined,
                                title: 'Motor de razonamiento',
                                subtitle: _modelModeLabel(
                                  settings.automationModelMode,
                                ),
                                onTap: () =>
                                    _pickModelMode(context, ref, settings),
                              ),
                              _SettingsRow(
                                icon: settings.voiceEnabled
                                    ? Icons.volume_up_outlined
                                    : Icons.volume_off_outlined,
                                title: 'Audio de Nano',
                                subtitle: settings.voiceEnabled
                                    ? 'Leer respuestas y resultados en voz alta'
                                    : 'Responder únicamente con texto',
                                trailing: Switch(
                                  value: settings.voiceEnabled,
                                  onChanged: notifier.setVoiceEnabled,
                                ),
                                showChevron: false,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24), // UI-REV-02: gap Dev xl
                          const AutomationSectionLabel('Reglas'),
                          _SettingsCard(
                            children: [
                              _SettingsRow(
                                icon: Icons.rule_rounded,
                                title: 'Reglas de automatización',
                                subtitle:
                                    'Activar, desactivar o borrar respuestas '
                                    'automáticas',
                                onTap: () => Navigator.of(context).push(
                                  nanoGlassPageRoute<void>(
                                    builder: (_) =>
                                        const AutomationRulesScreen(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24), // UI-REV-02: gap Dev xl
                          const AutomationSectionLabel('Ejecución'),
                          const _SettingsCard(
                            children: [
                              _SettingsRow(
                                icon: Icons.verified_user_outlined,
                                title: 'Acciones críticas protegidas',
                                subtitle: 'Confirmación y política activas',
                                trailing: _ReadonlyStatus(),
                                showChevron: false,
                              ),
                              _SettingsRow(
                                icon: Icons.fact_check_outlined,
                                title: 'Verificación de resultados',
                                subtitle:
                                    'Comprobar el estado después de actuar',
                                trailing: _ReadonlyStatus(),
                                showChevron: false,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24), // UI-REV-02: gap Dev xl
                          const AutomationSectionLabel('Seguridad y accesos'),
                          const CapabilityStatusCard(),
                          if (onDevTap != null) ...[
                            const SizedBox(height: 24), // UI-REV-02: gap Dev xl
                            const AutomationSectionLabel('Diagnóstico'),
                            _SettingsCard(
                              children: [
                                _SettingsRow(
                                  icon: Icons.smart_toy_outlined,
                                  title: 'Herramientas del agente',
                                  subtitle:
                                      'Percepción, selectores y estado técnico',
                                  onTap: onDevTap,
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 17,
                                color: AutomationVisual.of(context).textMuted,
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  'Los cambios se guardan automáticamente',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AutomationVisual.of(
                                      context,
                                    ).textMuted,
                                    fontSize: 12,
                                  ),
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
      ),
    );
  }

  static Future<void> _pickMode(BuildContext context, WidgetRef ref) async {
    final selected = ref.read(settingsProvider).agentAutomationMode;
    final value = await showModalBottomSheet<AgentAutomationMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Modo de automatización',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              for (final mode in AgentAutomationMode.values)
                ListTile(
                  leading: Icon(
                    mode == selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: mode == selected
                        ? AutomationVisual.of(context).accent
                        : AutomationVisual.of(context).textMuted,
                  ),
                  title: Text(mode.label),
                  subtitle: Text(mode.description),
                  onTap: () => Navigator.of(context).pop(mode),
                ),
            ],
          ),
        ),
      ),
    );
    if (value != null) {
      ref.read(settingsProvider.notifier).setAgentAutomationMode(value);
    }
  }

  static Future<void> _pickModelMode(
    BuildContext context,
    WidgetRef ref,
    SettingsState settings,
  ) async {
    final options = <AutomationModelMode>[
      AutomationModelMode.sameAsChat,
      if (settings.automationModelPath.trim().isNotEmpty)
        AutomationModelMode.specificModel,
      AutomationModelMode.deterministicOnly,
    ];
    final value = await showModalBottomSheet<AutomationModelMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Motor de razonamiento',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              for (final option in options)
                ListTile(
                  leading: Icon(
                    option == settings.automationModelMode
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: option == settings.automationModelMode
                        ? AutomationVisual.of(context).accent
                        : AutomationVisual.of(context).textMuted,
                  ),
                  title: Text(_modelModeLabel(option)),
                  subtitle: Text(_modelModeDescription(option)),
                  onTap: () => Navigator.of(context).pop(option),
                ),
              if (settings.automationModelPath.trim().isEmpty)
                ListTile(
                  leading: const Icon(Icons.add_circle_outline_rounded),
                  title: const Text('Elegir un modelo específico'),
                  subtitle: const Text(
                    'Abre Modelos para descargar o seleccionar uno.',
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    context.go('/models');
                  },
                ),
            ],
          ),
        ),
      ),
    );
    if (value != null) {
      ref.read(settingsProvider.notifier).setAutomationModelMode(value);
    }
  }

  static String _modelModeLabel(AutomationModelMode mode) => switch (mode) {
    AutomationModelMode.sameAsChat => 'Mismo modelo que Chat',
    AutomationModelMode.specificModel => 'Modelo específico',
    AutomationModelMode.deterministicOnly => 'Solo lógica determinista',
  };

  static String _modelModeDescription(
    AutomationModelMode mode,
  ) => switch (mode) {
    AutomationModelMode.sameAsChat =>
      'Comparte el modelo local actualmente seleccionado en Chat.',
    AutomationModelMode.specificModel =>
      'Usa el modelo configurado exclusivamente para Automatización.',
    AutomationModelMode.deterministicOnly =>
      'No invoca un modelo; ejecuta únicamente rutas verificables conocidas.',
  };
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AutomationSurfaceCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index != children.length - 1)
            const Divider(height: 1, indent: 74),
        ],
      ],
    ),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 330 && trailing != null;
        return InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: visual.accentSoft,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: visual.accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              softWrap: true,
                              style: TextStyle(
                                color: visual.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (!compact && trailing != null) ...[
                            const SizedBox(width: 10),
                            trailing!,
                          ] else if (showChevron)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                color: visual.textMuted,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        softWrap: true,
                        style: TextStyle(
                          color: visual.textMuted,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      if (compact && trailing != null) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: trailing,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ValueBadge extends StatelessWidget {
  const _ValueBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: AutomationVisual.of(context).accent),
    ),
    child: Text(
      label,
      style: TextStyle(
        // El acento vivo (#FF7A00 sobre blanco ≈ 2.9:1) no pasa AA como color
        // de fuente en 10px: usar su variante oscura legible, no el acento.
        color: NanoTextColors.forText(
          AutomationVisual.of(context).accent,
          NanoThemeExtension.of(context).colors,
        ),
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ReadonlyStatus extends StatelessWidget {
  const _ReadonlyStatus();

  @override
  Widget build(BuildContext context) {
    final success = AutomationVisual.of(context).success;
    return Semantics(
      label: 'Activo',
      child: Tooltip(
        message: 'Activo',
        child: Icon(Icons.check_circle_rounded, color: success, size: 18),
      ),
    );
  }
}
