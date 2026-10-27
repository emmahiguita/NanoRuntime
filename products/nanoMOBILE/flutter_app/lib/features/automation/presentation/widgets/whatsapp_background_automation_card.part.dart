part of 'whatsapp_integration_cards.dart';

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

    return _buildBackgroundAutomationSettings(
      context: context,
      ref: ref,
      status: status,
      sawWhatsAppNotification: _sawWhatsAppNotification,
      remoteInputReady: _remoteInputReady,
      onRefresh: _refresh,
      onSetEnabled: _setEnabled,
      onOpenListenerSettings: _openListenerSettings,
      onOpenBatteryExemption: _openBatteryExemption,
    );
  }
}
