import 'package:flutter/material.dart';
import '../../domain/browser_tab_model.dart';

/// Explica el protocolo y dirección actuales sin inventar un certificado válido.
class BrowserConnectionDialog {
  const BrowserConnectionDialog._();

  static Future<void> show(BuildContext context, BrowserTabModel tab) {
    final scheme = Uri.tryParse(tab.url)?.scheme ?? '';
    final description = switch (scheme) {
      'https' =>
        'La dirección utiliza HTTPS. Este panel no inspecciona el certificado '
            'ni certifica la identidad del sitio. Comprueba el dominio antes de introducir datos personales.',
      'http' =>
        'La dirección utiliza HTTP, sin cifrado de transporte. '
            'Evita introducir contraseñas o datos personales.',
      _ => 'No hay información de certificado disponible para esta dirección.',
    };
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Información de conexión'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(tab.url),
            const SizedBox(height: 16),
            Text(description),
            if (tab.hasError) ...[
              const SizedBox(height: 12),
              const Text('La página reportó un error de carga.'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
