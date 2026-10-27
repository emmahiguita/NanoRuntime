import '../../personal_agent/application/personal_intent_router.dart';
import '../../personal_agent/domain/personal_intent.dart';
import '../language/whatsapp_text_normalizer.dart';
import 'conversation_topic.dart';
import 'conversation_topic_extractor.dart';
import 'dialogue_state_tracker.dart';

/// Quién es el sujeto principal de la acción o consulta en el turno actual.
enum UnderstandingSubject { user, nano, thirdParty, unspecified }

/// Tipo de acto discursivo detectado para guiar la comprensión del modelo.
enum UnderstandingDiscourseAct {
  taskQuery,
  taskAssignmentOrRole,
  followUpReference,
  correctionOrNegation,
  prohibition,
  preferenceAffirmation,
  multiPointParagraph,
  general,
}

/// Marco estructurado de comprensión lectora previo al LLM (`UnderstandingFrame`).
///
/// - **QUÉ HACE:** Analiza el mensaje entrante (desde un `"Hola"` hasta un
///   párrafo con múltiples preguntas) e identifica sujeto, referencias a turnos
///   anteriores, prohibiciones, gustos afirmados o párrafos multipunto.
/// - **CÓMO FUNCIONA:** Conserva `originalText` intacto, aplica normalización
///   tolerante a errores ([WhatsAppTextNormalizer]) y extrae el tema activo del
///   mismo chat sin mezclar conversaciones.
/// - **POR QUÉ:** Ayuda a que modelos compactos en LiteRT-LM no inviertan roles,
///   no pregunten lo que el usuario ya afirmó y respondan todos los puntos de un
///   párrafo largo con naturalidad.
final class UnderstandingFrame {
  final String conversationId;
  final String originalText;
  final String normalizedText;
  final UnderstandingDiscourseAct discourseAct;
  final UnderstandingSubject subject;
  final String? referencedTopicOrEntity;
  final bool isCorrectionOrNegation;
  final bool isProhibition;
  final bool requiresPriorTurnContext;

  const UnderstandingFrame({
    required this.conversationId,
    required this.originalText,
    required this.normalizedText,
    required this.discourseAct,
    required this.subject,
    this.referencedTopicOrEntity,
    this.isCorrectionOrNegation = false,
    this.isProhibition = false,
    this.requiresPriorTurnContext = false,
  });

  static final _prohibitionRegex = RegExp(
    r'\b(?:no\s+(?:hagas|digas|respondas|envies|mandes|uses|repitas)\s+(?:eso|asi|mas)|deja\s+de\s+(?:hacer|decir|repetir|usar))\b',
  );
  static final _nanoRoleRegex = RegExp(
    r'\b(?:eso\s+te\s+toca\s+a\s+ti|te\s+toca\s+a\s+ti|tu\s+eres\s+quien\s+debe|te\s+corresponde\s+a\s+ti|eso\s+lo\s+haces\s+tu|tu\s+debes\s+vigilar|encargate\s+tu)\b',
  );
  static final _correctionPrefixRegex = RegExp(
    r'^(?:no\b|pero\s+no\b|en\s+realidad\b|corrijo\b|me\s+referia\b|quise\s+decir\b|yo\s+soy\b)',
  );
  static final _shortFollowUpRegex = RegExp(
    r'^(?:y\s+)?(?:a\s+que\s+hora|como\s+quedo|en\s+que\s+quedo|que\s+paso\s+con\s+eso|y\s+eso|y\s+entonces|para\s+cuando|donde\s+fue|quien\s+dijo\s+eso)\b|'
    r'\b(?:lo\s+de\s+ayer|lo\s+que\s+hablamos|eso\s+que\s+dijiste|lo\s+de\s+[a-z]{3,})\b',
  );
  static final _preferenceRegex = RegExp(
    r'\b(?:me\s+(?:gusta|encanta|fascina|apasiona)\s+(?:el\s+|la\s+|los\s+|las\s+)?([a-z0-9\s]{3,25})|'
    r'soy\s+(?:fan|hincha|aficionado|aficionada)\s+(?:de|del)\s+([a-z0-9\s]{3,25}))',
  );
  static final _thirdPartyNameRegex = RegExp(
    r'\b(?:lo\s+de\s+|con\s+|dijo\s+|trae\s+|viene\s+)([A-ZÁÉÍÓÚÑ][a-záéíóúñ]{2,})\b',
  );

