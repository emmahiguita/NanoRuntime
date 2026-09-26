// turn_context_router.dart
// QUÉ HACE: Enruta y clasifica el contexto del turno entrante (continuidad, respuestas breves y FastPath).
// CÓMO FUNCIONA: Analiza complejidad léxica, etiquetas semánticas y memoria previa sin bloquear el hilo.
// POR QUÉ: Cumple SOLID, Clean Architecture y límite estricto < 200 líneas.
library;

import '../business/fact_selector.dart' show normalizeText;
import '../language/conversation_semantic_tag.dart'
    show ConversationSemanticClassifier, ConversationSemanticTag;
import '../language/turn_complexity_classifier.dart'
    show TurnComplexity, turnComplexityClassifier;
import '../messaging/conversation_memory.dart' show ConversationMemory;
import '../notifications/notification_object.dart';

import 'dialogue_state_tracker.dart' show ConversationDialogueState;

final class TurnRoutingAnalysis {
  final String targetText;
  final String fullText;
  final TurnComplexity targetComplexity;
  final TurnComplexity fullComplexity;
  final Set<ConversationSemanticTag> semanticTags;
  final bool isShortAcknowledgment;
  final bool isShortValueAnswer;
  final bool hasContextualContinuity;
  final bool hasEntityContinuity;
  final bool isFastPathEligible;
  final bool isClarificationRequest;

  const TurnRoutingAnalysis({
    required this.targetText,
    required this.fullText,
    required this.targetComplexity,
    required this.fullComplexity,
    this.semanticTags = const {},
    required this.isShortAcknowledgment,
    this.isShortValueAnswer = false,
    required this.hasContextualContinuity,
    this.hasEntityContinuity = false,
    required this.isFastPathEligible,
    this.isClarificationRequest = false,
  });
}

final class TurnContextRouter {
  const TurnContextRouter();

  static const _acknowledgmentTokens = {
    'ok', 'oka', 'okey', 'listo', 'lista', 'dale', 'de una', 'bueno', 'bien',
    'ya', 'perfecto', 'entendido', 'vale', 'claro', 'si', 'sip', 'sisas',
    'de acuerdo', 'comprendido', 'va', 'ta bien', 'no', 'nop', 'para nada',
  };

  static const _shortValueTokens = {
    'xs', 's', 'm', 'l', 'xl', 'xxl', 'negro', 'blanca', 'blanco', 'azul',
    'rojo', 'roja', 'verde', 'hoy', 'manana', 'tarde', 'uno', 'dos', 'tres',
  };

  static const _anaphoricTokens = {
    'ella', 'el', 'eso', 'esa', 'ese', 'ahi', 'alli', 'le', 'les', 'lo', 'la',
    'cambié', 'cambie', 'dijo', 'llamo', 'llamó', 'acuerdas',
  };

  static final _clarificationRegex = RegExp(
    r'^(?:[¿¡]?\s*(?:qu[eé]|c[oó]mo|qui[eé]n|cu[aá]l|d[oó]nde|por\s+qu[eé]|c[oó]mo\s+as[ií])[\s.,!?]*)$',
    caseSensitive: false,
  );

