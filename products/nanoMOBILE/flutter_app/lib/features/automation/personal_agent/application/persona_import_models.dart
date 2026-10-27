// QUÉ HACE: modela la revisión y aceptación de un lote de aprendizaje.
// CÓMO: conserva candidatos sin persistir hasta que el dueño los confirme.
// POR QUÉ: evita que un historial externo se convierta automáticamente en memoria.

part of 'persona_import.dart';

final class PersonaImportCandidate {
  const PersonaImportCandidate({
    required this.kind,
    required this.title,
    required this.preview,
    this.example,
    this.memory,
  });

  final String kind, title, preview;
  final Map<String, Object?>? example;
  final PersonalMemory? memory;
}

final class PersonaImportPreview {
  const PersonaImportPreview({
    required this.batchId,
    required this.fileName,
    required this.scopeKey,
    required this.history,
    required this.candidates,
    required this.warnings,
  });

  final String batchId, fileName, scopeKey, history;
  final List<PersonaImportCandidate> candidates;
  final List<String> warnings;

  Map<String, Object?> accepted(
    Set<int> indices, {
    required bool ownerVerified,
  }) {
    final examples = <Map<String, Object?>>[];
    final memories = <Map<String, Object?>>[];
    for (final index in indices.toList()..sort()) {
      if (index < 0 || index >= candidates.length) {
        throw StateError('La selección de revisión ya no es válida.');
      }
      final candidate = candidates[index];
      if (candidate.example case final example?) {
        if (candidate.kind != 'template' && !ownerVerified) {
          throw StateError(
            'Confirma qué respuestas escribiste tú antes de guardar.',
          );
        }
        final tone = Map<String, String>.from(example['tone'] as Map);
        tone['ownerVerified'] =
            '${candidate.kind != 'template' && ownerVerified}';
        examples.add({...example, 'tone': tone});
      }
      if (candidate.memory case final memory?) {
        memories.add(
          memory
              .copyWith(metadata: {...memory.metadata, 'ownerVerified': 'true'})
              .toJson(),
        );
      }
    }
    if (examples.isEmpty && memories.isEmpty) {
      throw StateError('Selecciona datos para guardar.');
    }
    return {
      'batchId': batchId,
      'fileName': fileName,
      'scopeKey': scopeKey,
      'history': history,
      'examples': examples,
      'memories': memories,
    };
  }
}
