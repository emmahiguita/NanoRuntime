import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../../chat/domain/camera_capture_backend.dart';
import '../../engine/platform/whatsapp_media_share.dart';
import 'automation_input_attachment.dart';
import 'automation_input_menu.dart';

/// Reutiliza cámara Android, selector del sistema y catálogo privado existentes.
/// No lee binarios en memoria, no selecciona componentes y nunca envía archivos.
abstract final class AutomationAttachmentPicker {
  /// Una elección abre exactamente un proveedor y devuelve una copia estable.
  /// Cancelar no cambia el adjunto anterior ni el componente seleccionado.
  static Future<AutomationInputAttachment?> pick(
    AutomationInputChoice source,
  ) async {
    final String path, name;
    if (source == AutomationInputChoice.camera) {
      final photo = await const AndroidCameraCaptureBackend().capturePhoto();
      if (photo == null) return null;
      path = photo.path;
      name = photo.name;
    } else {
      if (source == AutomationInputChoice.whatsapp) return null;
      final result = await FilePicker.pickFiles(
        type: source == AutomationInputChoice.photos
            ? FileType.image
            : FileType.any,
        allowMultiple: false,
        withData: false,
      );
      final file = result?.files.single;
      if (file?.path == null) return null;
      path = file!.path!;
      name = file.name;
    }
    final selected = File(path);
    if (!await selected.exists() || await selected.length() == 0) {
      throw const FormatException(
        'El archivo no está disponible o está vacío.',
      );
    }
    final stable = await const WhatsAppMediaShare().copyToCatalog(
      path,
      category: NanoMediaCategory.forFileName(name),
    );
    if (stable == null) {
      throw const FormatException('No se pudo preparar el adjunto.');
    }
    // Solo la captura temporal propia se elimina después de copiarla al catálogo.
    if (source == AutomationInputChoice.camera && stable != path) {
      try {
        await selected.delete();
      } on FileSystemException {
        // La copia está a salvo; el sistema administra la captura temporal.
      }
    }
    return AutomationInputAttachment(name: name, path: stable);
  }
}
