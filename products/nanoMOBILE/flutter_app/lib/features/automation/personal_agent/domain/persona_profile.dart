/// PERSONA-PROFILE-05 — perfiles del agente personal (datos, no lógica).
///
/// - [PersonaProfile]: cómo escribe el DUEÑO (estilo, datos propios). Un
///   solo perfil real ("owner"); la clave única permite variantes futuras.
/// - [RelationshipProfile]: lo que el dueño sabe de CADA contacto
///   (preferencias, trato, contexto de negocio). El retriever
///   (PERSONA-RETRIEVAL-07) lo matchea por el remitente factual de la
///   notificación y COMPOSE-08 lo lleva al prompt.
library;

import 'dart:convert';

final class PersonaProfile {
  final String personaKey;
  final String displayName;

  /// Hechos libres del dueño: {"estilo": "...", "despedida": "..."}. El
  /// retriever los proyecta al prompt; jamás se interpretan aquí.
  final Map<String, String> facts;

  const PersonaProfile({
    required this.personaKey,
    required this.displayName,
    this.facts = const {},
  });

  Map<String, String> factsJson() => facts;

  factory PersonaProfile.fromRow(Map<dynamic, dynamic> row) {
    final factsRaw = row['factsJson'];
    final facts = <String, String>{};
    if (factsRaw is String && factsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(factsRaw);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            if (entry.key is String && entry.value is String) {
              facts[entry.key as String] = entry.value as String;
            }
          }
        }
      } on Object {
        // facts corruptos: se descartan (fail-open a perfil vacío).
      }
    }
    return PersonaProfile(
      personaKey: row['personaKey'] as String? ?? '',
      displayName: row['displayName'] as String? ?? '',
      facts: facts,
    );
  }
}

final class RelationshipProfile {
  final String relationshipKey;
  final String displayName;
  final Map<String, String> facts;

  const RelationshipProfile({
    required this.relationshipKey,
    required this.displayName,
    this.facts = const {},
  });

  factory RelationshipProfile.fromRow(Map<dynamic, dynamic> row) {
    final factsRaw = row['factsJson'];
    final facts = <String, String>{};
    if (factsRaw is String && factsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(factsRaw);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            if (entry.key is String && entry.value is String) {
              facts[entry.key as String] = entry.value as String;
            }
          }
        }
      } on Object {
        // facts corruptos: se descartan.
      }
    }
    return RelationshipProfile(
      relationshipKey: row['relationshipKey'] as String? ?? '',
      displayName: row['displayName'] as String? ?? '',
      facts: facts,
    );
  }
}
