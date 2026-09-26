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
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (e) {
      debugPrint('[models] Falló eliminación de archivo $path: $e');
    }
    return false;
  }
}
