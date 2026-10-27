// personal_memory_fact_resolver.dart
//
// QUÉ HACE: Recupera y razona sobre `PersonalMemory` (SQLite) y `ConversationMemory`
//   desde un saludo ("Hola") hasta párrafos grandes, ofreciendo opciones naturales.
// CÓMO FUNCIONA: Evalúa correferencias, citas, proyectos y párrafos multi-tema antes del LLM.
// POR QUÉ: separa recuperación factual y redacción; sin hechos, delega al modelo.

library;

import '../../engine/conversation/personal_style_formatter.dart';
import '../../engine/language/hybrid_intent_classifier.dart';
import '../../engine/messaging/conversation_memory.dart';
import '../../engine/notifications/conversation_understanding.dart';
import '../domain/personal_memory.dart';
import 'personal_conversation_resolver.dart' show PersonalTurnReply;
import 'personal_memory_fact_helpers.dart';

export 'personal_memory_fact_helpers.dart' show PersonalMemorySource;

part 'personal_memory_coreference.dart';
part 'personal_memory_plans.dart';

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
        pred.activeIntents.contains(
          HybridIntentCategory.contextualCoreference,
        )) {
      return _resolveCoreference(clean, conversationId, memory);
    }
    // 2. Cita o encuentro ("¿entonces sí nos vemos mañana?")
    if (pred.primaryIntent == HybridIntentCategory.personalAppointmentOrPlan) {
      return _resolveAppointmentOrProject(
        clean,
        conversationId,
        memory,
        pred,
        isAppointment: true,
      );
    }
    // 3. Proyecto propio ("¿ya terminaste la aplicación?")
    if (pred.primaryIntent == HybridIntentCategory.personalProjectOrFact) {
      return _resolveAppointmentOrProject(
        clean,
        conversationId,
        memory,
        pred,
        isAppointment: false,
      );
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
      // Extraer palabras clave no demuestra que Nano recuerde el contenido.
      // Si no hay un registro coincidente, devolver null permite que el modelo
      // conversacional/MCP responda o que el dispatcher omita el envío.
    }
    return null;
  }

  PersonalTurnReply _composeFromMemory(PersonalMemory m, String query) {
    final styled = _formatter.formatKnowledge(
      rawFacts: '${m.key}: ${m.value}',
      query: query,
    );
    final opts = styled.suggestions.isNotEmpty
        ? styled.suggestions
        : PersonalMemoryFactHelpers.buildDynamicOptions(
            userText: query,
            topics: [m.key],
            memorySummary: '${m.key}: ${m.value}',
          );
    return PersonalTurnReply(
      text: styled.text,
      understanding: ConversationUnderstanding(
        intent: 'personal_memory_verified',
        relation: 'responde',
        reply: styled.text,
        options: opts,
      ),
      suggestions: opts,
      isFast: true,
    );
  }
}
