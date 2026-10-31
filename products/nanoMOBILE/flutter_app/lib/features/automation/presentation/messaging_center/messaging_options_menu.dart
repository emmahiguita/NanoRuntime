// messaging_options_menu.dart
// QUÉ HACE: Menú secundario flotante iOS para acciones complementarias del Centro de Mensajería.
// CÓMO FUNCIONA: Despliega PopupMenuButton estilizado con cristal iOS para Biblioteca, Web y Meta Cloud.
// POR QUÉ: Descongestiona la barra superior evitando sobrecarga de iconos (< 65 líneas).
library;

import 'package:flutter/material.dart';
import '../business/meta_inbox_screen.dart';
import '../whatsapp_web/whatsapp_web_screen.dart';
import 'messaging_glass_icon_button.dart';

class MessagingOptionsMenu extends StatelessWidget {
  const MessagingOptionsMenu({super.key, this.onOpenLibrary});

  final VoidCallback? onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopupMenuButton<String>(
      tooltip: 'Más opciones',
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? const Color(0xF21E293B) : const Color(0xF8FFFFFF),
      surfaceTintColor: Colors.transparent,
      onSelected: (value) => _handleAction(context, value),
      itemBuilder: (_) => [
        if (onOpenLibrary != null)
          _buildItem('library', Icons.folder_open_rounded, 'Biblioteca PDF'),
        _buildItem('web', Icons.public_rounded, 'WhatsApp Web'),
        _buildItem('meta_cloud', Icons.cloud_outlined, 'API Oficial Meta Cloud'),
      ],
      child: const AbsorbPointer(
        child: IosGlassIconButton(
          icon: Icons.more_vert_rounded,
          tooltip: 'Más opciones',
          onTap: _noOp,
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, String value) {
    switch (value) {
      case 'library':
        onOpenLibrary?.call();
      case 'web':
        WhatsAppWebScreen.navigateTo(context);
      case 'meta_cloud':
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const MetaInboxScreen()),
        );
    }
  }

  PopupMenuItem<String> _buildItem(String val, IconData icon, String text) {
    return PopupMenuItem(
      value: val,
      child: Row(
        children: [
          Icon(icon, size: 19),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontSize: 13.5)),
        ],
      ),
    );
  }
}

void _noOp() {}
