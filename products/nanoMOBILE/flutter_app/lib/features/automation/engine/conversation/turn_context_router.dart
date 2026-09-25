/// QUÉ HACE:
/// Enruta y clasifica el contexto del turno entrante, detectando continuidades temáticas,
/// respuestas breves a preguntas previas ("sí", "M", "mañana") y elegibilidad para FastPath.
///
/// CÓMO FUNCIONA:
/// Analiza complejidad léxica, descompone mensajes en ráfagas (' · '), detecta acuses de recibo
/// y respuestas cortas de valor, e inspecciona la memoria previa para evitar desconectar
/// una respuesta corta de la pregunta comercial que la originó.
///
/// POR QUÉ:
/// Resuelve el error donde un usuario responde "M" o "sí" y el sistema lo toma como
/// un mensaje aislado sin asociarlo a la talla o confirmación que Nano acababa de solicitar.
library;

import '../business/fact_selector.dart' show normalizeText;
import '../language/conversation_semantic_tag.dart'
    show ConversationSemanticClassifier, ConversationSemanticTag;
import '../language/turn_complexity_classifier.dart'
    show TurnComplexity, turnComplexityClassifier;
import '../messaging/conversation_memory.dart'
    show ConversationMemory, ConversationMemoryEntryKind;
import '../notifications/notification_object.dart';

/// Contexto estructurado del turno analizado.
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
  });
}

/// Enrutador determinista del contexto de turno.
final class TurnContextRouter {
  const TurnContextRouter();

  static const _acknowledgmentTokens = {
    'ok', 'oka', 'okey', 'listo', 'lista', 'dale', 'de una', 'bueno', 'bien',
    'ya', 'perfecto', 'entendido', 'vale', 'claro', 'si', 'sip', 'sisas',
    'de acuerdo', 'comprendido', 'va', 'ta bien',
  };

  static const _shortValueTokens = {
    'xs', 's', 'm', 'l', 'xl', 'xxl', 'negro', 'blanca', 'blanco', 'azul',
    'rojo', 'roja', 'verde', 'hoy', 'manana', 'tarde', 'uno', 'dos', 'tres',
  };

  static const _anaphoricTokens = {
    'ella', 'el', 'eso', 'esa', 'ese', 'ahi', 'alli', 'le', 'les', 'lo', 'la',
    'cambié', 'cambie', 'dijo', 'llamo', 'llamó', 'acuerdas',
  };

  /// Analiza la notificación y la memoria previa para extraer el contexto del turno.
  TurnRoutingAnalysis analyze({
    required NotificationObject notification,
    required ConversationMemory? memory,
    required bool isBusinessChannel,
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
    final hasAnaphora =
        memory != null &&
        memory.entries.isNotEmpty &&
        _hasAnaphoricReference(targetText);
    final hasContinuity =
        hasAnaphora ||
        ((isShortAck || isShortVal) && _hasSubstantivePrecedingContext(memory));

    final hasCompoundOrSubstantiveTag =
        semanticTags.length >= 2 ||
        semanticTags.contains(ConversationSemanticTag.correction) ||
        semanticTags.contains(ConversationSemanticTag.request) ||
        semanticTags.contains(ConversationSemanticTag.question);

    final allFragmentsSocial =
        targetText == fullText ||
        fullText
            .split(RegExp(r'\s*[·\n]\s*'))
            .every(
              (frag) =>
                  frag.trim().isEmpty ||
                  turnComplexityClassifier
                      .classify(frag)
                      .eligibleForSocialPrompt,
            );

    final isFastPathEligible =
        !isBusinessChannel &&
        !hasContinuity &&
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
      final segments = inter.split(' · ').map((s) => s.trim()).where((s) => s.isNotEmpty);
      if (segments.isNotEmpty) return segments.last;
    }
    if (inter.isNotEmpty) return inter;

    final raw = notification.text.trim();
    if (raw.contains(' · ')) {
      final segments = raw.split(' · ').map((s) => s.trim()).where((s) => s.isNotEmpty);
      if (segments.isNotEmpty) return segments.last;
    }
    return raw;
  }

  static String _extractFullText(NotificationObject notification) {
    final inter = notification.interpretableText.trim();
    if (inter.isNotEmpty) return inter;
    return notification.text.trim();
  }

  static bool _isAcknowledgment(String text) {
    final clean = normalizeText(text)
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]+', unicode: true), '')
        .trim();
    return _acknowledgmentTokens.contains(clean);
  }

  static bool _isShortValue(String text) {
    final clean = normalizeText(text)
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]+', unicode: true), '')
        .trim();
    if (_shortValueTokens.contains(clean)) return true;
    return RegExp(r'^\d{1,4}$').hasMatch(clean);
  }

  static bool _hasSubstantivePrecedingContext(ConversationMemory? memory) {
    if (memory == null || memory.entries.isEmpty) return false;
    final entries = memory.entries;
    final limit = entries.length > 3 ? entries.length - 3 : 0;

    for (var i = entries.length - 1; i >= limit; i--) {
      final entry = entries[i];
      final text = entry.text.toLowerCase();

      if (entry.kind == ConversationMemoryEntryKind.outboundVerified ||
          entry.kind == ConversationMemoryEntryKind.outboundDispatched) {
        if (text.contains('?') ||
            text.contains('vale') ||
            text.contains('cuesta') ||
            text.contains('precio') ||
            text.contains('talla') ||
            text.contains('color') ||
            text.contains('envio') ||
            text.contains('disponible') ||
            text.contains('stock')) {
          return true;
        }
      }

      if (entry.kind == ConversationMemoryEntryKind.inbound) {
        if (text.contains('precio') ||
            text.contains('cuanto') ||
            text.contains('donde') ||
            text.contains('horario') ||
            text.contains('envio')) {
          return true;
        }
      }
    }
    return false;
  }
}
