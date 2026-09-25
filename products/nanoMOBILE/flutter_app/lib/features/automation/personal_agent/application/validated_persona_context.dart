/// Contexto personal validado, listo para entrar al prompt.
/// QUÉ HACE: transporta únicamente campos saneados y rechazos explícitos.
/// CÓMO: el validador construye esta vista inmutable antes de redactar.
/// POR QUÉ: separa el DTO de la política de validación.
library;

import '../domain/persona_example.dart';

final class ValidatedPersonaContext {
  const ValidatedPersonaContext({
    required this.ownerName,
    required this.ownerNotes,
    required this.relationshipName,
    required this.relationshipNotes,
    required this.examples,
    required this.rejected,
  });

  final String ownerName;
  final String ownerNotes;
  final String? relationshipName;
  final String? relationshipNotes;
  final List<PersonaExample> examples;
  final List<String> rejected;

  bool get hasContent =>
      ownerName.isNotEmpty ||
      ownerNotes.isNotEmpty ||
      (relationshipNotes?.isNotEmpty ?? false) ||
      examples.isNotEmpty;
}
