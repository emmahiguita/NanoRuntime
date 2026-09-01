import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/features/automation/domain/automation_policy.dart';
import 'package:nanoai/features/automation/engine/model/automation_model.dart';

import '../automation_visual_theme.dart';
import '../widgets/automation_bottom_navigation.dart';
import '../widgets/capability_status_card.dart';

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

    return Theme(
      data: AutomationVisual.theme(),
      child: Builder(
        builder: (context) => Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: AutomationVisual.canvas,
          bottomNavigationBar: keyboardOpen
              ? null
              : AutomationBottomNavigation(
                  onAutomationTap: () => Navigator.of(context).maybePop(),
                ),
          body: SafeArea(
            bottom: false,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
              children: [
                const _SettingsHeader(),
                const SizedBox(height: 28),
                const Text(
                  'Configuración',
                  style: TextStyle(
                    color: AutomationVisual.text,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Personaliza cómo Nano ejecuta tus automatizaciones.',
                  style: TextStyle(
                    color: AutomationVisual.textMuted,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                const AutomationSectionLabel('General'),
                _SettingsCard(
                  children: [
                    _SettingsRow(
                      icon: Icons.bolt_rounded,
                      title: 'Modo de automatización',
                      subtitle: settings.agentAutomationMode.label,
                      trailing: _ValueBadge(
                        label: settings.agentAutomationMode.label.toUpperCase(),
                      ),
                      onTap: () => _pickMode(context, ref),
                    ),
                    _SettingsRow(
                      icon: Icons.psychology_outlined,
                      title: 'Motor de razonamiento',
                      subtitle: _modelModeLabel(settings.automationModelMode),
                      onTap: () => _pickModelMode(context, ref, settings),
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
                const SizedBox(height: 28),
                const AutomationSectionLabel('Ejecución'),
                const _SettingsCard(
                  children: [
                    _SettingsRow(
                      icon: Icons.verified_user_outlined,
                      title: 'Acciones críticas protegidas',
                      subtitle: 'Confirmación y política activas',
                      trailing: _ReadonlyStatus(label: 'ACTIVO'),
                      showChevron: false,
                    ),
                    _SettingsRow(
                      icon: Icons.fact_check_outlined,
                      title: 'Verificación de resultados',
                      subtitle: 'Comprobar el estado después de actuar',
                      trailing: _ReadonlyStatus(label: 'ACTIVO'),
                      showChevron: false,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const AutomationSectionLabel('Seguridad y accesos'),
                const CapabilityStatusCard(),
                if (onDevTap != null) ...[
                  const SizedBox(height: 28),
                  const AutomationSectionLabel('Diagnóstico'),
                  _SettingsCard(
                    children: [
                      _SettingsRow(
                        icon: Icons.build_outlined,
                        title: 'Herramientas del agente',
                        subtitle: 'Percepción, selectores y estado técnico',
                        onTap: onDevTap,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 17,
                      color: AutomationVisual.textMuted,
                    ),
                    SizedBox(width: 7),
                    Text(
                      'Los cambios se guardan automáticamente',
                      style: TextStyle(
                        color: AutomationVisual.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
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
                        ? AutomationVisual.accent
                        : AutomationVisual.textMuted,
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
                        ? AutomationVisual.accent
                        : AutomationVisual.textMuted,
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

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 64,
    child: Row(
      children: [
        IconButton(
          tooltip: 'Atrás',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, size: 27),
        ),
        const Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CompactBrand(),
              SizedBox(height: 2),
              Text(
                'Automatización inteligente',
                style: TextStyle(
                  color: AutomationVisual.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 48),
      ],
    ),
  );
}

class _CompactBrand extends StatelessWidget {
  const _CompactBrand();

  @override
  Widget build(BuildContext context) => RichText(
    text: const TextSpan(
      style: TextStyle(
        fontFamily: 'Inter',
        color: AutomationVisual.text,
        fontSize: 23,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
      ),
      children: [
        TextSpan(text: 'NANO '),
        TextSpan(
          text: 'AI',
          style: TextStyle(color: AutomationVisual.accent),
        ),
      ],
    ),
  );
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
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AutomationVisual.accentSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AutomationVisual.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AutomationVisual.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AutomationVisual.textMuted,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ] else if (showChevron)
            const Icon(
              Icons.chevron_right_rounded,
              color: AutomationVisual.textMuted,
            ),
        ],
      ),
    ),
  );
}

class _ValueBadge extends StatelessWidget {
  const _ValueBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: AutomationVisual.accent),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: AutomationVisual.accent,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ReadonlyStatus extends StatelessWidget {
  const _ReadonlyStatus({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(
        Icons.check_circle_rounded,
        color: Color(0xFF24B47E),
        size: 17,
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(
          color: Color(0xFF19825E),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
