import 'dart:convert';
import '../domain/persona_profile.dart';
import '../domain/personal_contact_policy.dart';
import '../domain/personal_memory.dart';
import 'persona_repository.dart';

/// Una fuente durable; migración por ID, sin deduplicar por nombres visibles.
class PersonalContactsRepository {
  PersonalContactsRepository({PersonaRepository? repository})
    : _repo = repository ?? PersonaRepository.instance;
  final PersonaRepository _repo;
  static Future<void> _tail = Future.value();

  Future<List<RelationshipProfile>> load() async {
    final relationships = await _repo.listRelationships(rethrowFailures: true);
    final old = await _repo.listPersonas(rethrowFailures: true);
    final keys = relationships.map((p) => p.relationshipKey).toSet();
    for (final profile in old.where(
      (p) => p.personaKey.startsWith('contact_'),
    )) {
      final key = 'unbound:legacy:${profile.personaKey}';
      if (keys.contains(key) ||
          relationships.any(
            (p) => p.facts['legacyPersonaKey'] == profile.personaKey,
          )) {
        continue;
      }
      final facts = {
        ...profile.facts,
        'autoReply': 'false',
        'legacyPersonaKey': profile.personaKey,
        'styleRegister': PersonalContactPolicy.normalizeStyle(
          profile.facts['styleRegister'],
        ),
      };
      if (!await _repo.upsertRelationship(key, profile.displayName, facts)) {
        throw StateError('No se pudo recuperar un contacto anterior.');
      }
      relationships.add(
        RelationshipProfile(
          relationshipKey: key,
          displayName: profile.displayName,
          facts: facts,
        ),
      );
    }
    return relationships
        .where((p) => !p.relationshipKey.startsWith('role:'))
        .toList();
  }

  Future<void> save({
    RelationshipProfile? existing,
    required String name,
    required List<String> conversationIds,
    required List<String> groups,
    required String style,
    required bool autoReply,
  }) {
    final task = _tail.then((_) async {
      final profiles = await load();
      if (autoReply && conversationIds.isEmpty) {
        throw StateError(
          'Vincula una conversación antes de permitir respuestas automáticas.',
        );
      }
      if (existing?.relationshipKey.startsWith('contact:') == true &&
          !conversationIds.any(
            (id) => personalizationScope(id) == existing!.relationshipKey,
          )) {
        throw StateError(
          'Conserva la conversación principal. Para dejar de atenderla, retira y pausa la ficha.',
        );
      }
      if (name.trim().isEmpty) {
        throw StateError('Escribe el nombre del contacto.');
      }
      for (final profile in profiles) {
        if (profile.relationshipKey == existing?.relationshipKey) continue;
        if (PersonalContactPolicy.conversations(
              profile,
            ).any(conversationIds.contains) ||
            conversationIds.any(
              (id) => personalizationScope(id) == profile.relationshipKey,
            )) {
          throw StateError(
            'Una conversación ya pertenece a ${profile.displayName}. Edita esa ficha.',
          );
        }
      }
      if (existing == null && conversationIds.isEmpty) {
        throw StateError('Selecciona una conversación real.');
      }
      final key =
          existing?.relationshipKey ??
          personalizationScope(conversationIds.first);
      final facts = {
        ...?existing?.facts,
        'conversationIds': jsonEncode(conversationIds.toSet().toList()),
        'conversationId': conversationIds.firstOrNull ?? '',
        'groups': jsonEncode(groups.toSet().toList()),
        'styleRegister': style,
        'autoReply': '$autoReply',
        'profileEnabled': 'true',
        'hiddenFromContacts': 'false',
        'relationship': groups.any((g) => g == 'Trabajo' || g == 'Clientes')
            ? 'professional'
            : groups.any(
                (g) =>
                    g == 'Familia' || g == 'Amigos cercanos' || g == 'Amigos',
              )
            ? 'close'
            : 'known',
      };
      if (!await _repo.upsertRelationship(key, name.trim(), facts)) {
        throw StateError('No se pudo guardar el contacto.');
      }
    });
    _tail = task.then<void>((_) {}, onError: (Object _) {});
    return task;
  }
}
