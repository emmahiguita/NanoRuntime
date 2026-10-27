part of 'whatsapp_integration_cards.dart';

Widget _buildBackgroundAutomationSettings({
  required BuildContext context,
  required WidgetRef ref,
  required Map<dynamic, dynamic> status,
  required bool sawWhatsAppNotification,
  required bool remoteInputReady,
  required Future<void> Function() onRefresh,
  required Future<void> Function(bool enabled) onSetEnabled,
  required Future<void> Function() onOpenListenerSettings,
  required Future<void> Function() onOpenBatteryExemption,
}) {
  final settings = ref.watch(settingsProvider);
  final engine = ref.watch(runtimeEngineProvider);

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
    AutomationModelMode.sameAsChat =>
      settings.chatModelId.isNotEmpty
          ? settings.chatModelId
          : (selectedModelPath.isNotEmpty
                ? selectedModelPath.split(Platform.pathSeparator).last
                : ''),
    AutomationModelMode.specificModel =>
      settings.automationModelId.isNotEmpty
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
        icon: remoteInputReady ? Icons.reply_all_rounded : Icons.reply_outlined,
        title: '4. Respuesta RemoteInput',
        subtitle: remoteInputReady
            ? 'Android expone una acción de respuesta compatible'
            : sawWhatsAppNotification
            ? 'La notificación activa no permite respuesta directa'
            : 'Pendiente de observar una notificación de WhatsApp',
        trailing: ValueBadge(
          label: remoteInputReady
              ? 'LISTO'
              : sawWhatsAppNotification
              ? 'NO'
              : 'PENDIENTE',
        ),
        onTap: onRefresh,
        showChevron: false,
      ),
      SettingsRow(
        icon: enabled ? Icons.phonelink_erase : Icons.phone_android,
        title: 'Procesar en segundo plano',
        subtitle: enabled
            ? 'Responder con Nano cerrada y pantalla apagada'
            : 'Solo con Nano abierta',
        trailing: Switch(value: enabled, onChanged: onSetEnabled),
        showChevron: false,
      ),
      SettingsRow(
        icon: Icons.notifications_active_outlined,
        title: 'Acceso a notificaciones',
        subtitle: listenerGranted
            ? 'Concedido — Nano ve los mensajes entrantes'
            : 'Necesario para ver los mensajes entrantes',
        trailing: ValueBadge(label: listenerGranted ? 'SÍ' : 'FALTA'),
        onTap: onOpenListenerSettings,
        showChevron: false,
      ),
      SettingsRow(
        icon: Icons.battery_std,
        title: 'Exención de batería',
        subtitle: batteryIgnored
            ? 'Concedida — el sistema permite trabajar en segundo plano'
            : 'Android bloquea el arranque sin ella: toca para concederla',
        trailing: ValueBadge(label: batteryIgnored ? 'SÍ' : 'FALTA'),
        onTap: onOpenBatteryExemption,
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
