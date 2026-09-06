/// PERSONA-COMPOSE-08 — contexto del agente personal para el prompt.
///
/// Cache en memoria (hidratada por la barrera global) para las lecturas del
/// perfil del dueño y las relaciones; retriever FTS4 (async) para los
/// ejemplos de estilo. Regla FACTS → DECISION → PERSONA → SEND: este bloque
/// es SOLO forma y hechos del dueño — la decisión de enviar ya corrió en el
/// DecisionEngine antes de llegar aquí.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/persona_example.dart';
import '../domain/persona_profile.dart';
import 'persona_repository.dart';
import 'persona_retriever.dart';

/// Única instancia del contexto personal: la UI de Ajustes refresca este
/// cache tras editar y el writer lo lee EN VIVO por borrador. Hidratación
/// bajo la barrera global de stores (coordinator).
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
  final Map<String, RelationshipProfile> _relationships = {};

  /// Hidratación (barrera global): perfiles y relaciones en cache. Los
  /// ejemplos NO se cachean: el retriever los busca por mensaje.
  Future<void> load() async {
    for (final persona in await _repository.listPersonas()) {
      if (persona.personaKey == 'owner') {
        _ownerName = persona.displayName;
        _ownerNotes = persona.facts['notas'] ?? '';
      }
    }
    _relationships.clear();
    for (final relationship in await _repository.listRelationships()) {
      _relationships[relationship.relationshipKey] = relationship;
    }
  }

  /// Recarga tras editar en la UI (misma vía que [load]).
  Future<void> refresh() => load();

  /// Bloque <DATOS DE LA PERSONA> para el prompt ('' si no hay nada).
  ///
  /// [messageText] alimenta el retriever (ejemplos parecidos al contexto);
  /// [sender] es el remitente FACTUAL de la notificación (jamás el LLM) y
  /// matchea la relación por clave normalizada (nombre en minúsculas).
  Future<String> personaBlockFor(String messageText, String sender) async {
    final parts = <String>[];
    if (_ownerName.isNotEmpty) {
      parts.add(
        'El dueño del negocio es $_ownerName. Preséntate como su asistente '
        'solo si el cliente lo pregunta.',
      );
    }
    if (_ownerNotes.isNotEmpty) {
      parts.add('Datos del dueño: $_ownerNotes');
    }
    final relationship = _relationships[sender.trim().toLowerCase()];
    if (relationship != null) {
      final notes = relationship.facts['notas'];
      if (notes != null && notes.isNotEmpty) {
        parts.add(
          'Sobre el contacto ${relationship.displayName}: $notes',
        );
      }
    }
    final examples = await _retriever.retrieve(messageText);
    if (examples.isNotEmpty) {
      parts.add(
        'Ejemplos de cómo responde el dueño (guía de forma):\n'
        '${examples.map(_exampleLine).join('\n')}',
      );
    }
    if (parts.isEmpty) return '';
    return '<DATOS DE LA PERSONA>\n'
        '${parts.join('\n')}\n'
        'Hechos sobre el dueño y sus contactos: úsalos SOLO para forma y '
        'contexto real; jamás inventes datos a partir de ellos.\n'
        '</DATOS DE LA PERSONA>';
  }

  static String _exampleLine(PersonaExample example) => '- ${example.body}';
}
