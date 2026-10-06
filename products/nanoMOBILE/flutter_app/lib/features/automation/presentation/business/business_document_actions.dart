import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../engine/business/business_document_library.dart';

/// Agrupa las acciones del sistema para compartir o borrar un PDF real.
final class BusinessDocumentActions {
  BusinessDocumentActions._();

  /// Abre el selector nativo; el usuario elige la app y confirma el destinatario.
  static Future<void> share({
    required BuildContext context,
    required BusinessDocument document,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              document.file.path,
              mimeType: 'application/pdf',
              name: document.name,
            ),
          ],
        ),
      );
    } on Object catch (error) {
      _showError(messenger, 'No se pudo compartir el PDF: $error');
    }
  }

  /// Confirma antes de borrar y actualiza la lista tras eliminar el archivo.
  static Future<void> delete({
    required BuildContext context,
    required BusinessDocumentLibrary library,
    required BusinessDocument document,
    required Future<void> Function() onDeleted,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar PDF'),
        content: Text('¿Eliminar «${document.name}»?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await library.delete(document);
      await onDeleted();
    } on Object catch (error) {
      _showError(messenger, 'No se pudo eliminar el PDF: $error');
    }
  }

  // Conserva un aviso entendible junto a la vista desde donde se actuó.
  static void _showError(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
