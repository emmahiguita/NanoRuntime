// model_delete_confirmation.dart — Confirmación única para borrar modelos descargados.
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// Explica qué archivos se borrarán y muestra si la operación física terminó.
Future<void> confirmModelDeletion({
  required BuildContext context,
  required String modelName,
  required String fileName,
  required Future<bool> Function() delete,
}) async {
  // Confirmación iOS: cancelar es la opción segura y borrar exige aceptación.
  // La operación física existente se ejecuta solo después de cerrar el diálogo.
  final confirmed = await showCupertinoDialog<bool>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: const Text('Eliminar modelo descargado'),
      content: Text(
        '$modelName\n\nSe quitarán el archivo “$fileName”, su verificación y cualquier descarga incompleta. Si está en uso, Nano intentará detenerlo antes de borrarlo.',
      ),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancelar'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final deleted = await delete();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        deleted
            ? 'Modelo eliminado del dispositivo.'
            : 'Nano no pudo detener el motor o eliminar los archivos.',
      ),
    ),
  );
}
