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

  /// Recorre TODO el storage compartido (/storage/emulated/0) con
  /// MANAGE_EXTERNAL_STORAGE y devuelve los modelos detectados con su path
  /// absoluto. Lanza [StateError] si el permiso no está concedido.
  Future<List<DetectedModel>> scanAll();

  /// true si la app tiene acceso a todos los archivos (API 30+; en
  /// versiones anteriores el storage compartido siempre es legible).
  Future<bool> hasAllFilesAccess();

  /// Abre la pantalla del sistema para conceder MANAGE_EXTERNAL_STORAGE.
  /// Devuelve true si quedó concedido al volver a la app.
  Future<bool> requestAllFilesAccess();
}
