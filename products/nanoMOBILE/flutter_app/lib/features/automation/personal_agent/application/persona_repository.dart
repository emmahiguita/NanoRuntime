// persona_repository.dart
//
// QUÉ HACE:
// Repositorio de perfiles del Agente Personal, relaciones de contactos y ejemplos de estilo (SQLite v3).
//
// CÓMO FUNCIONA:
// - Única vía tipada entre Dart y SQLite mediante el canal nativo `com.nanoai/automation_store`.
// - Almacena y consulta perfiles en `persona_profiles` y `relationship_profiles`.
// - Soporta indexación y búsqueda rápida de pares condicionados mediante FTS4 (`exampleSearch`).
// - Extiende operaciones de memoria e historial a través de `persona_repository_memories.dart`.
//
// POR QUÉ:
// Mantiene retrocompatibilidad total sin romper llamadas existentes (< 200 líneas).

library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

import '../domain/persona_example.dart';
import '../domain/persona_profile.dart';
import '../domain/personal_memory.dart';

part 'persona_repository_memories.dart';
part 'persona_repository_examples.dart';

final class PersonaRepository {
  PersonaRepository._();

  static final PersonaRepository instance = PersonaRepository._();
  static const _channel = MethodChannel('com.nanoai/automation_store');

  /// Upsert del perfil de la persona (clave única, normalmente "owner").
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
}
