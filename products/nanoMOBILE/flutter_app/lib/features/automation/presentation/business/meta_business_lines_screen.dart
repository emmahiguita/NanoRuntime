import 'package:flutter/material.dart';
import 'meta_inbox_screen.dart';

/// Las líneas son declaraciones del due?o: no implican registro o conexión Meta.
/// Cada entrada usa claves independientes y mantiene su ?mbito al abrir un chat.
class MetaBusinessLinesScreen extends StatelessWidget {
  const MetaBusinessLinesScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Líneas del negocio')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Conecta cada línea después de registrarla en Meta. '
            'Guardar una conexión no confirma su activaci?n.',
          ),
          const SizedBox(height: 16),
          for (final number in ['3203527283', '3225133665'])
            Card(
              child: ListTile(
                leading: const Icon(Icons.business_outlined),
                title: Text(number),
                subtitle: const Text('Ver bandeja y configurar conexión'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MetaInboxScreen(
                      lineId: 'line_$number',
                      lineLabel: number,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Conexi?n anterior'),
            subtitle: const Text(
              'Conserva la configuraci?n existente, si la hay.',
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const MetaInboxScreen()),
            ),
          ),
        ],
      ),
    ),
  );
}
