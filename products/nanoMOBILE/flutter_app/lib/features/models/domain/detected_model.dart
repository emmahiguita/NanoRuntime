/// Formato de archivo de modelo detectado en el storage del device.
///
/// Solo [DetectedModelFormat.gguf] con magic válido es usable por el motor
/// nanortime. Safetensors y ONNX se listan pero sin acción (honesto).
enum DetectedModelFormat { gguf, safetensors, onnx }

/// Modelo encontrado por el escaneo SAF del storage — sin copias: el
/// archivo queda en su ubicación original y se usa vía fd del worker.
class DetectedModel {
  final String name;
  final int sizeBytes; // -1 cuando el provider no reporta tamaño
  final String uri; // content uri persistible del documento (SAF)
  final DetectedModelFormat format;
  final bool magicOk; // magic "GGUF" verificado en los primeros 4 bytes

  /// Path absoluto del filesystem (scanner con MANAGE_EXTERNAL_STORAGE).
  /// Null cuando el modelo vino del árbol SAF (se usa vía fd del worker).
  final String? path;

  const DetectedModel({
    required this.name,
    required this.sizeBytes,
    required this.uri,
    required this.format,
    required this.magicOk,
    this.path,
  });

  /// Usable por el motor solo si es GGUF con magic válido.
  bool get usable => format == DetectedModelFormat.gguf && magicOk;
}
