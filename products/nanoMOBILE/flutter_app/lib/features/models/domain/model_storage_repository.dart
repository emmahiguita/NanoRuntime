import 'package:nanoai/features/models/domain/detected_model.dart';

/// Frontera hacia el storage SAF del device (canal `com.nanoai/model_storage`).
///
/// La UI y el notifier dependen de esta interfaz, nunca del canal: inyectable
/// en tests con un fake.
abstract interface class ModelStorageRepository {
  /// Abre el selector de carpeta una vez y persiste el grant. Devuelve el
  /// uri elegido o null si el usuario cancela.
  Future<String?> pickTree();

  /// Uri persistido del árbol SAF, o null si nunca se concedió.
  Future<String?> persistedTree();

  /// Recorre el árbol concedido y devuelve los modelos detectados
  /// (.gguf/.safetensors/.onnx, GGUF con magic verificado). Lanza
  /// [StateError] si no hay árbol concedido.
  Future<List<DetectedModel>> scan();

  /// Abre el documento y transfiere el fd al worker :nanoshell. Devuelve el
  /// path `/proc/self/fd/N` legible por el engine, o null si falla.
  Future<String?> openFd(String uri);
}
