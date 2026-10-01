// QUÉ: solicita un enlace público de Google Sheets para importación real.
// CÓMO: valida mediante el servicio del controlador y conserva el diálogo si falla.
// POR QUÉ: hace explícito que esta vía es pública y de solo lectura.

import 'package:flutter/material.dart';
import '../../application/database_studio_controller.dart';

abstract final class DatabaseGoogleSheetDialog {
  static Future<void> show(
    BuildContext context,
    DatabaseStudioController controller,
  ) async {
    final input = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Importar Google Sheets'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pega un enlace público o compartido para lectura. Las hojas privadas requieren OAuth.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: input,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'https://docs.google.com/spreadsheets/...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final ok = await controller.importPublicGoogleSheet(input.text);
              if (ok && dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Importar'),
          ),
        ],
      ),
    );
    input.dispose();
  }
}
