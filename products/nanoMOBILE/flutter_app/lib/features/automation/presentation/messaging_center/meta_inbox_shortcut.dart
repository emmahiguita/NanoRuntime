import 'package:flutter/material.dart';
import '../business/meta_inbox_screen.dart';

/// Acceso explícito a Meta sin cambiar los switches ni automatizaciones personales existentes.
class MetaInboxShortcut extends StatelessWidget {
  const MetaInboxShortcut({super.key});
  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    leading: const Icon(Icons.cloud_outlined),
    title: const Text('Bandeja oficial de WhatsApp'),
    subtitle: const Text('Historial recibido por el servidor Nano'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const MetaInboxScreen())),
  );
}
