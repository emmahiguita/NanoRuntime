import 'package:flutter/material.dart';
import '../business/whatsapp_media_library.dart';

/// Un aviso sin URI no permite adivinar el archivo: ofrece biblioteca, no un visor falso.
class UnboundWhatsAppMediaCard extends StatelessWidget {
  final String label;
  final IconData icon;
  const UnboundWhatsAppMediaCard({
    super.key,
    required this.label,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () => WhatsAppMediaLibrary.show(context),
    icon: Icon(icon),
    label: Text('$label · archivo no vinculado\nAbrir biblioteca'),
  );
}
