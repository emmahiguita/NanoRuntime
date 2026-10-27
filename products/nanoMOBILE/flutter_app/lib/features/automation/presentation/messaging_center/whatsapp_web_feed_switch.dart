/// Interruptor compacto para incorporar resúmenes reales de WhatsApp Web al hub.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/whatsapp_media_payload.dart';
import '../whatsapp_web/whatsapp_web_screen.dart';
import 'messaging_center_providers.dart';

class WhatsAppWebFeedSwitch extends ConsumerWidget {
  const WhatsAppWebFeedSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabledAsync = ref.watch(whatsappWebFeedEnabledProvider);
    final session = ref.watch(whatsappWebSessionProvider).valueOrNull;
    final conversations = ref
        .watch(whatsappWebConversationsProvider)
        .valueOrNull;
    final enabled = enabledAsync.valueOrNull ?? false;
    final connected = session?.status == WhatsAppWebSessionStatus.connected;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final subtitle = switch ((enabled, session?.status)) {
      (false, _) => 'Actívalo para ver los chats web en este panel',
      (true, WhatsAppWebSessionStatus.connected) =>
        '${conversations?.length ?? 0} chats observados',
      (true, WhatsAppWebSessionStatus.waitingForQr) =>
        'Abre WhatsApp Web y vincula el dispositivo',
      (true, WhatsAppWebSessionStatus.syncing) => 'Sincronizando WhatsApp Web…',
      _ => 'Restaurando la sesión vinculada…',
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.055)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: connected && enabled
              ? const Color(0xFF22C55E).withValues(alpha: 0.45)
              : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 11, right: 4, top: 5, bottom: 5),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.public_rounded,
                size: 18,
                color: Color(0xFF16A34A),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WhatsApp Web',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: connected
                  ? 'Abrir WhatsApp Web'
                  : 'Vincular WhatsApp Web',
              onPressed: () => WhatsAppWebScreen.navigateTo(context),
              icon: Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: isDark ? Colors.white60 : const Color(0xFF475569),
              ),
            ),
            Semantics(
              label: 'Mostrar conversaciones de WhatsApp Web en Mensajes',
              child: Switch.adaptive(
                value: enabled,
                onChanged: enabledAsync.isLoading
                    ? null
                    : (value) async {
                        try {
                          await ref
                              .read(whatsappWebFeedEnabledProvider.notifier)
                              .setEnabled(value);
                          // Mensajería restaura el host; solo el botón Web abre
                          // la vinculación cuando realmente se necesita un QR.
                        } catch (_) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'No se pudo guardar la conexión de WhatsApp Web.',
                              ),
                            ),
                          );
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
