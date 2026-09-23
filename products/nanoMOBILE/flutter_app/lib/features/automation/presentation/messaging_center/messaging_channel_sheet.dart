/// MESSAGING-CHANNEL-SHEET — Gestión real de canales y permisos del sistema.
///
/// QUÉ HACE: activa las reglas existentes de WhatsApp y abre el permiso real.
/// CÓMO: reutiliza el registro de reglas y el executor nativo ya conectados.
/// POR QUÉ: evita controles decorativos o estados que no correspondan al móvil.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/automation_coordinator_provider.dart' show ruleRegistryProvider;
import '../../engine/messaging/messaging_package.dart';
import '../../executors/notification_executor_provider.dart';
import 'messaging_center_providers.dart';

Future<void> showMessagingChannelSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: const Color(0xFF0F172A),
    isScrollControlled: true,
    builder: (sheetContext) => Consumer(
      builder: (context, sheetRef, _) {
        final registry = sheetRef.watch(ruleRegistryProvider);
        final access = sheetRef.watch(notificationAccessProvider).valueOrNull;
        final hasAccess = access?.accessGranted == true;

        void setChannel(String packageName, bool enabled) {
          // Estas son las mismas reglas que consume el pipeline de producción.
          if (enabled) {
            registry.seedWhatsAppRule(packageName);
          } else {
            registry.removeWhatsAppRule(packageName);
          }
        }

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Canales y permisos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  Platform.isAndroid
                      ? 'Elige qué canales puede procesar NanoAI.'
                      : 'iOS no permite leer mensajes de otras apps mediante notificaciones.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
                if (Platform.isAndroid) ...[
                  const SizedBox(height: 12),
                  _ChannelSwitch(
                    title: 'WhatsApp',
                    subtitle: 'Mensajes personales',
                    value: registry.isWhatsAppRuleActive(MessagingPackage.whatsapp),
                    onChanged: (value) => setChannel(MessagingPackage.whatsapp, value),
                  ),
                  _ChannelSwitch(
                    title: 'WhatsApp Business',
                    subtitle: 'Mensajes de clientes',
                    value: registry.isWhatsAppRuleActive(MessagingPackage.whatsappBusiness),
                    onChanged: (value) =>
                        setChannel(MessagingPackage.whatsappBusiness, value),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        await ref.read(notificationExecutorProvider).requestAccess();
                        ref.invalidate(notificationAccessProvider);
                      },
                      icon: Icon(
                        hasAccess ? Icons.verified_user_rounded : Icons.security_rounded,
                      ),
                      label: Text(
                        hasAccess
                            ? 'Revisar permiso de notificaciones'
                            : 'Conceder permiso de notificaciones',
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Entendido'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _ChannelSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ChannelSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      value: value,
      onChanged: onChanged,
    );
  }
}
