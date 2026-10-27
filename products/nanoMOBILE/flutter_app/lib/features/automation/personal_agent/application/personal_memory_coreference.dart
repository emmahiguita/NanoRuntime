// QUÉ: conserva la resolución existente de referencias al historial.
// CÓMO: consulta los mismos hechos y temas, dentro de la biblioteca del resolver.
// POR QUÉ: separa esta responsabilidad sin duplicar estado ni cambiar contratos.
part of 'personal_memory_fact_resolver.dart';

extension _PersonalMemoryCoreference on PersonalMemoryFactResolver {
  Future<PersonalTurnReply> _resolveCoreference(
    String userText,
    String conversationId,
    ConversationMemory? memory,
  ) async {
    final candidates = PersonalMemoryFactHelpers.extractConversationTopics(
      memory,
      currentText: userText,
    );
    final stored = await PersonalMemoryFactHelpers.findMatchingMemories(
      memorySource: _memorySource,
      conversationId: conversationId,
      query: userText,
      topics: const [],
      minScore: 0.15,
    );
    for (final m in stored.take(2)) {
      final s = '${m.key}: ${m.value}'.trim();
      if (!candidates.contains(s)) candidates.add(s);
    }

    if (candidates.isEmpty) {
      const ask =
          'Parce, refrescame la memoria un segundo, ¿a cuál tema te referís exactamente?';
      const opts = [
        ask,
        '¿Me recordás de qué estábamos hablando la otra vez?',
        'Contame un poco más para ubicarnos bien.',
      ];
      return const PersonalTurnReply(
        text: ask,
        understanding: ConversationUnderstanding(
          intent: 'coreference_clarification',
          relation: 'corrige',
          questions: [ask],
          missingFacts: ['referente_conversacional_previo'],
          reply: ask,
          options: opts,
        ),
        suggestions: opts,
        isFast: true,
      );
    }
    if (candidates.length >= 2) {
      final t1 = PersonalMemoryFactHelpers.shortenTopic(candidates[0]);
      final t2 = PersonalMemoryFactHelpers.shortenTopic(candidates[1]);
      final ask = 'Parce, ¿te referís a lo de "$t1" o a lo de "$t2"?';
      final opts = [
        ask,
        'Sí, sobre "$t1" seguimos pendientes.',
        'Si es por "$t2", decime cómo avanzamos.',
      ];
      return PersonalTurnReply(
        text: ask,
        understanding: ConversationUnderstanding(
          intent: 'coreference_disambiguation',
          relation: 'corrige',
          questions: [ask],
          reply: ask,
          options: opts,
        ),
        suggestions: opts,
        isFast: true,
      );
    }
    final single = PersonalMemoryFactHelpers.shortenTopic(candidates.first);
    final opts = PersonalMemoryFactHelpers.buildDynamicOptions(
      userText: userText,
      topics: [single],
      memorySummary: single,
    );
    return PersonalTurnReply(
      text: opts.first,
      understanding: ConversationUnderstanding(
        intent: 'coreference_resolved',
        relation: 'continua',
        reply: opts.first,
        options: opts,
      ),
      suggestions: opts,
      isFast: true,
    );
  }
}
