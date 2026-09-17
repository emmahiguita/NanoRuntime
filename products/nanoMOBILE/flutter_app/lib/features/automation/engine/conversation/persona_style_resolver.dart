/// PERSONA STYLE RESOLVER
///
/// Resuelve respuestas mediante emparejamiento directo con el estilo real
/// del usuario registrado en FTS4 (pares condicionados incomingText -> body).
/// Cumple Clean Architecture y SOLID: < 200 líneas, sin LLM síncrono.
library;

import 'package:flutter/foundation.dart' show debugPrint;

import '../../personal_agent/application/persona_retriever.dart';
import '../../personal_agent/domain/persona_example.dart';
import '../business/fact_selector.dart' show normalizeText, tokenizeText;
import '../language/language_assist.dart';
import '../notifications/conversation_understanding.dart';

/// Resultado de una resolución de estilo por recuperación directa.
final class PersonaStyleMatch {
  final String reply;
  final double confidence;
  final ConversationUnderstanding understanding;
  final PersonaExample matchedExample;
  final List<String> suggestions;

  const PersonaStyleMatch({
    required this.reply,
    required this.confidence,
    required this.understanding,
    required this.matchedExample,
    this.suggestions = const [],
  });
}

/// Contrato para resolución de estilo personal sin LLM.
abstract interface class PersonaStyleResolver {
  Future<PersonaStyleMatch?> resolve({
    required String text,
    required String conversationId,
    String scopeKey = 'owner',
    double minConfidence = 0.65,
  });
}

/// Implementación por defecto usando [PersonaRetriever] de SQLite FTS4.
final class RuntimePersonaStyleResolver implements PersonaStyleResolver {
  const RuntimePersonaStyleResolver({
    required PersonaRetriever retriever,
  }) : _retriever = retriever;

  final PersonaRetriever _retriever;

  @override
  Future<PersonaStyleMatch?> resolve({
    required String text,
    required String conversationId,
    String scopeKey = 'owner',
    double minConfidence = 0.65,
  }) async {
    final cleanInput = text.trim();
    if (cleanInput.isEmpty) return null;

    final normalizedInput = normalizeText(cleanInput);
    final inputTokens = tokenizeText(normalizedInput);
    if (inputTokens.isEmpty) return null;

    try {
      final candidates = await _retriever.retrieve(
        cleanInput,
        limit: 4,
        scopeKey: scopeKey,
      );
      if (candidates.isEmpty) return null;

      PersonaExample? bestExample;
      var bestScore = 0.0;

      for (final cand in candidates) {
        if (!cand.isPaired || !cand.enabled) continue;

        final normalizedIncoming = normalizeText(cand.incomingText);
        final incomingTokens = tokenizeText(normalizedIncoming);
        if (incomingTokens.isEmpty) continue;

        // Coincidencia exacta normalizada
        if (normalizedInput == normalizedIncoming) {
          bestExample = cand;
          bestScore = 1.0;
          break;
        }

        // Jaccard similarity entre tokens
        final intersection = inputTokens.intersection(incomingTokens).length;
        final union = inputTokens.union(incomingTokens).length;
        final score = union > 0 ? intersection / union : 0.0;

        if (score > bestScore) {
          bestScore = score;
          bestExample = cand;
        }
      }

      if (bestExample == null || bestScore < minConfidence) {
        return null;
      }

      final rawReply = bestExample.body.trim();
      final cleanReply = LanguageAssistService.safeCleanOutput(rawReply);
      if (cleanReply.isEmpty) return null;

      debugPrint(
        '[style-resolver] HIT score=${bestScore.toStringAsFixed(2)} '
        'pair="${bestExample.incomingText}" -> "$cleanReply"',
      );

      final suggestions = <String>[cleanReply];
      for (final c in candidates) {
        if (c.id != bestExample.id && c.body.trim().isNotEmpty) {
          final s = LanguageAssistService.safeCleanOutput(c.body.trim());
          if (s.isNotEmpty && !suggestions.contains(s)) {
            suggestions.add(s);
          }
          if (suggestions.length >= 3) break;
        }
      }

      return PersonaStyleMatch(
        reply: cleanReply,
        confidence: bestScore,
        matchedExample: bestExample,
        suggestions: suggestions,
        understanding: ConversationUnderstanding(
          reply: cleanReply,
          options: suggestions,
          intent: 'persona_style_match',
          relation: 'responde',
          questions: const [],
          missingFacts: const [],
          requiresAction: false,
        ),
      );
    } on Object catch (e) {
      debugPrint('[style-resolver] error en recuperación: $e');
      return null;
    }
  }
}