  /// Construye el [UnderstandingFrame] para el turno actual del chat.
  static UnderstandingFrame analyze({
    required String conversationId,
    required String rawText,
    List<String> recentInboundInSameChat = const [],
    ConversationDialogueState? dialogueState,
    ConversationTopic? activeTopic,
  }) {
    final normalized = WhatsAppTextNormalizer.normalizeForUnderstanding(rawText);
    final topic = _resolveTopic(
      rawText,
      recentInboundInSameChat,
      dialogueState,
      activeTopic,
    );

    if (_prohibitionRegex.hasMatch(normalized)) {
      return UnderstandingFrame(
        conversationId: conversationId,
        originalText: rawText,
        normalizedText: normalized,
        discourseAct: UnderstandingDiscourseAct.prohibition,
        subject: UnderstandingSubject.nano,
        referencedTopicOrEntity: topic,
        isCorrectionOrNegation: true,
        isProhibition: true,
        requiresPriorTurnContext: true,
      );
    }
    if (_nanoRoleRegex.hasMatch(normalized)) {
      final isNeg = normalized.startsWith('no ') || normalized.contains(' no ');
      return UnderstandingFrame(
        conversationId: conversationId,
        originalText: rawText,
        normalizedText: normalized,
        discourseAct: isNeg
            ? UnderstandingDiscourseAct.correctionOrNegation
            : UnderstandingDiscourseAct.taskAssignmentOrRole,
        subject: UnderstandingSubject.nano,
        referencedTopicOrEntity: topic,
        isCorrectionOrNegation: isNeg,
        requiresPriorTurnContext: true,
      );
    }
    final routedIntent = PersonalIntentRouter.route(rawText);
    if (routedIntent == PersonalIntent.nanoDailyPlan ||
        routedIntent == PersonalIntent.userDailyPlan ||
        routedIntent == PersonalIntent.userPendingTasks) {
      return UnderstandingFrame(
        conversationId: conversationId,
        originalText: rawText,
        normalizedText: normalized,
        discourseAct: UnderstandingDiscourseAct.taskQuery,
        subject: routedIntent == PersonalIntent.nanoDailyPlan
            ? UnderstandingSubject.nano
            : UnderstandingSubject.user,
        referencedTopicOrEntity: topic,
      );
    }
    if (_correctionPrefixRegex.hasMatch(normalized)) {
      return UnderstandingFrame(
        conversationId: conversationId,
        originalText: rawText,
        normalizedText: normalized,
        discourseAct: UnderstandingDiscourseAct.correctionOrNegation,
        subject: normalized.contains('tu ')
            ? UnderstandingSubject.nano
            : UnderstandingSubject.user,
        referencedTopicOrEntity: topic,
        isCorrectionOrNegation: true,
        requiresPriorTurnContext: true,
      );
    }
    if (_shortFollowUpRegex.hasMatch(normalized)) {
      final hasThirdParty =
          _thirdPartyNameRegex.hasMatch(rawText) ||
          recentInboundInSameChat.any(_thirdPartyNameRegex.hasMatch);
      return UnderstandingFrame(
        conversationId: conversationId,
        originalText: rawText,
        normalizedText: normalized,
        discourseAct: UnderstandingDiscourseAct.followUpReference,
        subject: hasThirdParty
            ? UnderstandingSubject.thirdParty
            : UnderstandingSubject.unspecified,
        referencedTopicOrEntity: topic,
        requiresPriorTurnContext: true,
      );
    }
    final prefMatch = _preferenceRegex.firstMatch(normalized);
    if (prefMatch != null && !rawText.contains('?')) {
      final pref = (prefMatch.group(1) ?? prefMatch.group(2) ?? '').trim();
      return UnderstandingFrame(
        conversationId: conversationId,
        originalText: rawText,
        normalizedText: normalized,
        discourseAct: UnderstandingDiscourseAct.preferenceAffirmation,
        subject: UnderstandingSubject.user,
        referencedTopicOrEntity: pref.isNotEmpty ? pref : topic,
      );
    }
    final isMultiPoint =
        rawText.length >= 110 ||
        RegExp(r'[.!?]\s+\S').allMatches(rawText).length >= 2;
    return UnderstandingFrame(
      conversationId: conversationId,
      originalText: rawText,
      normalizedText: normalized,
      discourseAct: isMultiPoint
          ? UnderstandingDiscourseAct.multiPointParagraph
          : UnderstandingDiscourseAct.general,
      subject: UnderstandingSubject.unspecified,
      referencedTopicOrEntity: topic,
    );
  }

