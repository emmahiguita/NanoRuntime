import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_transitions.dart';
import 'package:nanoai/features/automation/domain/automation_policy.dart';
import 'package:nanoai/features/automation/engine/model/automation_model.dart';

import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/core/widgets/navigation/nano_navigation_panel.dart';
import 'package:nanoai/features/automation/engine/business/business_facts.dart';
import 'package:nanoai/features/automation/engine/business/business_facts_providers.dart';
import 'package:nanoai/features/automation/engine/messaging/tone_profile.dart';
import 'package:nanoai/features/automation/engine/messaging/tone_profile_providers.dart';

import '../automation_layout.dart';
import '../automation_visual_theme.dart';
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
    final visualMode = AutomationVisual.modeFromSetting(settings.themeMode);

    return AnimatedTheme(
      data: AutomationVisual.theme(context, mode: visualMode),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: Builder(
        builder: (context) => Scaffold(
          // KEYBOARD-FIX-01: false — NanoShellBarScope usa Stack; si el
          // Scaffold encoge el body con el teclado, la barra salta.
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.transparent,
          body: NanoShellBarScope(
            slotId: 'automation_settings',
            // TOP-INSET-FIX-01 — SafeArea top propio: el header queda bajo
            // la barra de estado (patrón de messages/dev).
            child: SafeArea(
              top: true,
              bottom: false,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 48),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: AutomationLayout.contentMaxWidth(context),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const AutomationBackHeader(),
                          const SizedBox(height: 20),
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
                          const AutomationSectionLabel(
                            'Automatización en segundo plano',
                          ),
                          const _BackgroundAutomationCard(),
                          const SizedBox(height: 24), // UI-REV-02: gap Dev xl
                          const AutomationSectionLabel('Datos del negocio'),
                          const _BusinessDataCard(),
                          const SizedBox(height: 24), // UI-REV-02: gap Dev xl
                          const AutomationSectionLabel('Tono de respuesta'),
                          const _ToneCard(),
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

/// WA-PROD-01 — estado del runtime en segundo plano: puerta de usuario,
/// accesos reales (listener de notificaciones + exención de batería) y
/// mensajes pendientes en la cola durable. Solo presenta estados factuales
/// que consulta el runtime — ningún toggle decorativo.
class _BackgroundAutomationCard extends ConsumerStatefulWidget {
  const _BackgroundAutomationCard();

  @override
  ConsumerState<_BackgroundAutomationCard> createState() =>
      _BackgroundAutomationCardState();
}

class _BackgroundAutomationCardState
    extends ConsumerState<_BackgroundAutomationCard> {
  Map<dynamic, dynamic>? _status;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final status = await NanoRuntimeApi.instance.automationBackgroundStatus();
    if (mounted) setState(() => _status = status);
  }

  Future<void> _setEnabled(bool enabled) async {
    await NanoRuntimeApi.instance.setBackgroundAutomation(enabled);
    await _refresh();
  }

  Future<void> _openBatteryExemption() async {
    await NanoRuntimeApi.instance.requestBatteryExemption();
    // El diálogo del sistema tarda en reflejar el cambio al volver.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    await _refresh();
  }

  Future<void> _openListenerSettings() async {
    await NanoRuntimeApi.instance.requestNotificationAccess();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null) {
      return const _SettingsCard(
        children: [
          _SettingsRow(
            icon: Icons.hourglass_empty,
            title: 'Estado del runtime',
            subtitle: 'Consultando…',
            showChevron: false,
          ),
        ],
      );
    }

    final enabled = status['backgroundEnabled'] == true;
    final listenerGranted = status['listenerGranted'] == true;
    final batteryIgnored = status['batteryIgnored'] == true;
    final runtimeRunning = status['runtimeRunning'] == true;
    final pending = (status['pendingCount'] as num?)?.toInt() ?? 0;

    return _SettingsCard(
      children: [
        _SettingsRow(
          icon: enabled ? Icons.phonelink_erase : Icons.phone_android,
          title: 'Procesar en segundo plano',
          subtitle: enabled
              ? 'Responder con Nano cerrada y pantalla apagada'
              : 'Solo con Nano abierta',
          trailing: Switch(value: enabled, onChanged: _setEnabled),
          showChevron: false,
        ),
        _SettingsRow(
          icon: Icons.notifications_active_outlined,
          title: 'Acceso a notificaciones',
          subtitle: listenerGranted
              ? 'Concedido — Nano ve los mensajes entrantes'
              : 'Necesario para ver los mensajes entrantes',
          trailing: _ValueBadge(label: listenerGranted ? 'SÍ' : 'FALTA'),
          onTap: _openListenerSettings,
          showChevron: false,
        ),
        _SettingsRow(
          icon: Icons.battery_std,
          title: 'Exención de batería',
          subtitle: batteryIgnored
              ? 'Concedida — el sistema permite trabajar en segundo plano'
              : 'Android bloquea el arranque sin ella: toca para concederla',
          trailing: _ValueBadge(label: batteryIgnored ? 'SÍ' : 'FALTA'),
          onTap: _openBatteryExemption,
          showChevron: false,
        ),
        _SettingsRow(
          icon: Icons.inbox_outlined,
          title: runtimeRunning ? 'Procesando ahora' : 'En reposo',
          subtitle: pending == 0
              ? 'Sin mensajes pendientes'
              : 'Mensajes en cola: $pending',
          trailing: _ValueBadge(label: '$pending'),
          showChevron: false,
        ),
      ],
    );
  }
}

/// WA-BUSINESS-01 — datos reales del negocio que el agente puede afirmar:
/// productos (nombre, variante, precio, stock), horario y envío. Se guardan
/// en el store durable y viajan al prompt como bloque <DATOS DEL NEGOCIO>.
class _BusinessDataCard extends ConsumerWidget {
  const _BusinessDataCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facts = ref.watch(businessFactsNotifierProvider);
    final products = facts.products;
    return _SettingsCard(
      children: [
        _SettingsRow(
          icon: Icons.sell_outlined,
          title: 'Productos',
          subtitle: products.isEmpty
              ? 'Sin productos — el agente no afirmará precios ni stock'
              : '${products.length} producto${products.length == 1 ? '' : 's'} · '
                    'primero: ${products.first.name}',
          trailing: _ValueBadge(label: '${products.length}'),
          onTap: () => _openProductsSheet(context, ref),
        ),
        _SettingsRow(
          icon: Icons.schedule_rounded,
          title: 'Horario',
          subtitle: facts.hours.trim().isEmpty
              ? 'Sin definir — no lo afirmará'
              : facts.hours.trim(),
          onTap: () => _editText(
            context,
            ref,
            title: 'Horario del negocio',
            initial: facts.hours,
            onSave: (v) =>
                ref.read(businessFactsNotifierProvider.notifier).setHours(v),
          ),
        ),
        _SettingsRow(
          icon: Icons.local_shipping_outlined,
          title: 'Envío',
          subtitle: facts.delivery.trim().isEmpty
              ? 'Sin definir — no lo afirmará'
              : facts.delivery.trim(),
          onTap: () => _editText(
            context,
            ref,
            title: 'Envío',
            initial: facts.delivery,
            onSave: (v) =>
                ref.read(businessFactsNotifierProvider.notifier).setDelivery(v),
          ),
        ),
      ],
    );
  }

  void _openProductsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Productos del catálogo',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AutomationVisual.of(sheetContext).text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'El agente responde precios y stock SOLO de lo que está aquí.',
                style: TextStyle(
                  fontSize: 12,
                  color: AutomationVisual.of(sheetContext).textMuted,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: Consumer(
                  builder: (context, ref, _) {
                    final list = ref
                        .watch(businessFactsNotifierProvider)
                        .products;
                    if (list.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Sin productos todavía.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AutomationVisual.of(context).textMuted,
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final p = list[i];
                        final variant = p.details.trim();
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            variant.isEmpty ? p.name : '${p.name} ($variant)',
                            style: TextStyle(
                              color: AutomationVisual.of(context).text,
                            ),
                          ),
                          subtitle: Text(
                            '${p.priceLabel}'
                            '${p.stock == null ? ' · stock no informado' : ' · stock ${p.stock}'}',
                            style: TextStyle(
                              color: AutomationVisual.of(context).textMuted,
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: AutomationVisual.of(context).textMuted,
                            ),
                            tooltip: 'Quitar producto',
                            onPressed: () => ref
                                .read(businessFactsNotifierProvider.notifier)
                                .removeProduct(p.id),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _addProduct(sheetContext, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Agregar producto'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addProduct(BuildContext context, WidgetRef ref) async {
    final product = await showDialog<BusinessProduct>(
      context: context,
      builder: (_) => const _ProductDialog(),
    );
    if (product == null) return;
    await ref
        .read(businessFactsNotifierProvider.notifier)
        .upsertProduct(product);
  }

  Future<void> _editText(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String initial,
    required Future<void> Function(String) onSave,
  }) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _TextEditDialog(title: title, initial: initial),
    );
    if (value == null || value.trim().isEmpty) return;
    await onSave(value);
  }
}

/// WA-NATURAL-01 — perfil de tono de las respuestas automáticas. Controles
/// deterministas (sin texto libre): cada opción se traduce a frases fijas
/// del bloque <TONO DE RESPUESTA> que el borrador inyecta al prompt.
class _ToneCard extends ConsumerWidget {
  const _ToneCard();

  static const _warmthLabels = {
    ToneWarmth.cercano: 'Cercano',
    ToneWarmth.formal: 'Formal',
  };
  static const _verbosityLabels = {
    ToneVerbosity.breve: 'Breve',
    ToneVerbosity.media: 'Media',
    ToneVerbosity.extensa: 'Extensa',
  };
  static const _salesLabels = {
    ToneSales.natural: 'Natural',
    ToneSales.persuasivo: 'Persuasivo',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(toneProfileNotifierProvider);
    final notifier = ref.read(toneProfileNotifierProvider.notifier);
    return _SettingsCard(
      children: [
        _SettingsRow(
          icon: Icons.record_voice_over_outlined,
          title: 'Tono automático',
          subtitle: profile.enabled
              ? 'Activo — guía de forma en las respuestas'
              : 'Inactivo — respuestas como hasta ahora',
          trailing: Switch(
            value: profile.enabled,
            onChanged: (v) => notifier.update(profile.copyWith(enabled: v)),
          ),
          showChevron: false,
        ),
        if (profile.enabled) ...[
          _SettingsRow(
            icon: Icons.waving_hand_outlined,
            title: 'Trato',
            subtitle: 'Cómo se dirige al cliente',
            trailing: _ValueBadge(
              label: _warmthLabels[profile.warmth]!.toUpperCase(),
            ),
            onTap: () => notifier.update(
              profile.copyWith(
                warmth:
                    ToneWarmth.values[(profile.warmth.index + 1) %
                        ToneWarmth.values.length],
              ),
            ),
            showChevron: false,
          ),
          _SettingsRow(
            icon: Icons.format_size_rounded,
            title: 'Extensión',
            subtitle: 'Longitud típica de las respuestas',
            trailing: _ValueBadge(
              label: _verbosityLabels[profile.verbosity]!.toUpperCase(),
            ),
            onTap: () => notifier.update(
              profile.copyWith(
                verbosity:
                    ToneVerbosity.values[(profile.verbosity.index + 1) %
                        ToneVerbosity.values.length],
              ),
            ),
            showChevron: false,
          ),
          _SettingsRow(
            icon: Icons.emoji_emotions_outlined,
            title: 'Emojis',
            subtitle: profile.emojis ? 'Con moderación' : 'Sin emojis',
            trailing: Switch(
              value: profile.emojis,
              onChanged: (v) => notifier.update(profile.copyWith(emojis: v)),
            ),
            showChevron: false,
          ),
          _SettingsRow(
            icon: Icons.trending_up_rounded,
            title: 'Venta',
            subtitle: 'Presión comercial en las respuestas',
            trailing: _ValueBadge(
              label: _salesLabels[profile.sales]!.toUpperCase(),
            ),
            onTap: () => notifier.update(
              profile.copyWith(
                sales:
                    ToneSales.values[(profile.sales.index + 1) %
                        ToneSales.values.length],
              ),
            ),
            showChevron: false,
          ),
        ],
      ],
    );
  }
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog();

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final _name = TextEditingController();
  final _variant = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _variant.dispose();
    _price.dispose();
    _stock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return AlertDialog(
      backgroundColor: visual.surface,
      title: Text('Nuevo producto', style: TextStyle(color: visual.text)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nombre (ej. Galaxy S24)',
              ),
            ),
            TextField(
              controller: _variant,
              decoration: const InputDecoration(
                labelText: 'Variante (ej. negro 256GB) — opcional',
              ),
            ),
            TextField(
              controller: _price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Precio en pesos (ej. 899000)',
              ),
            ),
            TextField(
              controller: _stock,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Stock (número) — opcional',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: visual.textMuted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }

  void _save() {
    final name = _name.text.trim();
    final price = int.tryParse(_price.text.trim());
    if (name.isEmpty || price == null || price <= 0) {
      setState(() {
        _error = 'Nombre obligatorio y precio numérico mayor que cero.';
      });
      return;
    }
    final stock = int.tryParse(_stock.text.trim());
    Navigator.of(context).pop(
      BusinessProduct(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        details: _variant.text.trim(),
        price: price,
        stock: stock,
      ),
    );
  }
}

class _TextEditDialog extends StatefulWidget {
  const _TextEditDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_TextEditDialog> createState() => _TextEditDialogState();
}

class _TextEditDialogState extends State<_TextEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return AlertDialog(
      backgroundColor: visual.surface,
      title: Text(widget.title, style: TextStyle(color: visual.text)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        minLines: 1,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final v = _controller.text.trim();
            if (v.isEmpty) return;
            Navigator.of(context).pop(v);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
