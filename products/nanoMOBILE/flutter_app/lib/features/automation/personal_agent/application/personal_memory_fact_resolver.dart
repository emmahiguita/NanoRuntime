// personal_memory_fact_resolver.dart
//
// QUÉ HACE: Recupera y razona sobre `PersonalMemory` (SQLite) y `ConversationMemory`
//   desde un saludo ("Hola") hasta párrafos grandes, ofreciendo opciones naturales.
// CÓMO FUNCIONA: Evalúa correferencias, citas, proyectos y párrafos multi-tema antes del LLM.
// POR QUÉ: Evita respuestas robóticas o inventadas y mantiene <190 líneas (Clean Architecture + SOLID).

library;

import '../../engine/conversation/personal_style_formatter.dart';
import '../../engine/language/hybrid_intent_classifier.dart';
import '../../engine/messaging/conversation_memory.dart';
import '../../engine/notifications/conversation_understanding.dart';
import '../domain/personal_memory.dart';
import 'personal_conversation_resolver.dart' show PersonalTurnReply;
import 'personal_memory_fact_helpers.dart';

export 'personal_memory_fact_helpers.dart' show PersonalMemorySource;

final class PersonalMemoryFactResolver {
  final PersonalMemorySource? _memorySource;
  final HybridIntentClassifier _classifier;
  final PersonalStyleFormatter _formatter;

  const PersonalMemoryFactResolver({
    PersonalMemorySource? memorySource,
    HybridIntentClassifier classifier = const HybridIntentClassifier(),
    PersonalStyleFormatter formatter = const RuntimePersonalStyleFormatter(),
  }) : _memorySource = memorySource,
       _classifier = classifier,
       _formatter = formatter;

  /// Resuelve el turno consultando SQLite y el hilo reciente con opciones de respuesta.
  Future<PersonalTurnReply?> resolve({
    required String userText,
    required String conversationId,
    required ConversationMemory? memory,
  }) async {
    final clean = userText.trim();
    if (clean.isEmpty) return null;
    final pred = _classifier.classify(clean);

    // 1. Correferencias ("lo de la otra vez", "lo de ayer")
    if (pred.primaryIntent == HybridIntentCategory.contextualCoreference ||
        pred.activeIntents.contains(HybridIntentCategory.contextualCoreference)) {
      return _resolveCoreference(clean, conversationId, memory);
    }
    // 2. Cita o encuentro ("¿entonces sí nos vemos mañana?")
    if (pred.primaryIntent == HybridIntentCategory.personalAppointmentOrPlan) {
      return _resolveAppointmentOrProject(clean, conversationId, memory, pred, isAppointment: true);
    }
    // 3. Proyecto propio ("¿ya terminaste la aplicación?")
    if (pred.primaryIntent == HybridIntentCategory.personalProjectOrFact) {
      return _resolveAppointmentOrProject(clean, conversationId, memory, pred, isAppointment: false);
    }
    // 4. Coincidencia temática en SQLite o párrafo largo multi-punto
    if (pred.extractedTopics.isNotEmpty) {
      final matched = await PersonalMemoryFactHelpers.findMatchingMemories(
        memorySource: _memorySource,
        conversationId: conversationId,
        query: clean,
        topics: pred.extractedTopics,
        minScore: 0.45,
      );
      if (matched.isNotEmpty) return _composeFromMemory(matched.first, clean);
      if (pred.extractedTopics.length >= 4 &&
          pred.primaryIntent == HybridIntentCategory.openComplexDialogue) {
        final opts = PersonalMemoryFactHelpers.buildDynamicOptions(
          userText: clean,
          topics: pred.extractedTopics,
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
    }
    return null;
  }

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
      const ask = 'Parce, refrescame la memoria un segundo, ¿a cuál tema te referís exactamente?';
      const opts = [ask, '¿Me recordás de qué estábamos hablando la otra vez?', 'Contame un poco más para ubicarnos bien.'];
      return const PersonalTurnReply(
        text: ask,
        understanding: ConversationUnderstanding(intent: 'coreference_clarification', relation: 'corrige', questions: [ask], missingFacts: ['referente_conversacional_previo'], reply: ask, options: opts),
        suggestions: opts,
        isFast: true,
      );
    }
    if (candidates.length >= 2) {
      final t1 = PersonalMemoryFactHelpers.shortenTopic(candidates[0]);
      final t2 = PersonalMemoryFactHelpers.shortenTopic(candidates[1]);
      final ask = 'Parce, ¿te referís a lo de "$t1" o a lo de "$t2"?';
      final opts = [ask, 'Sí, sobre "$t1" seguimos pendientes.', 'Si es por "$t2", decime cómo avanzamos.'];
      return PersonalTurnReply(
        text: ask,
        understanding: ConversationUnderstanding(intent: 'coreference_disambiguation', relation: 'corrige', questions: [ask], reply: ask, options: opts),
        suggestions: opts,
        isFast: true,
      );
    }
    final single = PersonalMemoryFactHelpers.shortenTopic(candidates.first);
    final opts = PersonalMemoryFactHelpers.buildDynamicOptions(userText: userText, topics: [single], memorySummary: single);
    return PersonalTurnReply(
      text: opts.first,
      understanding: ConversationUnderstanding(intent: 'coreference_resolved', relation: 'continua', reply: opts.first, options: opts),
      suggestions: opts,
      isFast: true,
    );
  }

  Future<PersonalTurnReply> _resolveAppointmentOrProject(
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

    final evidence = PersonalMemoryFactHelpers.findEvidenceInConversation(memory, pred.extractedTopics);
    if (evidence != null) {
      final opts = PersonalMemoryFactHelpers.buildDynamicOptions(userText: userText, topics: pred.extractedTopics, memorySummary: evidence);
      return PersonalTurnReply(
        text: opts.first,
        understanding: ConversationUnderstanding(intent: 'personal_memory_verified', relation: 'responde', reply: opts.first, options: opts),
        suggestions: opts,
        isFast: true,
      );
    }

    final honest = isAppointment
        ? 'Parce, déjame revisar cómo tengo la agenda para confirmar bien y ya te aviso.'
        : 'Parce, ahí voy avanzando con eso paso a paso; apenas tenga novedad concreta te cuento.';
    final opts = [
      honest,
      isAppointment ? 'Dame unos minutos verifico mis horarios y te confirmo.' : 'Todavía estoy afinando detalles, pero va por buen camino.',
      isAppointment ? '¿A qué hora te quedaría mejor por si acaso?' : 'Apenas tenga lista la siguiente versión te la muestro.',
    ];
    return PersonalTurnReply(
      text: honest,
      understanding: ConversationUnderstanding(intent: isAppointment ? 'personal_appointment_unverified' : 'personal_project_unverified', relation: 'responde', missingFacts: [isAppointment ? 'confirmacion_encuentro_propietario' : 'estado_actual_proyecto_propietario'], reply: honest, options: opts),
      suggestions: opts,
      isFast: true,
    );
  }

  PersonalTurnReply _composeFromMemory(PersonalMemory m, String query) {
    final styled = _formatter.formatKnowledge(rawFacts: '${m.key}: ${m.value}', query: query);
    final opts = styled.suggestions.isNotEmpty
        ? styled.suggestions
        : PersonalMemoryFactHelpers.buildDynamicOptions(userText: query, topics: [m.key], memorySummary: '${m.key}: ${m.value}');
    return PersonalTurnReply(
      text: styled.text,
      understanding: ConversationUnderstanding(intent: 'personal_memory_verified', relation: 'responde', reply: styled.text, options: opts),
      suggestions: opts,
      isFast: true,
    );
  }
}
