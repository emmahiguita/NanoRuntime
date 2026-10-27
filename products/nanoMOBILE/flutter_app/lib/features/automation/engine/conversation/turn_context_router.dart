import '../business/fact_selector.dart' show normalizeText;
import '../language/conversation_semantic_tag.dart'
    show ConversationSemanticClassifier, ConversationSemanticTag;
import '../language/turn_complexity_classifier.dart'
    show TurnComplexity, turnComplexityClassifier;
import '../messaging/conversation_memory.dart' show ConversationMemory;
import '../notifications/notification_object.dart';
import 'dialogue_state_tracker.dart' show ConversationDialogueState;

/// Resultado inmutable del análisis de enrutamiento de un turno entrante.
///
/// - **QUÉ HACE:** Agrupa el texto completo interpretable, su complejidad y
///   banderas de continuidad conversacional.
/// - **CÓMO FUNCIONA:** Separa el texto objetivo ([targetText]) de las señales
///   semánticas ([semanticTags]) para que el motor decida cómo responder.
/// - **POR QUÉ:** Evita recalcular expresiones regulares en distintas capas.
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

/// Enrutador de contexto por turno para conversaciones de WhatsApp y chat local.
///
/// - **QUÉ HACE:** Clasifica el mensaje entrante desde un simple `"Hola"` hasta
///   un párrafo largo o ráfaga de varios mensajes (`" · "`).
/// - **CÓMO FUNCIONA:** Conserva todos los fragmentos sustantivos del turno
///   (sin recortar solo el último fragmento) y detecta correferencias y preguntas.
/// - **POR QUÉ:** Si un contacto envía varias oraciones seguidas, Nano debe
///   comprender el mensaje íntegro y no perder el contexto inicial.
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

  /// Analiza la notificación entrante junto con la memoria de la conversación.
  ///
  /// - **QUÉ HACE:** Determina complejidad, continuidad y texto completo a responder.
  /// - **CÓMO FUNCIONA:** Evalúa anáforas, preguntas pendientes y etiquetas semánticas.
  /// - **POR QUÉ:** Permite que el generador LiteRT-LM reciba todo el contexto.
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
    final hasAnaphora =
        memory != null &&
        memory.entries.isNotEmpty &&
        _hasAnaphoricReference(targetText);
    final hasSubstantivePreceding = _hasSubstantivePrecedingContext(
      memory,
      dialogueState,
    );
    final hasContinuity =
        hasAnaphora ||
        (hasPendingQ && !isSocialTurn) ||
        isClarification ||
        ((isShortAck || isShortVal) && hasSubstantivePreceding && !isSocialTurn);
    final hasCompoundOrSubstantiveTag =
        !isSocialTurn &&
        (semanticTags.length >= 2 ||
            semanticTags.contains(ConversationSemanticTag.correction) ||
            semanticTags.contains(ConversationSemanticTag.request) ||
            semanticTags.contains(ConversationSemanticTag.question));

    final isFastPathEligible =
        !isBusinessChannel &&
        !hasContinuity &&
        !isClarification &&
        !hasCompoundOrSubstantiveTag &&
        targetComplexity.eligibleForSocialPrompt &&
        !fullComplexity.isNarrative &&
        !fullComplexity.isContextual &&
        !fullComplexity.isComplex;

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

  /// Extrae el texto objetivo preservando todas las ideas de una ráfaga o párrafo.
  static String _extractTargetText(NotificationObject notification) {
    final base = _extractFullText(notification);
    if (!base.contains(' · ')) return base;
    final parts = base
        .split(' · ')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return base;
    if (parts.length == 1) return parts.first;
    return parts.join('. ');
  }

  static String _extractFullText(NotificationObject notification) {
    final inter = notification.interpretableText.trim();
    return inter.isNotEmpty ? inter : notification.text.trim();
  }

  static bool _hasAnaphoricReference(String text) {
    final words = normalizeText(text)
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toSet();
    return words.any(_anaphoricTokens.contains);
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
    return _shortValueTokens.contains(clean) ||
        RegExp(r'^\d{1,4}$').hasMatch(clean);
  }

  static bool _hasSubstantivePrecedingContext(
    ConversationMemory? memory,
    ConversationDialogueState? state,
  ) {
    if (state != null &&
        (state.hasPendingQuestion ||
            (state.lastAgentStatement?.isNotEmpty ?? false))) {
      return true;
    }
    if (memory == null || memory.entries.isEmpty) return false;
    final entries = memory.entries;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (entries.last.atMs > 0 && (now - entries.last.atMs).abs() < 900000) {
      return true;
    }
    final limit = entries.length > 3 ? entries.length - 3 : 0;
    for (var i = entries.length - 1; i >= limit; i--) {
      if (entries[i].text.contains('?')) return true;
    }
    return false;
  }
}
