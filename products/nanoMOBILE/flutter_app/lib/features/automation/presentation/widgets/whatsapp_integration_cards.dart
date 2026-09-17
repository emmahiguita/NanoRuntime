import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/core/services/runtime_engine.dart';
import 'package:nanoai/features/automation/application/automation_coordinator_provider.dart'
    show ruleRegistryProvider;
import 'package:nanoai/features/automation/engine/messaging/messaging_package.dart';
import 'package:nanoai/features/automation/engine/model/automation_model.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_autonomy_mode.dart';
import '../automation_visual_theme.dart';
import 'automation_settings_pickers.dart';
import 'settings_tile_components.dart';

/// WA-BUSINESS-01 — Selector de aplicaciones de WhatsApp.
/// Crea/elimina la regla universal de WhatsApp y WhatsApp Business
/// por petición explícita del usuario (opt-in, WA-CONSENT-01).
class WhatsAppAppsCard extends ConsumerWidget {
  const WhatsAppAppsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(ruleRegistryProvider);

    bool isActive(String pkg) => registry.isWhatsAppRuleActive(pkg);

    void toggle(String pkg, bool value) {
      if (value) {
        registry.seedWhatsAppRule(pkg);
      } else {
        registry.removeWhatsAppRule(pkg);
      }
    }

    final isWaActive = isActive(MessagingPackage.whatsapp);
    final isW4bActive = isActive(MessagingPackage.whatsappBusiness);

    return SettingsCard(
      children: [
        SettingsRow(
          icon: Icons.chat_outlined,
          title: 'WhatsApp Personal',
          subtitle: isWaActive
              ? 'Activo — Nano procesa y responde mensajes'
              : 'Inactivo — no procesa mensajes',
          trailing: Switch(
            value: isWaActive,
            onChanged: (v) => toggle(MessagingPackage.whatsapp, v),
          ),
          showChevron: false,
        ),
        SettingsRow(
          icon: Icons.storefront_outlined,
          title: 'WhatsApp Business',
          subtitle: isW4bActive
              ? 'Activo — responde mensajes de clientes comerciales'
              : 'Inactivo — toca para activar',
          trailing: Switch(
            value: isW4bActive,
            onChanged: (v) => toggle(MessagingPackage.whatsappBusiness, v),
          ),
          showChevron: false,
        ),
      ],
    );
  }
}

/// WA-PROD-01 — estado del runtime en segundo plano: puerta de usuario,
/// accesos reales (listener de notificaciones + exención de batería) y
/// mensajes pendientes en la cola durable. Solo presenta estados factuales
/// que consulta el runtime — ningún toggle decorativo.
class BackgroundAutomationCard extends ConsumerStatefulWidget {
  const BackgroundAutomationCard({super.key});

  @override
  ConsumerState<BackgroundAutomationCard> createState() =>
      _BackgroundAutomationCardState();
}

