/// PERSONAL STYLE FORMATTER
///
/// Transforma hechos crudos o información externa (Web, Catálogo, Noticias)
/// al estilo conversacional auténtico de Emmanuel (paisa/colombiano cercano),
/// sin sonar robótico ni como asistente de soporte.
/// Cumple Clean Architecture, SOLID y límite de < 200 líneas.
library;

import '../language/language_assist.dart';
import '../notifications/conversation_understanding.dart';

final class StyledResponseResult {
  final String text;
  final List<String> suggestions;
  final ConversationUnderstanding understanding;

  const StyledResponseResult({
    required this.text,
    required this.suggestions,
    required this.understanding,
  });
}

abstract interface class PersonalStyleFormatter {
  StyledResponseResult formatKnowledge({
    required String rawFacts,
    required String query,
    String? ownerName,
  });
}

final class RuntimePersonalStyleFormatter implements PersonalStyleFormatter {
  const RuntimePersonalStyleFormatter();

  static const _intros = [
    'Pillá que',
    'Por lo que vi,',
    'Por ahí estuve mirando y',
    'Según estuve viendo,',
    'Pillá, según vi:',
  ];

  @override
  StyledResponseResult formatKnowledge({
    required String rawFacts,
    required String query,
    String? ownerName,
  }) {
    final cleanFacts = _cleanRawFacts(rawFacts);

    if (cleanFacts.isEmpty) {
      const candidates = [
        'La verdad no sé, tendría que mirar.',
        'No sé, déjame ver y te digo.',
        'No sabría decirte, no encontré nada claro.',
        'No estoy seguro todavía, déjame ver.',
      ];
      final minuteSeed = (query.hashCode ^ DateTime.now().minute).abs();
      final fallback = candidates[minuteSeed % candidates.length];
      return StyledResponseResult(
        text: fallback,
        suggestions: candidates.take(3).toList(),
        understanding: ConversationUnderstanding(
          reply: fallback,
          intent: 'knowledge_empty',
          relation: 'responde',
          questions: const [],
          missingFacts: const ['informacion_no_encontrada'],
          requiresAction: false,
        ),
      );
    }

    // Componer respuesta en primera persona auténtica
    final minuteSeed = (query.hashCode ^ DateTime.now().minute).abs();
    final intro = _intros[minuteSeed % _intros.length];

    // Formatear texto conciso y completo (1 a 3 oraciones)
    final sentences = cleanFacts.split(RegExp(r'(?<=[.!?])\s+'));
    final textBody = sentences.take(3).join(' ').trim();
    final isAlreadyConversational = cleanFacts.toLowerCase().startsWith('hola') ||
        cleanFacts.toLowerCase().startsWith('claro') ||
        cleanFacts.toLowerCase().startsWith('mira') ||
        cleanFacts.toLowerCase().startsWith('pillá') ||
        cleanFacts.toLowerCase().startsWith('pilla');

    final formattedPrimary = isAlreadyConversational
        ? textBody
        : '$intro $textBody'.trim();
    final cleaned = LanguageAssistService.safeCleanOutput(formattedPrimary);

    final suggestions = <String>[cleaned];

    // Alternativas estilísticas
    final alt1 = isAlreadyConversational
        ? textBody
        : 'Estuve mirando y $textBody'.trim();
    final cleanAlt1 = LanguageAssistService.safeCleanOutput(alt1);
    if (!suggestions.contains(cleanAlt1)) suggestions.add(cleanAlt1);

    final alt2 = textBody;
    final cleanAlt2 = LanguageAssistService.safeCleanOutput(alt2);
    if (!suggestions.contains(cleanAlt2)) suggestions.add(cleanAlt2);

    return StyledResponseResult(
      text: cleaned,
      suggestions: suggestions,
      understanding: ConversationUnderstanding(
        reply: cleaned,
        options: suggestions,
        intent: 'external_knowledge_styled',
        relation: 'responde',
        questions: const [],
        missingFacts: const [],
        requiresAction: false,
      ),
    );
  }

  /// Limpia citas, URLs y prefijos pesados típicos de motores de búsqueda.
  static String _cleanRawFacts(String raw) {
    var text = raw.trim();

    // Remover encabezados markdown de búsqueda
    text = text.replaceAll(RegExp(r'### 🌐.*?\n\n'), '');
    text = text.replaceAll(RegExp(r'\*\*Puntos destacados:\*\*.*', dotAll: true), '');
    text = text.replaceAll(RegExp(r'🔍 \*Fuente.*', dotAll: true), '');
    text = text.replaceAll(RegExp(r'https?:\/\/\S+'), '');
    text = text.replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1');

    // Remover jerga formal de Wikipedia o bot
    text = text.replaceAll(RegExp(r'^(Según Wikipedia,|Wikipedia informa que|En resumen:)\s*', caseSensitive: false), '');

    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }
}
