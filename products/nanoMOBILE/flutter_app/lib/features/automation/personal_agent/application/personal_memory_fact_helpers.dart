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

  // QUÉ HACE: Extrae hasta 3 palabras-clave temáticas de los últimos turnos de conversación.
  // CÓMO FUNCIONA: Itera la memoria en reverso, omite entradas muy cortas o iguales al texto actual,
  //   extrae la primera palabra significativa (≤25 chars) de cada entrada como keyword.
  // POR QUÉ: La versión anterior devolvía oraciones completas (50-100 chars c/u); su join
  //   producía un $focus de 300+ chars → buildDynamicOptions generaba replies >2000 chars
  //   → 'reply_notification excede 2000 caracteres' → fallo sistemático en "Calma mi amor".
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
      final words = tokenizeText(norm).where((w) => w.length >= 3).toList();
      if (words.length < 2) continue;
      // Tomar la primera palabra clave significativa (≤25 chars) como topic.
      final keyword = words.firstWhere(
        (w) => w.length >= 4 && !_stopWords.contains(w),
        orElse: () => words.first,
      );
      final topic = keyword.length <= 25 ? keyword : keyword.substring(0, 25);
      if (!results.contains(topic)) results.add(topic);
      if (results.length >= 3) break;
    }
    return results;
  }

  // Palabras vacías que no aportan valor como tópico.
  static const _stopWords = {
    'que', 'con', 'para', 'por', 'los', 'las', 'del', 'una', 'uno',
    'como', 'esta', 'este', 'esto', 'ese', 'esa', 'hay', 'ser', 'son',
    'tiene', 'puede', 'bien', 'mal', 'mas', 'muy', 'todo', 'cada',
  };

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
    List<String> topicFollowups = const [],
  }) {
    if (topicFollowups.isNotEmpty) {
      return topicFollowups.take(3).toList();
    }
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
    final normUser = normalizeText(userText);
    if (normUser.contains('haces') || normUser.contains('haciendo') || normUser.contains('hacer')) {
      return const [
        'Por acá relajado, ¿y vos qué tal todo?',
        'Acá trabajando un rato en el cel, ¿y tú qué haces?',
        'En las mismas parce, descansando un rato. ¿Qué me cuentas?',
      ];
    }
    if (normUser.contains('alegra') || normUser.contains('que bueno') || normUser.contains('genial')) {
      return const [
        'Total parce, me alegra mucho también.',
        'De una, un abrazo. Todo marchando bien por acá.',
        'Sisas, gracias a Dios todo en orden. ¿Y tú cómo vas?',
      ];
    }
    if (normUser.contains('gracias') || normUser.contains('agradezco')) {
      return const [
        'Con todo gusto parce, para lo que necesites.',
        'De una, con mucho gusto. Me avisas cualquier cosa.',
        'Un placer hermano, todo bien por acá.',
      ];
    }
    if (normUser.contains('bien') || normUser.contains('bueno') || normUser.contains('listo') || normUser.contains('dale')) {
      return const [
        'Listo pues parce, todo claro por acá.',
        'De una, un abrazo. Cualquier cosa me avisás.',
        'Dale hermano, hablamos más tarde.',
      ];
    }
    if (normUser.contains('no pregunte') || normUser.contains('no lo pregunte') || normUser.contains('equivocaste')) {
      return const [
        'Qué pena, me enredé ahí. Cuéntame, ¿qué era lo que me decías?',
        'Qué pena contigo parce, me crucé de tema. Dime qué necesitas y lo miramos.',
        'Ah, disculpa. Me confundí de mensaje. Decime qué era lo que necesitabas.',
      ];
    }
    return const [
      'Hola, todo bien por acá. ¿Qué tal tu día?',
      'Hola parce, por acá todo tranquilo. ¿Cómo estás?',
      'Qué más, todo bien por este lado. ¿Qué cuentas?',
    ];
  }
}
