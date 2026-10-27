part of 'nano_overlay_runtime.dart';

/// Presentación del selector existente desde el mismo engine. Requiere Activity
/// disponible; si Android no puede mostrarlo, devuelve fallo y no prepara un envío.
extension _NanoOverlayFiles on NanoOverlayRuntime {
  Future<Map<String, Object>> _pickFile(String source) async {
    final choice = switch (source) {
      'camera' => AutomationInputChoice.camera,
      'photos' => AutomationInputChoice.photos,
      'files' => AutomationInputChoice.files,
      _ => null,
    };
    if (choice == null) {
      return {'ok': false, 'text': 'Origen de archivo no válido.'};
    }
    if (!controller.beginFilePreparation()) {
      return {
        'ok': false,
        'state': 'busy',
        'text': 'Espera a que termine la petición actual.',
      };
    }
    try {
      final file = await AutomationAttachmentPicker.pick(choice);
      if (file == null) {
        return {
          'ok': false,
          'state': 'cancelled',
          'text': 'Selección cancelada; no se envió nada.',
        };
      }
      if (controller.isDisposed) {
        return {'ok': false, 'text': 'El asistente ya no está disponible.'};
      }
      controller.setAttachment(
        NanoPreparedAttachment(name: file.name, path: file.path),
      );
      final text =
          'Adjunto preparado: ${file.name}. Selecciona WhatsApp y escribe «Envía el adjunto a (contacto)».';
      controller.reportStatus(text);
      return {'ok': true, 'state': 'attachment_prepared', 'text': text};
    } on Object catch (error) {
      return {
        'ok': false,
        'state': 'failed',
        'text': error is FormatException
            ? error.message
            : 'Abre Nano para seleccionar el archivo; no se envió nada.',
      };
    } finally {
      controller.endFilePreparation();
    }
  }
}
