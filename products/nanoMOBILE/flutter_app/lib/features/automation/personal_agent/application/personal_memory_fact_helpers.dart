// personal_memory_fact_helpers.dart
//
// QUÉ HACE:
// Funciones auxiliares de búsqueda temática y extracción de referentes en
// `PersonalMemory` (SQLite) y `ConversationMemory` para `PersonalMemoryFactResolver`.
//
// POR QUÉ:
// Mantiene `personal_memory_fact_resolver.dart` por debajo de 180 líneas (SOLID - SRP).

library;

import '../../engine/business/fact_selector.dart' show normalizeText, tokenizeText;
import '../../engine/messaging/conversation_memory.dart';
import '../../engine/messaging/social_context_retriever.dart';
import '../domain/personal_memory.dart';
import 'persona_repository.dart';

typedef PersonalMemorySource = Future<List<PersonalMemory>> Function({
  String? scopeKey,
  int limit,
});

abstract final class PersonalMemoryFactHelpers {
  static Future<List<PersonalMemory>> findMatchingMemories({
    PersonalMemorySource? memorySource,
    required String conversationId,
    required String query,
    required List<String> topics,
    required double minScore,
  }) async {
    try {
      final fetch = memorySource ?? PersonaRepository.instance.listPersonalMemories;
      final scope = personalizationScope(conversationId);
      final raw = <PersonalMemory>[
        if (scope != 'owner') ...await fetch(scopeKey: scope, limit: 50),
        ...await fetch(scopeKey: 'owner', limit: 80),
      ];
      if (raw.isEmpty) return const [];

      final now = DateTime.now().millisecondsSinceEpoch;
      final active = PersonalMemory.resolveSupersession(raw).where(
        (m) => m.enabled && m.lifecycleAt(now) != MemoryLifecycleState.superseded,
      );

      final scored = <(PersonalMemory, double)>[];
      for (final m in active) {
        final combined = '${m.key} ${m.value}';
        var score = SocialContextRetriever.scoreThematicRelevance(query, combined);
        final normCombined = normalizeText(combined);
        for (final t in topics) {
          if (normCombined.contains(t)) score += 0.35;
        }
        if (m.scopeKey == scope && scope != 'owner') score += 0.15;
        if (score >= minScore) scored.add((m, score));
      }
      scored.sort((a, b) => b.$2.compareTo(a.$2));
      return scored.map((e) => e.$1).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static List<String> extractConversationTopics(
    ConversationMemory? memory, {
    required String currentText,
  }) {
    if (memory == null || memory.entries.isEmpty) return <String>[];
    final results = <String>[];
    final normCurrent = normalizeText(currentText);
    for (final entry in memory.entries.reversed) {
      final norm = normalizeText(entry.text);
      if (norm.isEmpty || norm == normCurrent) continue;
      if (tokenizeText(norm).length < 4) continue;
      if (!results.contains(entry.text.trim())) {
        results.add(entry.text.trim());
      }
      if (results.length >= 3) break;
    }
    return results;
  }

  static String? findEvidenceInConversation(
    ConversationMemory? memory,
    List<String> topics,
  ) {
    if (memory == null || memory.entries.isEmpty || topics.isEmpty) return null;
    for (final entry in memory.entries.reversed) {
      final norm = normalizeText(entry.text);
      if (topics.any(norm.contains) && tokenizeText(norm).length >= 4) {
        return shortenTopic(entry.text.trim());
      }
    }
    return null;
  }

  static String shortenTopic(String raw) =>
      raw.length <= 70 ? raw : '${raw.substring(0, 67)}...';

  /// Construye opciones naturales no robóticas para saludos cortos ("Hola") o párrafos extensos.
  /// QUÉ HACE: Genera 3 alternativas de respuesta adaptadas al contenido del mensaje.
  /// CÓMO FUNCIONA: Si detecta tópicos en un párrafo largo, los referencia; si es saludo corto,
  ///   ofrece respuestas cálidas y variadas sin plantillas estáticas.
  /// POR QUÉ: Garantiza opciones para responder desde un "Hola" hasta párrafos grandes.
  static List<String> buildDynamicOptions({
    required String userText,
    required List<String> topics,
    String? memorySummary,
  }) {
    if (memorySummary != null && memorySummary.isNotEmpty) {
      return [
        'Sí parce, confirmado: $memorySummary.',
        'Claro, sobre eso tengo presente que $memorySummary. ¿Cómo lo cuadramos?',
        'Dale, revisemos lo de $memorySummary apenas tengas un espacio.',
      ];
    }
    if (topics.length >= 2) {
      final focus = topics.take(3).join(', ');
      return [
        'Entendido parce, te leí todo sobre $focus. Dame un momento y revisamos cada punto.',
        'Claro que sí, muy buen resumen sobre $focus. ¿Por cuál punto empezamos primero?',
        'Ya vi lo que me comentas de $focus; déjame verificar los detalles y te confirmo.',
      ];
    }
    return const [
      '¡Hola! ¿Qué tal todo? Contame cómo vas.',
      '¡Buenas! Todo bien por acá, ¿en qué te puedo colaborar hoy?',
      '¡Qué más parce! Decime qué tenés en mente.',
    ];
  }
}
