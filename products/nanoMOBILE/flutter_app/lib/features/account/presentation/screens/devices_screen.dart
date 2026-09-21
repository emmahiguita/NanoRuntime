import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import '../../../../core/widgets/nano_components.dart';
import '../../application/account_providers.dart';

import '../../domain/device_entity.dart';

/// QUÉ HACE:
/// Pantalla de administración y auditoría de dispositivos vinculados.
///
/// CÓMO FUNCIONA:
/// Lista los dispositivos conectados, resalta el dispositivo actual y permite
/// renombrar o desvincular terminales remotas.
///
/// POR QUÉ:
/// Cumple la regla 22: control de sesiones y privacidad estricta sin usar IMEI.
class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NanoThemeExtension.of(context).colors;
    final state = ref.watch(deviceControllerProvider);
    final notifier = ref.read(deviceControllerProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Dispositivos', style: NanoType.headline(colors.onSurface)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(NanoSpacing.md),
              children: [
                Text(
                  'DISPOSITIVOS CONECTADOS',
                  style: NanoType.overline(colors.onSurfaceVariant),
                ),
                const SizedBox(height: NanoSpacing.sm),
                ...state.devices.map((device) => _buildDeviceTile(
                      context,
                      colors,
                      device,
                      notifier,
                    )),
              ],
            ),
    );
  }

  Widget _buildDeviceTile(
    BuildContext context,
    NanoColors colors,
    DeviceEntity device,
    dynamic notifier,
  ) {
    final icon = device.platform == 'android'
        ? Icons.phone_android_rounded
        : Icons.computer_rounded;

    return NanoOpticalSurface(
      borderRadius: NanoRadius.medium,
      margin: const EdgeInsets.only(bottom: NanoSpacing.sm),
      padding: const EdgeInsets.all(NanoSpacing.md),
      child: Row(
        children: [
          Icon(icon, color: colors.primary, size: 24),
          const SizedBox(width: NanoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        device.friendlyName,
                        style: NanoType.title(colors.onSurface),
                      ),
                    ),
                    if (device.isCurrentDevice)
                      const NanoBadge('Actual', kind: BadgeKind.success),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Visto: ${device.lastSeenAt.day}/${device.lastSeenAt.month}/${device.lastSeenAt.year}',
                  style: NanoType.caption(colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: colors.onSurfaceVariant),
            onSelected: (val) {
              if (val == 'rename') {
                _showRenameDialog(context, device, notifier);
              } else if (val == 'unlink') {
                notifier.unlinkDevice(device.deviceId);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'rename', child: Text('Renombrar')),
              if (!device.isCurrentDevice)
                const PopupMenuItem(
                  value: 'unlink',
                  child: Text('Desvincular', style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    DeviceEntity device,
    dynamic notifier,
  ) {
    final controller = TextEditingController(text: device.friendlyName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar dispositivo'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nombre del dispositivo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                notifier.renameDevice(device.deviceId, controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