  TurnRoutingAnalysis analyze({
    required NotificationObject notification,
    required ConversationMemory? memory,
    required bool isBusinessChannel,
    ConversationDialogueState? dialogueState,
  }) {
    final targetText = _extractTargetText(notification);
    final fullText = _extractFullText(notification);
    final targetComplexity = turnComplexityClassifier.classify(targetText);
    final fullComplexity = targetText == fullText
        ? targetComplexity
        : turnComplexityClassifier.classify(fullText);
    final semanticTags = ConversationSemanticClassifier.classifyAll(fullText);

    final isShortAck = _isAcknowledgment(targetText);
    final isShortVal = _isShortValue(targetText);
    final isClarification = _clarificationRegex.hasMatch(targetText.trim());
    final isSocialTurn = targetComplexity.isSocialMinimal;
    final hasPendingQ = dialogueState?.hasPendingQuestion ?? false;
    final hasAnaphora = memory != null &&
        memory.entries.isNotEmpty &&
        _hasAnaphoricReference(targetText);
    final hasSubstantivePreceding = _hasSubstantivePrecedingContext(memory, dialogueState);
    final hasContinuity = hasAnaphora ||
        (hasPendingQ && !isSocialTurn) ||
        isClarification ||
        ((isShortAck || isShortVal) && hasSubstantivePreceding && !isSocialTurn);
    final hasCompoundOrSubstantiveTag = !isSocialTurn &&
        (semanticTags.length >= 2 ||
            semanticTags.contains(ConversationSemanticTag.correction) ||
            semanticTags.contains(ConversationSemanticTag.request) ||
            semanticTags.contains(ConversationSemanticTag.question));

    final allFragmentsSocial = targetText == fullText ||
        fullText.split(RegExp(r'\s*[·\n]\s*')).every(
              (frag) =>
                  frag.trim().isEmpty ||
                  turnComplexityClassifier
                      .classify(frag)
                      .eligibleForSocialPrompt,
            );

    final isFastPathEligible = !isBusinessChannel &&
        !hasContinuity &&
        !isClarification &&
        !hasCompoundOrSubstantiveTag &&
        targetComplexity.eligibleForSocialPrompt &&
        !fullComplexity.isNarrative &&
        !fullComplexity.isContextual &&
        !fullComplexity.isComplex &&
        allFragmentsSocial;

    return TurnRoutingAnalysis(
      targetText: targetText,
      fullText: fullText,
      targetComplexity: targetComplexity,
      fullComplexity: fullComplexity,
      semanticTags: semanticTags,
      isShortAcknowledgment: isShortAck,
      isShortValueAnswer: isShortVal,
      hasContextualContinuity: hasContinuity,
      hasEntityContinuity: hasAnaphora,
      isFastPathEligible: isFastPathEligible,
      isClarificationRequest: isClarification,
    );
  }

  static bool _hasAnaphoricReference(String text) {
    final words = normalizeText(text)
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toSet();
    return words.any(_anaphoricTokens.contains);
  }

  static String _extractTargetText(NotificationObject notification) {
    final inter = notification.interpretableText.trim();
    if (inter.contains(' · ')) {
      final s = inter.split(' · ').map((e) => e.trim()).where((e) => e.isNotEmpty);
      if (s.isNotEmpty) return s.last;
    }
    if (inter.isNotEmpty) return inter;
    final raw = notification.text.trim();
    if (raw.contains(' · ')) {
      final s = raw.split(' · ').map((e) => e.trim()).where((e) => e.isNotEmpty);
      if (s.isNotEmpty) return s.last;
    }
    return raw;
  }

  static String _extractFullText(NotificationObject notification) {
    final inter = notification.interpretableText.trim();
    return inter.isNotEmpty ? inter : notification.text.trim();
  }

  static bool _isAcknowledgment(String text) => _acknowledgmentTokens.contains(
        normalizeText(text)
            .replaceAll(RegExp(r'[^\p{L}\p{N}\s]+', unicode: true), '')
            .trim(),
      );

  static bool _isShortValue(String text) {
    final clean = normalizeText(text)
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]+', unicode: true), '')
        .trim();
    return _shortValueTokens.contains(clean) || RegExp(r'^\d{1,4}$').hasMatch(clean);
  }

  static bool _hasSubstantivePrecedingContext(
    ConversationMemory? memory,
    ConversationDialogueState? state,
  ) {
    if (state != null && (state.hasPendingQuestion || (state.lastAgentStatement?.isNotEmpty ?? false))) {
      return true;
    }
    if (memory == null || memory.entries.isEmpty) return false;
    final entries = memory.entries;
    final last = entries.last;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (last.atMs > 0 && (now - last.atMs).abs() < 900000) return true;
    final limit = entries.length > 3 ? entries.length - 3 : 0;
    for (var i = entries.length - 1; i >= limit; i--) {
      if (entries[i].text.contains('?')) return true;
    }
    return false;
  }
}
