import 'package:flutter/material.dart';
import 'meta_inbox_shortcut.dart';
import 'whatsapp_web_feed_switch.dart';

/// Conserva los controles reales, pero no desplaza todos los chats en poca altura.
class MessagingConnectionControls extends StatelessWidget {
  const MessagingConnectionControls({super.key});

  @override
  Widget build(BuildContext context) {
    const controls = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        WhatsAppWebFeedSwitch(),
        SizedBox(height: 8),
        MetaInboxShortcut(),
      ],
    );
    // Usa altura disponible, no la etiqueta teléfono/tablet u orientación sola.
    if (MediaQuery.sizeOf(context).height >= 500) return controls;
    return const ExpansionTile(
      key: PageStorageKey('whatsapp-compact-connections'),
      title: Text('Conexiones WhatsApp'),
      leading: Icon(Icons.link_rounded),
      dense: true,
      tilePadding: EdgeInsets.symmetric(horizontal: 8),
      childrenPadding: EdgeInsets.only(bottom: 8),
      children: [controls],
    );
  }
}
