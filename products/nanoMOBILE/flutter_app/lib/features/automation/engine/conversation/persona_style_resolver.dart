/// PERSONA STYLE RESOLVER
///
/// Resuelve respuestas mediante emparejamiento directo con el estilo real
/// del usuario registrado en FTS4 (pares condicionados incomingText -> body).
/// Cumple Clean Architecture y SOLID: < 200 líneas, sin LLM síncrono.
library;

import 'package:flutter/foundation.dart' show debugPrint;

import '../../personal_agent/application/conversation_decision_guards.dart';
import '../../personal_agent/application/persona_retriever.dart';
import '../../personal_agent/domain/persona_example.dart';
import '../../personal_agent/domain/conversation_agent_message_classifier.dart'
    show isLiveStateQuestion;
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
  RuntimePersonaStyleResolver({required PersonaRetriever retriever})
    : _retriever = retriever;

  final PersonaRetriever _retriever;
  final Map<String, int> _lastVariantByConversation = {};

  @override
  Future<PersonaStyleMatch?> resolve({
    required String text,
    required String conversationId,
    String scopeKey = 'owner',
    double minConfidence = 0.65,
  }) async {
    final cleanInput = text.trim();
    if (cleanInput.isEmpty) return null;
    // Una respuesta histórica enseña estilo, pero no prueba ubicación,
    // actividad, comida, disponibilidad ni otro estado actual del dueño.
    if (isLiveStateQuestion(cleanInput)) return null;

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
      List<String> bestReusableVariants = const [];
      var bestScore = 0.0;

      for (final cand in candidates) {
        if (!cand.canReuseLiterally || !cand.enabled) continue;
        final safeVariants = cand.reusableVariants(
          ConversationDecisionGuards.affirmsOwnerActivity,
        );
        if (safeVariants.isEmpty) continue;

        final score = PersonaRetriever.scoreExample(cleanInput, cand);
        if (score > bestScore) {
          bestScore = score;
          bestExample = cand;
          bestReusableVariants = safeVariants;
        }
      }

      if (bestExample == null ||
          bestReusableVariants.isEmpty ||
          bestScore < minConfidence) {
        return null;
      }

      final variants = bestReusableVariants;
      final String rawReply;
      final suggestions = <String>[];

      if (variants.length > 1) {
        // La primera opción depende de la conversación; las siguientes rotan
        // sin repetir consecutivamente la misma respuesta aprendida.
        final rotationKey = '$conversationId:${bestExample.id}';
        final previous = _lastVariantByConversation[rotationKey];
        final selectedIndex = previous == null
            ? conversationId.hashCode.abs() % variants.length
            : (previous + 1) % variants.length;
        if (_lastVariantByConversation.length >= 128) {
          _lastVariantByConversation.remove(
            _lastVariantByConversation.keys.first,
          );
        }
        _lastVariantByConversation[rotationKey] = selectedIndex;
        rawReply = variants[selectedIndex];
        for (final v in variants) {
          final clean = LanguageAssistService.safeCleanOutput(v);
          if (clean.isNotEmpty && !suggestions.contains(clean)) {
            suggestions.add(clean);
          }
        }
      } else {
        rawReply = variants.first;
      }

      final cleanReply = LanguageAssistService.safeCleanOutput(rawReply);
      if (cleanReply.isEmpty) return null;
      if (!suggestions.contains(cleanReply)) suggestions.insert(0, cleanReply);

      debugPrint(
        '[style-resolver] HIT score=${bestScore.toStringAsFixed(2)} '
        'pair="${bestExample.incomingText}" -> "$cleanReply" (${variants.length} variantes)',
      );

      for (final c in candidates) {
        if (c.id == bestExample.id || !c.canReuseLiterally) continue;
        final safeOther = c.reusableVariants(
          ConversationDecisionGuards.affirmsOwnerActivity,
        );
        for (final body in safeOther) {
          final s = LanguageAssistService.safeCleanOutput(body);
          if (s.isNotEmpty && !suggestions.contains(s)) {
            suggestions.add(s);
          }
          if (suggestions.length >= 5) break;
        }
        if (suggestions.length >= 5) break;
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
