/// Memoria de correcciones explícitas del dueño, separada del catálogo de
/// respuestas para que cada componente tenga una única responsabilidad.
library;

import '../domain/personal_memory.dart';
import 'persona_repository.dart';
import 'personal_learning_text.dart';

final class PersonalReplyCorrectionMemory {
  const PersonalReplyCorrectionMemory(this._repository);

  final PersonaRepository _repository;

  /// Persiste una preferencia sólo una vez por entrada y corrección exactas.
  Future<void> remember({
    required String incoming,
    required String reply,
    required String correctedFrom,
  }) async {
    final memories = await _repository.listPersonalMemories(
      scopeKey: 'owner',
      limit: 50,
    );
    final repeated = memories.any(
      (item) =>
          item.kind == 'stylePreference' &&
          normalizePersonalLearningText(
                item.metadata['input']?.toString() ?? '',
              ) ==
              normalizePersonalLearningText(incoming) &&
          normalizePersonalLearningText(
                item.metadata['corrected']?.toString() ?? '',
              ) ==
              normalizePersonalLearningText(reply),
    );
    if (repeated) return;

    await _repository.savePersonalMemory(
      PersonalMemory(
        scopeKey: 'owner',
        key: 'correccion_estilo',
        value: 'Preferir "$reply" sobre "$correctedFrom"',
        kind: 'stylePreference',
        observedAt: DateTime.now().millisecondsSinceEpoch,
        metadata: {
          'suggested': correctedFrom,
          'corrected': reply,
          'input': incoming,
        },
      ),
    );
  }
}
