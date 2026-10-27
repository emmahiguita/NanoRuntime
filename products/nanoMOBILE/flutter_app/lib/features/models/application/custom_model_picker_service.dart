// custom_model_picker_service.dart — Selector e importador de modelos GGUF externos.
// QUÉ HACE: Abre el explorador de archivos nativo, valida cabecera GGUF y crea DetectedModel.
// CÓMO FUNCIONA: Lee los primeros 4 bytes (0x47, 0x47, 0x55, 0x46) sin cargar el archivo a RAM.
// POR QUÉ: Permite conectar cualquier modelo desde microSD/OTG con verificación de integridad zero-copy.
library;

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../domain/detected_model.dart';

class CustomModelPickerService {
  const CustomModelPickerService();

  /// Abre el selector de archivos del sistema y valida cabecera GGUF (0x47, 0x47, 0x55, 0x46).
  Future<DetectedModel?> pickModel() async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) return null;
    final pickedPath = result.files.single.path;
    if (pickedPath == null || pickedPath.isEmpty) return null;

    final file = File(pickedPath);
    if (!await file.exists()) {
      throw const FileSystemException('El archivo seleccionado no existe en disco.');
    }

    final len = await file.length();
    if (len < 24) {
      throw const FormatException('El archivo es demasiado pequeño para ser un modelo GGUF válido.');
    }

    // Valida cabecera GGUF (0x47, 0x47, 0x55, 0x46) de forma eficiente leyendo solo 4 bytes
    final headerBytes = await file.openRead(0, 4).first;
    final isGguf = headerBytes.length >= 4 &&
        headerBytes[0] == 0x47 &&
        headerBytes[1] == 0x47 &&
        headerBytes[2] == 0x55 &&
        headerBytes[3] == 0x46;

    if (!isGguf) {
      throw const FormatException('El archivo seleccionado no contiene una cabecera GGUF válida.');
    }

    final fileName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'modelo_externo.gguf';

    return DetectedModel(
      name: fileName,
      sizeBytes: len,
      uri: file.uri.toString(),
      format: DetectedModelFormat.gguf,
      magicOk: true,
      path: file.path,
    );
  }
}
