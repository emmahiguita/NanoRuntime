// nano_m3_drawer_tools_section.dart â€” SecciÃ³n de herramientas del Drawer estilo iOS.
// QUÃ‰ HACE: Agrupa los accesos a Chat, Navegador, WhatsApp, MCP y Escritorio.
// CÃ“MO FUNCIONA: Despliega Inset Grouped card limpia con NanoIosDrawerTile.
// POR QUÃ‰: DiseÃ±o minimalista estilo iOS sin textos largos innecesarios (< 110 lÃ­neas).
library;

import 'package:flutter/cupertino.dart';
import 'nano_ios_drawer_section.dart';
import 'nano_ios_drawer_tile.dart';

class NanoM3DrawerToolsSection extends StatelessWidget {
  const NanoM3DrawerToolsSection({
    super.key,
    required this.onOpenChat,
    required this.onOpenBrowser,
    required this.onOpenWhatsApp,
    required this.onOpenMcp,
    required this.onOpenDesktop,
  });

  final VoidCallback onOpenChat;
  final VoidCallback onOpenBrowser;
  final VoidCallback onOpenWhatsApp;
  final VoidCallback onOpenMcp;
  final VoidCallback onOpenDesktop;

  @override
  Widget build(BuildContext context) {
    return NanoIosDrawerSection(
      title: 'Herramientas',
      children: [
        NanoIosDrawerTile(
          icon: CupertinoIcons.chat_bubble_2_fill,
          iconColor: const Color(0xFF007AFF),
          title: 'Chat Multimodal',
          showDivider: true,
          onTap: onOpenChat,
        ),
        NanoIosDrawerTile(
          icon: CupertinoIcons.compass_fill,
          iconColor: const Color(0xFFFF9500),
          title: 'Navegador Web',
          showDivider: true,
          onTap: onOpenBrowser,
        ),
        NanoIosDrawerTile(
          icon: CupertinoIcons.bubble_left_bubble_right_fill,
          iconColor: const Color(0xFF34C759),
          title: 'WhatsApp y Mensajes',
          showDivider: true,
          onTap: onOpenWhatsApp,
        ),
        NanoIosDrawerTile(
          icon: CupertinoIcons.link,
          iconColor: const Color(0xFF5856D6),
          title: 'Skills MCP',
          showDivider: true,
          onTap: onOpenMcp,
        ),
        NanoIosDrawerTile(
          icon: CupertinoIcons.device_laptop,
          iconColor: const Color(0xFF1D4ED8),
          title: 'Escritorio Linux (VNC)',
          showDivider: false,
          onTap: onOpenDesktop,
        ),
      ],
    );
  }
}
