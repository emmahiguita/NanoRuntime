// persona_repository_memories.dart
//
// QUÉ HACE:
// Operaciones de persistencia para memorias personales (episódicas, preferencias de estilo)
// e historial de importaciones batch del Agente Personal.
//
// CÓMO FUNCIONA:
// - Se comunica mediante canal tipado con Kotlin hacia la base de datos SQLite v3 (`AutomationStoreDb`).
// - Serializa y deserializa listas de PersonalMemory con timeouts acotados (10s).
// - Maneja importación de lotes JSON con validación y borrado de lotes (`deleteImportBatch`).
//
// POR QUÉ:
// Mantiene el tamaño de archivos estrictamente menor a 200 líneas cumpliendo el principio de Responsabilidad Única (SRP).

part of 'persona_repository.dart';

extension PersonaRepositoryMemories on PersonaRepository {
  Future<Map<String, dynamic>> importPersonalization(
    Map<String, Object?> payload,
  ) async {
    final result = await PersonaRepository._channel
        .invokeMapMethod<String, dynamic>('personalizationImport', {
          'json': jsonEncode(payload),
        })
        .timeout(const Duration(seconds: 30));
    if (result == null) {
      throw StateError('La importación no devolvió resultado.');
    }
    return result;
  }

  Future<Map<String, dynamic>> personalizationSummary() async =>
      await PersonaRepository._channel
          .invokeMapMethod<String, dynamic>('personalizationSummary')
          .timeout(const Duration(seconds: 10)) ??
      {};

  Future<int> deleteImportBatch(String batchId) async =>
      await PersonaRepository._channel
          .invokeMethod<int>('personalizationDeleteBatch', {'batchId': batchId})
          .timeout(const Duration(seconds: 15)) ??
      0;

  Future<String?> importHistory(int id) => PersonaRepository._channel
      .invokeMethod<String>('personalizationHistory', {'id': id})
      .timeout(const Duration(seconds: 10));

  Future<List<PersonalMemory>> listPersonalMemories({
    String? scopeKey,
    int limit = 100,
    int offset = 0,
  }) async {
    final rows = await PersonaRepository._channel
        .invokeListMethod<dynamic>('personalMemoryList', {
          if (scopeKey != null) 'scopeKey': scopeKey,
          'limit': limit,
          'offset': offset,
        })
        .timeout(const Duration(seconds: 10));
    return [
      for (final row in rows ?? const [])
        if (row is Map) PersonalMemory.fromRow(row),
    ];
  }

  Future<void> savePersonalMemory(PersonalMemory memory) async {
    final id = await PersonaRepository._channel
        .invokeMethod<num>('personalMemorySave', {
          'json': jsonEncode(memory.toJson()),
        })
        .timeout(const Duration(seconds: 10));
    if (id == null || id < 0) {
      throw StateError('No se pudo guardar la memoria.');
    }
  }

  Future<void> deletePersonalMemory(int id) async {
    if (await PersonaRepository._channel
            .invokeMethod<bool>('personalMemoryDelete', {'id': id})
            .timeout(const Duration(seconds: 10)) !=
        true) {
      throw StateError('La memoria no se pudo eliminar.');
    }
  }

  Future<void> bindRelationshipScope(
    String oldKey,
    String newKey,
    String conversationId,
  ) async {
    if (await PersonaRepository._channel
            .invokeMethod<bool>('relationshipBindScope', {
              'oldKey': oldKey,
              'newKey': newKey,
              'conversationId': conversationId,
            })
            .timeout(const Duration(seconds: 15)) !=
        true) {
      throw StateError('No se pudo vincular la conversación.');
    }
  }
}