class _BackgroundAutomationCardState
    extends ConsumerState<BackgroundAutomationCard> {
  Map<dynamic, dynamic>? _status;
  bool _sawWhatsAppNotification = false;
  bool _remoteInputReady = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final status = await NanoRuntimeApi.instance.automationBackgroundStatus();
    final active = await NanoRuntimeApi.instance.listActiveNotifications(
      limit: 100,
    );
    final whatsAppNotifications = active
        .whereType<Map>()
        .where((item) {
          final packageName = (item['package'] ?? item['packageName'])
              ?.toString();
          return packageName == MessagingPackage.whatsapp ||
              packageName == MessagingPackage.whatsappBusiness;
        })
        .toList(growable: false);
    if (mounted) {
      setState(() {
        _status = status;
        _sawWhatsAppNotification = whatsAppNotifications.isNotEmpty;
        _remoteInputReady = whatsAppNotifications.any(
          (item) => item['canReply'] == true,
        );
      });
    }
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
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final engine = ref.watch(runtimeEngineProvider);
    final status = _status;
    if (status == null) {
      return const SettingsCard(
        children: [
          SettingsRow(
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
    final selectedModelPath = switch (settings.automationModelMode) {
      AutomationModelMode.sameAsChat => settings.chatModelPath,
      AutomationModelMode.specificModel => settings.automationModelPath,
      AutomationModelMode.deterministicOnly => '',
    };
    final selectedModelName = switch (settings.automationModelMode) {
      AutomationModelMode.sameAsChat => settings.chatModelId.isNotEmpty
          ? settings.chatModelId
          : (selectedModelPath.isNotEmpty
              ? selectedModelPath.split(Platform.pathSeparator).last
              : ''),
      AutomationModelMode.specificModel => settings.automationModelId.isNotEmpty
          ? settings.automationModelId
          : (selectedModelPath.isNotEmpty
              ? selectedModelPath.split(Platform.pathSeparator).last
              : ''),
      AutomationModelMode.deterministicOnly => 'Determinista (0 LLM)',
    };
    final modelSelected =
        selectedModelPath.trim().isNotEmpty &&
        File(selectedModelPath).existsSync();
    final runtimeReady =
        engine.phase == EnginePhase.ready &&
        modelSelected &&
        engine.modelPath == selectedModelPath;
    final backgroundReady = enabled && listenerGranted && batteryIgnored;

    return SettingsCard(
      children: [
        SettingsRow(
          icon: modelSelected
              ? Icons.check_circle_outline_rounded
              : Icons.error_outline_rounded,
          title: '1. Modelo para responder',
          subtitle: modelSelected
              ? '$selectedModelName · Accesible para UI y segundo plano'
              : settings.automationModelMode ==
                    AutomationModelMode.deterministicOnly
              ? 'Modo determinista: no puede redactar respuestas nuevas'
              : 'Falta elegir un modelo GGUF instalado (toca para elegir)',
          trailing: ValueBadge(label: modelSelected ? 'LISTO' : 'FALTA'),
          onTap: () =>
              AutomationSettingsPickers.pickAutomationModelMode(context, ref),
          showChevron: true,
        ),
        SettingsRow(
          icon: runtimeReady ? Icons.memory_rounded : Icons.memory_outlined,
          title: '2. Motor local',
          subtitle: runtimeReady
              ? 'Modelo cargado y health check correcto'
              : modelSelected
              ? 'Aún no está cargado; se inicia al redactar'
              : 'Requiere un modelo válido antes de arrancar',
          trailing: ValueBadge(
            label: runtimeReady
                ? 'LISTO'
                : engine.phase == EnginePhase.starting
                ? 'INICIANDO'
                : 'EN ESPERA',
          ),
          showChevron: false,
        ),
        SettingsRow(
          icon: backgroundReady
              ? Icons.cloud_done_outlined
              : Icons.cloud_off_outlined,
          title: '3. Capacidad en segundo plano',
          subtitle: backgroundReady
              ? 'Runtime, listener y batería habilitados'
              : 'Activa runtime, notificaciones y exención de batería',
          trailing: ValueBadge(label: backgroundReady ? 'LISTO' : 'FALTA'),
          showChevron: false,
        ),
        SettingsRow(
          icon: _remoteInputReady
              ? Icons.reply_all_rounded
              : Icons.reply_outlined,
          title: '4. Respuesta RemoteInput',
          subtitle: _remoteInputReady
              ? 'Android expone una acción de respuesta compatible'
              : _sawWhatsAppNotification
              ? 'La notificación activa no permite respuesta directa'
              : 'Pendiente de observar una notificación de WhatsApp',
          trailing: ValueBadge(
            label: _remoteInputReady
                ? 'LISTO'
                : _sawWhatsAppNotification
                ? 'NO'
                : 'PENDIENTE',
          ),
          onTap: _refresh,
          showChevron: false,
        ),
        SettingsRow(
          icon: enabled ? Icons.phonelink_erase : Icons.phone_android,
          title: 'Procesar en segundo plano',
          subtitle: enabled
              ? 'Responder con Nano cerrada y pantalla apagada'
              : 'Solo con Nano abierta',
          trailing: Switch(value: enabled, onChanged: _setEnabled),
          showChevron: false,
        ),
        SettingsRow(
          icon: Icons.notifications_active_outlined,
          title: 'Acceso a notificaciones',
          subtitle: listenerGranted
              ? 'Concedido — Nano ve los mensajes entrantes'
              : 'Necesario para ver los mensajes entrantes',
          trailing: ValueBadge(label: listenerGranted ? 'SÍ' : 'FALTA'),
          onTap: _openListenerSettings,
          showChevron: false,
        ),
        SettingsRow(
          icon: Icons.battery_std,
          title: 'Exención de batería',
          subtitle: batteryIgnored
              ? 'Concedida — el sistema permite trabajar en segundo plano'
              : 'Android bloquea el arranque sin ella: toca para concederla',
          trailing: ValueBadge(label: batteryIgnored ? 'SÍ' : 'FALTA'),
          onTap: _openBatteryExemption,
          showChevron: false,
        ),
        SettingsRow(
          icon: Icons.inbox_outlined,
          title: runtimeRunning ? 'Procesando ahora' : 'En reposo',
          subtitle: pending == 0
              ? 'Sin mensajes pendientes'
              : 'Mensajes en cola: $pending',
          trailing: ValueBadge(label: '$pending'),
          showChevron: false,
        ),
      ],
    );
  }
}

/// AUTO-03 — modo de autonomía del pipeline de WhatsApp. El MISMO motor de
/// decisión (ConversationDecisionEngine) aplica el modo como tope ANTES de su
/// fórmula: no hay segundo motor ni reglas nuevas.
/// AUTONOMY FAIL-SAFE (PROD-02): `waAutonomyMode == null` = el dueño aún no
/// elige. La card lo dice honesto (sin pretender que hay selección) y el
/// pipeline opera en safeAuto hasta que el dueño elija en este picker.
class AutonomyModeCard extends ConsumerWidget {
  const AutonomyModeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final raw = ref.watch(settingsProvider).waAutonomyMode;
    final mode = ConversationAutonomyModeName.fromName(raw);
    return SettingsCard(
      children: [
        SettingsRow(
          icon: Icons.auto_awesome_outlined,
          title: 'Autonomía de respuestas',
          subtitle: raw == null
              ? 'No has elegido aún — Nano solo responde lo seguro.'
              : mode.description,
          trailing: ValueBadge(label: mode.label.toUpperCase()),
          onTap: () => _pickAutonomyMode(context, ref),
        ),
      ],
    );
  }

  static Future<void> _pickAutonomyMode(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final rawSelected = ref.read(settingsProvider).waAutonomyMode;
    final selected = rawSelected == null
        ? null
        : ConversationAutonomyModeName.fromName(rawSelected);
    final value = await showModalBottomSheet<ConversationAutonomyMode>(
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
                'Autonomía de respuestas',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              for (final mode in ConversationAutonomyMode.values)
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
      ref.read(settingsProvider.notifier).setWaAutonomyMode(value.name);
    }
  }
}
