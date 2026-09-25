// persona_context.dart
//
// QUÉ HACE:
// Contexto en memoria del Agente Personal y perfiles de relación para WhatsApp y mensajería móvil.
//
// CÓMO FUNCIONA:
// - Mantiene en cache perfiles, notas y estilo del dueño para acceso síncrono ultra-rápido.
// - Carga y refresca durablemente datos desde PersonaRepository bajo la barrera global de stores.
// - Delega la composición sintáctica del prompt a PersonaPromptBuilder.
//
// POR QUÉ:
// Aplica Clean Architecture (SRP/DIP) separando el estado en memoria de la generación de texto (< 200 líneas).

library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/persona_profile.dart';
import '../domain/personal_memory.dart';
import 'persona_prompt_builder.dart';
import 'persona_repository.dart';
import 'persona_retriever.dart';
import 'personal_style_seed.dart';

export 'persona_prompt_builder.dart';

final personaContextProvider = Provider<PersonaContext>((ref) {
  return PersonaContext();
});

final class PersonaContext {
  PersonaContext({PersonaRepository? repository, PersonaRetriever? retriever})
      : _repository = repository ?? PersonaRepository.instance,
        _retriever = retriever ?? PersonaRetriever();

  final PersonaRepository _repository;
  final PersonaRetriever _retriever;

  String _ownerName = '';
  String _ownerNotes = '';
  Map<String, String> _ownerFacts = {};
  final Map<String, RelationshipProfile> _relationships = {};

  Future<void> load() async {
    final personas = await _repository.listPersonas();
    final relationships = await _repository.listRelationships();
    final owner = personas.where((p) => p.personaKey == 'owner').firstOrNull;
    _ownerName = owner?.displayName ?? '';
    _ownerNotes = owner?.facts['notas'] ?? '';
    _ownerFacts = owner?.facts ?? {};
    _relationships.clear();
    for (final relationship in relationships) {
      _relationships[relationship.relationshipKey] = relationship;
    }
    try {
      await ensurePersonalStyleSeed(_repository);
    } catch (e) {
      debugPrint('[persona] Error verificando semilla de estilo: $e');
    }
  }

  Future<void> refresh() => load();

  bool hasRelationshipFor(String sender, {String conversationId = ''}) =>
      relationshipFor(sender, conversationId: conversationId) != null;

  RelationshipProfile? relationshipFor(String sender, {String conversationId = ''}) {
    final senderKey = sender.trim().toLowerCase();
    final profile = conversationId.isEmpty
        ? _relationships[senderKey]
        : _relationships[personalizationScope(conversationId)] ??
              _relationships[senderKey];
    return profile?.facts['profileEnabled'] == 'false' ? null : profile;
  }

  /// El historial operativo siempre conserva contexto. El aprendizaje de
  /// personalidad, en cambio, sólo se permite para perfiles habilitados de
  /// forma explícita y respeta el interruptor global del dueño.
  bool allowsStyleLearningFor(String sender, {String conversationId = ''}) {
    if (_ownerFacts['learnStyle'] == 'false') return false;
    final profile = relationshipFor(sender, conversationId: conversationId);
    return profile?.facts['learnStyle'] == 'true';
  }

  String get ownerName => _ownerName;

  Future<String> personaBlockFor(
    String messageText,
    String sender, {
    String conversationId = '',
    String role = 'personal',
  }) {
    return PersonaPromptBuilder.buildBlock(
      messageText: messageText,
      sender: sender,
      ownerName: _ownerName,
      ownerNotes: _ownerNotes,
      ownerFacts: _ownerFacts,
      relationships: _relationships,
      retriever: _retriever,
      repository: _repository,
      conversationId: conversationId,
      role: role,
    );
  }
}
