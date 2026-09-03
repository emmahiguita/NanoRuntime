/// EDGE-03 — Panel de mensajería: aplica a apps conocidas de mensajería
/// ([MessagingPackage.known], UNI-01). WhatsApp NO conoce este panel; este
/// panel conoce el paquete (OCP correcto).
///
/// Puro: deriva el contacto y las últimas notificaciones SOLO del
/// [NanoEdgeState] recibido. No consulta memoria, no ejecuta, no toca
/// canales.
library;

import 'package:nanoai/features/automation/engine/messaging/messaging_package.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_object.dart';

import '../nano_edge_state.dart';
import 'context_panel.dart';

final class MessagingContextPanel implements ContextPanel {
  const MessagingContextPanel();

  @override
  String get id => 'messaging';

  @override
  bool matches(String packageName) => isKnownMessagingPackage(packageName);

  @override
  NanoEdgeContent contentFor(NanoEdgeState state) {
    final snapshot = state.snapshot;
    final package = snapshot?.foregroundPackage ?? '';
    final appLabel = _appLabel(package);

    // Solo notificaciones del paquete en foreground: el panel habla de la
    // app que el usuario está viendo, no de otras.
    final mine = snapshot?.notifications
            .where((n) => n.packageName == package)
            .toList() ??
        const <NotificationObject>[];

    final contact = state.conversationContact ??
        (mine.isNotEmpty ? mine.first.sender : null);

    final lines = <String>[
      if (contact != null && contact.isNotEmpty) 'Contacto: $contact',
      for (final n in mine.take(3))
        [
          if (n.isGroup) 'Grupo',
          if (n.sender.isNotEmpty) n.sender,
          if (n.messageText.trim().isNotEmpty) n.messageText.trim(),
        ].join(' · '),
    ];
    return NanoEdgeContent(
      title: appLabel,
      body: lines.isEmpty
          ? 'Sin conversación activa observada.'
          : lines.join('\n'),
    );
  }

  static String _appLabel(String package) => switch (package) {
    MessagingPackage.whatsapp => 'WhatsApp',
    MessagingPackage.whatsappBusiness => 'WhatsApp Business',
    MessagingPackage.telegram || MessagingPackage.telegramOrg => 'Telegram',
    _ => package,
  };
}
