/// PERSONA-PROFILE-05 — repositorio de perfiles (persona + relaciones).
///
/// Única vía Dart hacia las tablas `persona_profiles` y
/// `relationship_profiles` (SQLite v3). Los métodos viajan por el canal
/// tipado del AutomationStoreDb: Dart manda datos, Kotlin compone el SQL
/// (jamás texto SQL desde Dart).
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

import '../domain/persona_example.dart';
import '../domain/persona_profile.dart';
import '../domain/personal_memory.dart';

final class PersonaRepository {
  PersonaRepository._();

  static final PersonaRepository instance = PersonaRepository._();

  static const _channel = MethodChannel('com.nanoai/automation_store');

  /// Upsert del perfil de la persona (clave única, normalmente "owner").
  /// false = rechazado por el store (límites/whitelist).
  Future<bool> upsertPersona(
    String personaKey,
    String displayName,
    Map<String, String> facts,
  ) async {
    try {
      final rowId = await _channel.invokeMethod<num>('personaUpsert', {
        'personaKey': personaKey,
        'displayName': displayName,
        'factsJson': jsonEncode(facts),
      });
      return (rowId ?? -1) >= 0;
    } on Object catch (error) {
      debugPrint('[persona] upsertPersona falló: $error');
      return false;
    }
  }

  /// Todos los perfiles de persona (hoy: el del dueño).
  Future<List<PersonaProfile>> listPersonas() async {
    try {
      final rows = await _channel
          .invokeListMethod<dynamic>('personaList')
          .timeout(const Duration(seconds: 10));
      return [
        for (final row in rows ?? const [])
          if (row is Map) PersonaProfile.fromRow(row.cast<dynamic, dynamic>()),
      ];
    } on Object catch (error) {
      debugPrint('[persona] listPersonas falló: $error');
      rethrow;
    }
  }

  /// Upsert del perfil de relación (clave = remitente normalizado).
  Future<bool> upsertRelationship(
    String relationshipKey,
    String displayName,
    Map<String, String> facts,
  ) async {
    try {
      final rowId = await _channel.invokeMethod<num>('relationshipUpsert', {
        'relationshipKey': relationshipKey,
        'displayName': displayName,
        'factsJson': jsonEncode(facts),
      });
      return (rowId ?? -1) >= 0;
    } on Object catch (error) {
      debugPrint('[persona] upsertRelationship falló: $error');
      return false;
    }
  }

  Future<List<RelationshipProfile>> listRelationships() async {
    try {
      final rows = await _channel
          .invokeListMethod<dynamic>('relationshipList')
          .timeout(const Duration(seconds: 10));
      return [
        for (final row in rows ?? const [])
          if (row is Map)
            RelationshipProfile.fromRow(row.cast<dynamic, dynamic>()),
      ];
    } on Object catch (error) {
      debugPrint('[persona] listRelationships falló: $error');
      rethrow;
    }
  }

  Future<bool> deleteRelationship(String relationshipKey) async {
    try {
      return await _channel.invokeMethod<bool>('relationshipDelete', {
            'relationshipKey': relationshipKey,
          }) ??
          false;
    } on Object catch (error) {
      debugPrint('[persona] deleteRelationship falló: $error');
      return false;
    }
  }

  // ── PERSONA-DATASET-06 — ejemplos del estilo del dueño ───────────────

  /// Añade un ejemplo. [incomingText] no vacío lo convierte en PAR
  /// condicionado (R5-03): la respuesta [body] del dueño queda ligada a la
  /// entrada de cliente parecida. false = rechazado por el store (límites).
  Future<bool> addExample({
    required String personaKey,
    required String body,
    String incomingText = '',
    Map<String, String> tone = const {},
    String source = '',
  }) async {
    try {
      final rowId = await _channel.invokeMethod<num>('exampleAdd', {
        'personaKey': personaKey,
        'body': body,
        'incomingText': incomingText,
        'toneJson': jsonEncode(tone),
        'source': source,
      });
      return (rowId ?? -1) >= 0;
    } on Object catch (error) {
      debugPrint('[persona] addExample falló: $error');
      return false;
    }
  }

