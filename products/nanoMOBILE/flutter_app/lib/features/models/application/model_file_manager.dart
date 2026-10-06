// model_file_manager.dart — Gestor de archivos físicos de modelos en disco y SD.
// QUÉ HACE: Realiza operaciones seguras de eliminación y verificación de existencia de archivos GGUF.
// CÓMO FUNCIONA: Verifica existencia en FileSystem antes de invocar .delete() con captura de excepciones.
// POR QUÉ: Aísla las operaciones I/O de disco para cumplir con Single Responsibility y < 200 líneas.
library;

import 'dart:io';
import 'package:flutter/foundation.dart';

class ModelFileManager {
  const ModelFileManager();

  /// Elimina de forma segura un archivo físico de modelo si existe en el almacenamiento.
  static Future<bool> deletePhysicalFile(String? path) async {
    if (path == null || path.isEmpty) return false;
    try {
      final directory = Directory(path);
      final file = File(path);
      var removedCompanion = false;

      // Limpia restos reanudables y el manifiesto de integridad junto al peso.
      for (final suffix in const [
        '.part',
        '.integrity.json',
        '.integrity.json.part',
      ]) {
        final companion = File('$path$suffix');
        if (await companion.exists()) {
          await companion.delete();
          removedCompanion = true;
        }
      }

      // MNN se guarda como paquete/directorio; GGUF y Whisper como archivo.
      if (await directory.exists()) {
        await directory.delete(recursive: true);
        return true;
      }
      if (await file.exists()) await file.delete();
      return removedCompanion || !await file.exists();
    } catch (e) {
      debugPrint('[models] Falló eliminación de archivo $path: $e');
    }
    return false;
  }
}