  static String? _resolveTopic(
    String rawText,
    List<String> recentInbound,
    ConversationDialogueState? dialogueState,
    ConversationTopic? activeTopic,
  ) {
    final thirdParty = _thirdPartyNameRegex.firstMatch(rawText)?.group(1);
    if (thirdParty != null) return thirdParty;
    for (final candidate in [activeTopic, dialogueState?.activeTopic]) {
      if (candidate != null && candidate.isFresh()) {
        return candidate.keyEntities.isNotEmpty
            ? candidate.keyEntities.take(2).join(', ')
            : candidate.label;
      }
    }
    const extractor = ConversationTopicExtractor();
    for (final prev in recentInbound.reversed.take(3)) {
      if (prev.trim().isEmpty || prev.trim() == rawText.trim()) continue;
      final prevThird = _thirdPartyNameRegex.firstMatch(prev)?.group(1);
      final extracted = extractor.extractTopic(text: prev);
      if (prevThird != null) return prevThird;
      if (extracted != null && extracted.keyEntities.isNotEmpty) {
        return extracted.keyEntities.take(2).join(', ');
      }
      if (prev.trim().length <= 80) return prev.trim();
    }
    return null;
  }

  /// Genera la nota compacta de comprensión para inyectar en `<CONTEXTO DEL TURNO>`.
  String toCompactPromptBlock() => switch (discourseAct) {
    UnderstandingDiscourseAct.prohibition =>
      '[COMPRENSIÓN: prohibición directa al asistente. Acata con naturalidad sin repetir la acción rechazada.]',
    UnderstandingDiscourseAct.taskAssignmentOrRole ||
    UnderstandingDiscourseAct.correctionOrNegation =>
      subject == UnderstandingSubject.nano
          ? '[COMPRENSIÓN: el interlocutor indica que esa tarea te corresponde a ti (Nano). Confirma con naturalidad que tú te encargas.]'
          : '[COMPRENSIÓN: aclaración del interlocutor. Acéptala con naturalidad sin contradecirlo.]',
    UnderstandingDiscourseAct.followUpReference =>
      '[COMPRENSIÓN: pregunta de seguimiento sobre "${referencedTopicOrEntity ?? 'el turno anterior'}". Responde sobre ese mismo tema sin inventar horas no registradas.]',
    UnderstandingDiscourseAct.preferenceAffirmation =>
      '[COMPRENSIÓN: el interlocutor afirmó su gusto por "${referencedTopicOrEntity ?? 'ese tema'}". Comenta algo natural sin volver a preguntarle si le gusta.]',
    UnderstandingDiscourseAct.taskQuery =>
      subject == UnderstandingSubject.nano
          ? '[COMPRENSIÓN: pregunta por tus funciones actuales como Nano y los chats pendientes.]'
          : '[COMPRENSIÓN: pregunta por el horario o tareas del usuario hoy según su cronograma.]',
    UnderstandingDiscourseAct.multiPointParagraph =>
      '[COMPRENSIÓN: mensaje amplio con varias ideas o preguntas. Comprende todo el párrafo y responde a cada punto de forma natural y coherente.]',
    UnderstandingDiscourseAct.general => '',
  };
}
