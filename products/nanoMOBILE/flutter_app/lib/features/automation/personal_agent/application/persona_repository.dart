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
      final rows = await _channel.invokeListMethod<dynamic>('personaList');
      return [
        for (final row in rows ?? const [])
          if (row is Map) PersonaProfile.fromRow(row.cast<dynamic, dynamic>()),
      ];
    } on Object catch (error) {
      debugPrint('[persona] listPersonas falló: $error');
      return const [];
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
      final rows = await _channel.invokeListMethod<dynamic>('relationshipList');
      return [
        for (final row in rows ?? const [])
          if (row is Map)
            RelationshipProfile.fromRow(row.cast<dynamic, dynamic>()),
      ];
    } on Object catch (error) {
      debugPrint('[persona] listRelationships falló: $error');
      return const [];
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

  /// Añade un ejemplo. false = rechazado por el store (límites).
  Future<bool> addExample({
    required String personaKey,
    required String body,
    Map<String, String> tone = const {},
    String source = '',
  }) async {
    try {
      final rowId = await _channel.invokeMethod<num>('exampleAdd', {
        'personaKey': personaKey,
        'body': body,
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
  Future<List<PersonaExample>> listExamples() async {
    try {
      final rows = await _channel.invokeListMethod<dynamic>('exampleList');
      return [
        for (final row in rows ?? const [])
          if (row is Map) PersonaExample.fromRow(row.cast<dynamic, dynamic>()),
      ];
    } on Object catch (error) {
      debugPrint('[persona] listExamples falló: $error');
      return const [];
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
  }) async {
    try {
      final rows = await _channel.invokeListMethod<dynamic>('exampleSearch', {
        'query': query,
        'limit': limit,
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
}