  /// Todos los ejemplos (más recientes primero).
  Future<List<PersonaExample>> listExamples({
    int limit = 200,
    int offset = 0,
    String? scopeKey,
  }) async {
    try {
      final rows = await _channel
          .invokeListMethod<dynamic>('exampleList', {
            'limit': limit,
            'offset': offset,
            if (scopeKey != null) 'scopeKey': scopeKey,
          })
          .timeout(const Duration(seconds: 10));
      return [
        for (final row in rows ?? const [])
          if (row is Map) PersonaExample.fromRow(row.cast<dynamic, dynamic>()),
      ];
    } on Object catch (error) {
      debugPrint('[persona] listExamples falló: $error');
      rethrow;
    }
  }

  Future<bool> deleteExample(int id) async {
    try {
      return await _channel.invokeMethod<bool>('exampleDelete', {'id': id}) ??
          false;
    } on Object catch (error) {
      debugPrint('[persona] deleteExample falló: $error');
      return false;
    }
  }

  // ── PERSONA-RETRIEVAL-07 — búsqueda FTS4 ──────────────────────────────

  /// Ejemplos parecidos al contexto (FTS4 MATCH; el SQL se compone en
  /// Kotlin). Devuelve vacío si la query no tiene términos buscables.
  Future<List<PersonaExample>> searchExamples(
    String query, {
    int limit = 4,
    String scopeKey = 'owner',
    String roleKey = 'role:personal',
  }) async {
    try {
      final rows = await _channel.invokeListMethod<dynamic>('exampleSearch', {
        'query': query,
        'limit': limit,
        'scopeKey': scopeKey,
        'roleKey': roleKey,
      });
      return [
        for (final row in rows ?? const [])
          if (row is Map) PersonaExample.fromRow(row.cast<dynamic, dynamic>()),
      ];
    } on Object catch (error) {
      debugPrint('[persona] searchExamples falló: $error');
      return const [];
    }
  }

  Future<Map<String, dynamic>> importPersonalization(
    Map<String, Object?> payload,
  ) async {
    final result = await _channel
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
      await _channel
          .invokeMapMethod<String, dynamic>('personalizationSummary')
          .timeout(const Duration(seconds: 10)) ??
      {};
  Future<int> deleteImportBatch(String batchId) async =>
      await _channel
          .invokeMethod<int>('personalizationDeleteBatch', {'batchId': batchId})
          .timeout(const Duration(seconds: 15)) ??
      0;
  Future<String?> importHistory(int id) => _channel
      .invokeMethod<String>('personalizationHistory', {'id': id})
      .timeout(const Duration(seconds: 10));
  Future<List<PersonalMemory>> listPersonalMemories({
    String? scopeKey,
    int limit = 100,
    int offset = 0,
  }) async {
    final rows = await _channel
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
    final id = await _channel
        .invokeMethod<num>('personalMemorySave', {
          'json': jsonEncode(memory.toJson()),
        })
        .timeout(const Duration(seconds: 10));
    if (id == null || id < 0) {
      throw StateError('No se pudo guardar la memoria.');
    }
  }

  Future<void> deletePersonalMemory(int id) async {
    if (await _channel
            .invokeMethod<bool>('personalMemoryDelete', {'id': id})
            .timeout(const Duration(seconds: 10)) !=
        true) {
      throw StateError('La memoria no se pudo eliminar.');
    }
  }

  Future<void> updateExample(
    PersonaExample example, {
    String? body,
    String? incomingText,
    Map<String, String>? tone,
    String? scopeKey,
  }) async {
    if (await _channel
            .invokeMethod<bool>('exampleUpdate', {
              'id': example.id,
              'body': body ?? example.body,
              'incomingText': incomingText ?? example.incomingText,
              'toneJson': jsonEncode(tone ?? example.tone),
              if (scopeKey != null) 'scopeKey': scopeKey,
            })
            .timeout(const Duration(seconds: 10)) !=
        true) {
      throw StateError('No se pudo actualizar el ejemplo.');
    }
  }

  Future<void> bindRelationshipScope(
    String oldKey,
    String newKey,
    String conversationId,
  ) async {
    if (await _channel
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
