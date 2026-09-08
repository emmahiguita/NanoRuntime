/// PERSONA-VALIDATE-09 — validador determinista del contexto personal.
///
/// Regla del documento: «No confíes en un confidence=0.97 generado por el
/// LLM». Este validador NO genera confianza — aplica chequeos mecánicos
/// sobre el bloque <DATOS DE LA PERSONA> ANTES de entrar al prompt:
///
/// - neutraliza etiquetas tipo `<...>` (un dato del dueño jamás puede
///   romper la estructura del prompt ni inyectar un bloque falso);
/// - acota cada parte y el total (el prompt WA es compacto a propósito:
///   el motor local en Oppo degrada el contexto, WA-CTX-01);
/// - colapsa saltos de línea en campos sueltos (eco del modelo débil);
/// - descarta ejemplos vacíos o duplicados tras normalizar.
///
/// Puro y determinista: misma entrada → misma salida, sin LLM.
library;

import 'package:flutter/foundation.dart' show debugPrint;

import '../domain/persona_example.dart';

/// Contexto personal limpio, listo para el prompt. Los campos acotados son
/// los que el validador autoriza; [rejected] registra cada recorte para que
/// el dueño vea qué no entró (traza honesta, jamás silencio).
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

final class PersonaValidator {
  const PersonaValidator();

  /// Límites duros. Total acotado a 1500 chars: el bloque persona convive
  /// con estilo/tono/datos de negocio en un prompt ya denso (WA-CTX-01).
  static const int maxOwnerName = 80;
  static const int maxOwnerNotes = 500;
  static const int maxRelationshipNotes = 300;
  static const int maxExampleChars = 500;

  /// R5-03 — la entrada del cliente del par va acotada más corta que la
  /// respuesta: es el disparador del ejemplo, no su contenido.
  static const int maxExampleIncomingChars = 200;
  static const int maxExamples = 2;
  static const int maxTotalChars = 1500;

  ValidatedPersonaContext validate({
    required String ownerName,
    required String ownerNotes,
    String? relationshipName,
    String? relationshipNotes,
    List<PersonaExample> examples = const [],
  }) {
    final rejected = <String>[];

    var name = _neutralize(ownerName).trim();
    var notes = _neutralize(ownerNotes);
    var relName = relationshipName == null
        ? null
        : _neutralize(relationshipName).trim();
    var relNotes = relationshipNotes == null
        ? null
        : _neutralize(relationshipNotes);
    var cleanExamples = <PersonaExample>[];

    if (name.length > maxOwnerName) {
      rejected.add(
        'nombre del dueño recortado (${name.length} > $maxOwnerName)',
      );
      name = name.substring(0, maxOwnerName);
    }
    if (notes.length > maxOwnerNotes) {
      rejected.add(
        'notas del dueño omitidas (${notes.length} > $maxOwnerNotes)',
      );
      notes = '';
    }
    if (relName != null && relName.isEmpty) relName = null;
    if (relNotes != null) {
      if (relNotes.length > maxRelationshipNotes) {
        rejected.add(
          'notas de relación omitidas (${relNotes.length} > $maxRelationshipNotes)',
        );
        relNotes = '';
      }
      if (relNotes.trim().isEmpty) relNotes = null;
    }

    final seen = <String>{};
    for (final example in examples) {
      final body = _neutralize(example.body).trim();
      if (body.isEmpty) {
        rejected.add('ejemplo vacío descartado');
        continue;
      }
      if (seen.contains(body)) {
        rejected.add('ejemplo duplicado descartado');
        continue;
      }
      if (cleanExamples.length >= maxExamples) {
        rejected.add('ejemplos extra descartados (máx $maxExamples)');
        break;
      }
      seen.add(body);
      if (body.length > maxExampleChars) {
        rejected.add(
          'ejemplo largo omitido (${body.length} > $maxExampleChars)',
        );
        continue;
      }
      // R5-03 — la entrada del par se neutraliza y acota igual que el body;
      // si se pierde aquí el par se degrada a estilo legacy en el prompt.
      final incoming = _neutralize(example.incomingText).trim();
      if (incoming.length > maxExampleIncomingChars) {
        rejected.add(
          'entrada larga del ejemplo omitida '
          '(${incoming.length} > $maxExampleIncomingChars)',
        );
        continue;
      }
      cleanExamples.add(
        PersonaExample(
          id: example.id,
          personaKey: example.personaKey,
          body: body,
          incomingText: incoming,
          tone: example.tone,
          source: example.source,
        ),
      );
    }

    // Presupuesto total: recorta por prioridad (notas del dueño → notas de
    // relación → ejemplos). El nombre del dueño y la estructura nunca caen.
    var total = _totalOf(name, notes, relNotes, cleanExamples);
    if (total > maxTotalChars) {
      rejected.add(
        'bloque persona excede $maxTotalChars chars; recorte por prioridad',
      );
      var overflow = total - maxTotalChars;
      if (overflow > 0 && notes.isNotEmpty) {
        notes = '';
        total = _totalOf(name, notes, relNotes, cleanExamples);
        overflow = total - maxTotalChars;
      }
      if (overflow > 0 && relNotes != null && relNotes.isNotEmpty) {
        relNotes = null;
        total = _totalOf(name, notes, relNotes, cleanExamples);
        overflow = total - maxTotalChars;
      }
      while (overflow > 0 && cleanExamples.isNotEmpty) {
        final removed = cleanExamples.removeLast();
        overflow -= removed.body.length + removed.incomingText.length;
      }
    }

    if (rejected.isNotEmpty) {
      debugPrint('[persona] validator rechazó: ${rejected.join(' | ')}');
    }
    return ValidatedPersonaContext(
      ownerName: name,
      ownerNotes: notes.trim(),
      relationshipName: relName,
      relationshipNotes: relNotes?.trim(),
      examples: cleanExamples,
      rejected: rejected,
    );
  }

  /// Etiquetas tipo `<...>` fuera (podrían romper la estructura del prompt
  /// o inyectar un bloque falso) y saltos de línea colapsados a espacio
  /// (los campos sueltos van en una línea del prompt).
  static String _neutralize(String value) =>
      value.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('\n', ' ').trim();

  static int _totalOf(
    String name,
    String notes,
    String? relNotes,
    List<PersonaExample> examples,
  ) =>
      name.length +
      notes.length +
      (relNotes?.length ?? 0) +
      examples.fold(0, (sum, e) => sum + e.body.length + e.incomingText.length);
}
