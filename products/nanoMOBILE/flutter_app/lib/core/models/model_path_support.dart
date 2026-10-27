import 'dart:io';

import 'catalog_models.dart';

/// Valida que la ruta exista con la forma que consume su motor declarado.
bool isRunnableModelPath(String? path) {
  // Una ruta vacía nunca puede representar un modelo cargable.
  if (path == null || path.trim().isEmpty) return false;
  final candidate = path.trim();
  if (NeuralCatalog.backendForPath(candidate) != ModelBackendType.mnn) {
    return File(candidate).existsSync();
  }

  // MNN usa un paquete; la carpeta debe contener la configuración que abre JNI.
  if (File(candidate).existsSync()) return true;
  return Directory(candidate).existsSync() &&
      File('$candidate${Platform.pathSeparator}llm_config.json').existsSync();
}
