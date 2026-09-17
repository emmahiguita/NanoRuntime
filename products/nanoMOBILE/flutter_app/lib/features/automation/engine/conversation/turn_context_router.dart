/// TURN CONTEXT ROUTER
///
/// Enruta y estructura el contexto de un turno entrante en WhatsApp.
/// Analiza continuidad temática (evita responder solo al "ok" tras un pedido de precio),
/// detecta mensajes en ráfaga (MessagingStyle ' · ') y determina el rol del turno.
/// Cumple Clean Architecture y SOLID: < 220 líneas.
library;

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
  final bool isShortAcknowledgment;
  final bool hasContextualContinuity;
  final bool isFastPathEligible;

  const TurnRoutingAnalysis({
    required this.targetText,
    required this.fullText,
    required this.targetComplexity,
    required this.fullComplexity,
    required this.isShortAcknowledgment,
    required this.hasContextualContinuity,
    required this.isFastPathEligible,
  });
}

/// Enrutador determinista del contexto de turno.
final class TurnContextRouter {
  const TurnContextRouter();

  static const _acknowledgmentTokens = {
    'ok',
    'oka',
    'okey',
    'listo',
    'lista',
    'dale',
    'de una',
    'bueno',
    'bien',
    'ya',
    'perfecto',
    'entendido',
    'vale',
    'claro',
    'si',
    'sip',
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

    final isShortAck = _isAcknowledgment(targetText);
    final hasContinuity = isShortAck && _hasSubstantivePrecedingContext(memory);

    // FastPath solo se permite cuando:
    // 1. No es canal business.
    // 2. El mensaje objetivo califica como social mínimo.
    // 3. No hay señales narrativas/contextuales/complejas en el turno completo.
    // 4. NO es una confirmación corta que hereda un hilo previo sustantivo (evita bug precio+ok).
    final allFragmentsSocial = targetText == fullText ||
        fullText.split(RegExp(r'\s*[·\n]\s*')).every(
          (frag) =>
              frag.trim().isEmpty ||
              turnComplexityClassifier.classify(frag).eligibleForSocialPrompt,
        );

    final isFastPathEligible = !isBusinessChannel &&
        !hasContinuity &&
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
      isShortAcknowledgment: isShortAck,
      hasContextualContinuity: hasContinuity,
      isFastPathEligible: isFastPathEligible,
    );
  }

  /// Extrae el texto relevante del último fragmento de ráfaga o notificación.
  static String _extractTargetText(NotificationObject notification) {
    final inter = notification.interpretableText.trim();
    if (inter.contains(' · ')) {
      final segments = inter
          .split(' · ')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);
      if (segments.isNotEmpty) return segments.last;
    }
    if (inter.isNotEmpty) return inter;

    final raw = notification.text.trim();
    if (raw.contains(' · ')) {
      final segments = raw
          .split(' · ')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);
      if (segments.isNotEmpty) return segments.last;
    }
    return raw;
  }

  /// Extrae el texto completo consolidado.
  static String _extractFullText(NotificationObject notification) {
    final inter = notification.interpretableText.trim();
    if (inter.isNotEmpty) return inter;
    return notification.text.trim();
  }

  /// Comprueba si el texto es un acuse de recibo o confirmación corta ("ok", "dale", etc.).
  static bool _isAcknowledgment(String text) {
    final clean = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]+', unicode: true), '')
        .trim();
    return _acknowledgmentTokens.contains(clean);
  }

  /// Inspecciona si la conversación venía de una pregunta sustantiva o comercial.
  static bool _hasSubstantivePrecedingContext(ConversationMemory? memory) {
    if (memory == null || memory.entries.isEmpty) return false;

    // Buscar hacia atrás en los últimos 3 mensajes
    final entries = memory.entries;
    final limit = entries.length > 3 ? entries.length - 3 : 0;

    for (var i = entries.length - 1; i >= limit; i--) {
      final entry = entries[i];
      final text = entry.text.toLowerCase();

      // Si el mensaje anterior fue un outbound con pregunta o catálogo
      if (entry.kind == ConversationMemoryEntryKind.outboundVerified ||
          entry.kind == ConversationMemoryEntryKind.outboundDispatched) {
        if (text.contains('?') ||
            text.contains('vale') ||
            text.contains('cuesta') ||
            text.contains('precio') ||
            text.contains('disponible') ||
            text.contains('stock')) {
          return true;
        }
      }

      // Si el usuario anterior preguntó algo sustantivo
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
