import 'local_model.dart';

abstract interface class LocalModelRepository {
  /// Modelos del catálogo con estado de descarga REAL: comprueba el
  /// filesystem de la app (files/nano/models/) para decidir installed.
  Future<List<LocalModel>> listModels();
}
