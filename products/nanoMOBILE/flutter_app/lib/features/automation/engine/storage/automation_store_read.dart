part of 'automation_db_store_client.dart';

/// Las lecturas que preceden a una escritura deben propagar errores. Confundir
/// un fallo del canal con un índice vacío podría sobrescribir datos existentes.
extension AutomationStoreRead on AutomationDbStoreClient {
  Future<String?> section(String key, {bool strict = false}) async {
    try {
      return await AutomationDbStoreClient._channel.invokeMethod<String>('get', {'key': key});
    } on Object catch (error) {
      if (strict) rethrow;
      debugPrint('[automation-store] get($key) falló: $error');
      return null;
    }
  }
}
