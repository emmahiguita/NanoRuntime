// QUÉ: resuelve planes y proyectos solo si existe evidencia guardada.
// CÓMO: conserva la recuperación factual y devuelve null cuando no hay datos.
// POR QUÉ: una frase fija de agenda impedía consultar el modelo conversacional.
part of 'personal_memory_fact_resolver.dart';

extension _PersonalMemoryPlans on PersonalMemoryFactResolver {
  Future<PersonalTurnReply?> _resolveAppointmentOrProject(
    String userText,
    String conversationId,
    ConversationMemory? memory,
    HybridIntentPrediction pred, {
    required bool isAppointment,
  }) async {
    final matched = await PersonalMemoryFactHelpers.findMatchingMemories(
      memorySource: _memorySource,
      conversationId: conversationId,
      query: userText,
      topics: pred.extractedTopics,
      minScore: 0.25,
    );
    if (matched.isNotEmpty) return _composeFromMemory(matched.first, userText);

    final evidence = PersonalMemoryFactHelpers.findEvidenceInConversation(
      memory,
      pred.extractedTopics,
    );
    if (evidence != null) {
      final opts = PersonalMemoryFactHelpers.buildDynamicOptions(
        userText: userText,
        topics: pred.extractedTopics,
        memorySummary: evidence,
      );
      return PersonalTurnReply(
        text: opts.first,
        understanding: ConversationUnderstanding(
          intent: 'personal_memory_verified',
          relation: 'responde',
          reply: opts.first,
          options: opts,
        ),
        suggestions: opts,
        isFast: true,
      );
    }

    // Sin hechos de agenda/proyecto, no se promete verificar ni se inventa avance.
    // null devuelve el turno al compositor y al modelo con su historial real.
    return null;
  }
}
