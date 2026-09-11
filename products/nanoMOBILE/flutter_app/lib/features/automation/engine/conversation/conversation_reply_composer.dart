/// CANONICAL CONVERSATION COMPOSER
///
/// Unifica la comprensión y composición conversacional para WhatsApp:
/// modo automático (RuleDispatcher), modo sugerencias (PendingReplyStore),
/// y modo manual (NotificationAutomationSection / Responder mensajes).
///
/// Cumple Clean Architecture: pertenece a `engine/conversation/` y NUNCA
/// importa capas superiores (`application` o `presentation`).
library;

import 'package:flutter/foundation.dart' show debugPrint;

import '../language/language_assist.dart';
import '../language/pragmatic_fast_path.dart';
import '../messaging/conversation_key.dart' show resolveConversationIdentity;
import '../notifications/conversation_understanding.dart';
import '../notifications/notification_draft_writer.dart';
import '../notifications/notification_object.dart';
import '../../personal_agent/application/conversation_decision_engine.dart';
import '../../personal_agent/domain/conversation_agent_role.dart';
import '../../personal_agent/domain/conversation_decision.dart';

/// Resultado estructurado de la composición de respuesta.
/// Preserva la comprensión, la decisión y el texto final validado y reparado.
final class ConversationDraftResult {
  /// Texto final listo para presentar al usuario o despachar.
  final String text;

  /// Entendimiento estructurado factual del turno.
  final ConversationUnderstanding understanding;

  /// Decisión y políticas de calidad evaluadas por el DecisionEngine.
  final ConversationDecision decision;

  /// Rol determinado por el router canónico (personal, sales, etc.).
  final ConversationAgentRole role;

  /// ID canónico y aislado de la conversación.
  final String conversationId;

  /// true si fue resuelto determinísticamente sin invocar al LLM.
  final bool isFastPath;

  /// true si SafeConversationRepair modificó el texto por razones de calidad.
  final bool isRepaired;

  const ConversationDraftResult({
    required this.text,
    required this.understanding,
    required this.decision,
    required this.role,
    required this.conversationId,
    this.isFastPath = false,
    this.isRepaired = false,
  });

  bool get hasReply => text.trim().isNotEmpty;
}

/// Contrato único de composición conversacional para toda la aplicación.
abstract interface class ConversationReplyComposer {
  /// Compone un borrador contextual único garantizando:
  /// - Identidad y memoria aisladas por conversación
  /// - Personalidad y ejemplos FTS4
  /// - Hechos de negocio y estado
  /// - Decisión y reparación segura
  Future<ConversationDraftResult?> compose(
    NotificationObject notification, {
    ConversationDecisionContext? decisionContext,
  });

  /// Genera 2 o 3 variantes estilísticas basadas en la MISMA comprensión única.
  Future<List<String>> composeSuggestions(
    NotificationObject notification, {
    int maxSuggestions = 3,
    ConversationDecisionContext? decisionContext,
  });
}

/// Implementación concreta de producción de [ConversationReplyComposer].
final class RuntimeConversationReplyComposer
    implements ConversationReplyComposer {
  RuntimeConversationReplyComposer({
    required NotificationDraftSource draftSource,
    PragmaticFastPath? fastPath,
    ConversationDecisionEngine decisionEngine =
        const ConversationDecisionEngine(),
    Future<int> Function()? thermalStatus,
    ConversationDecisionContext Function(NotificationObject)? decisionContext,
  }) : _draftSource = draftSource,
       _fastPath = fastPath,
       _decisionEngine = decisionEngine,
       _thermalStatus = thermalStatus,
       _decisionContext = decisionContext;

  final NotificationDraftSource _draftSource;
  final PragmaticFastPath? _fastPath;
  final ConversationDecisionEngine _decisionEngine;
  final Future<int> Function()? _thermalStatus;
  final ConversationDecisionContext Function(NotificationObject)?
  _decisionContext;

  @override
  Future<ConversationDraftResult?> compose(
    NotificationObject notification, {
    ConversationDecisionContext? decisionContext,
  }) async {
    final identity = resolveConversationIdentity(notification);
    final conversationId = identity.key.id;
    final resolvedContext =
        decisionContext ??
        _decisionContext?.call(notification) ??
        const ConversationDecisionContext();

    debugPrint(
      '[conversation-compose] conv=${conversationId.length <= 8 ? conversationId : conversationId.substring(0, 8)} '
      'senderHash=${notification.sender.hashCode} inputLen=${notification.text.length}',
    );

    // 1. Pragmatic Fast Path: Saludos y agradecimientos puros (0 LLM, 0 latencia).
    // WA-INTENT-TURN: En WhatsApp, una notificación puede contener múltiples mensajes no
    // leídos concatenados con ' · ' (MessagingStyle). El Fast Path debe evaluar primordialmente
    // el último mensaje real entrante (interpretableText o el último segmento tras ' · ').
    final targetText = () {
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
    }();

    final fast = await _fastPath?.resolve(
      text: targetText,
      conversationId: conversationId,
    ) ?? (targetText != notification.text ? await _fastPath?.resolve(
      text: notification.text,
      conversationId: conversationId,
    ) : null);
    if (fast != null) {
      final cleaned = LanguageAssistService.safeCleanOutput(fast.reply);
      final decision = _decisionEngine.decide(
        understanding: fast.understanding,
        context: resolvedContext,
      );
      final isRepaired =
          decision.repairedText != null &&
          decision.repairedText!.trim().isNotEmpty;
      final finalText =
          isRepaired ? decision.repairedText!.trim() : cleaned.trim();

      debugPrint(
        '[conversation-compose:fastpath] act=${fast.act} reply="$finalText"',
      );

      return ConversationDraftResult(
        text: finalText,
        understanding: fast.understanding,
        decision: decision,
        role: resolvedContext.agentRole,
        conversationId: conversationId,
        isFastPath: true,
        isRepaired: isRepaired,
      );
    }

    // 2. Control térmico: CRITICAL+ (>=4) suprime la inferencia LLM opcional.
    // Constantes Android PowerManager: 0 none, 1 light, 2 moderate, 3 severe, 4 critical.
    // En dispositivos conectados a USB/cargador (Oppo/ColorOS), thermal=3 (severe) es habitual
    // y no debe apagar la automatización conversacional.
    final thermal = await _thermalStatus?.call();
    if (thermal != null && thermal >= 4) {
      debugPrint(
        '[conversation-compose] thermal $thermal (critical+): inferencia LLM suprimida',
      );
      return null;
    }

    // 3. Inferencia contextual completa vía RuntimeNotificationDraftWriter.
    final draft = await _draftSource(notification);
    if (draft == null || !draft.hasReply) {
      debugPrint('[conversation-compose] sin borrador producido por el motor');
      return null;
    }

    // 4. Limpieza determinista de salida (espacios y signos duplicados).
    final cleaned = LanguageAssistService.safeCleanOutput(draft.reply);
    if (cleaned.trim().isEmpty) {
      debugPrint(
        '[conversation-compose] borrador vacío tras limpieza de salida',
      );
      return null;
    }

    // 5. Decisión de calidad y reparación segura (SafeConversationRepair).
    final decision = _decisionEngine.decide(
      understanding: draft.understanding,
      context: resolvedContext,
    );
    final isRepaired =
        decision.repairedText != null &&
        decision.repairedText!.trim().isNotEmpty;
    final finalText =
        isRepaired ? decision.repairedText!.trim() : cleaned.trim();

    debugPrint(
      '[conversation-compose:llm] disposition=${decision.disposition.name} '
      'repaired=$isRepaired reply="$finalText"',
    );

    return ConversationDraftResult(
      text: finalText,
      understanding: draft.understanding,
      decision: decision,
      role: resolvedContext.agentRole,
      conversationId: conversationId,
      isFastPath: false,
      isRepaired: isRepaired,
    );
  }

  @override
  Future<List<String>> composeSuggestions(
    NotificationObject notification, {
    int maxSuggestions = 3,
    ConversationDecisionContext? decisionContext,
  }) async {
    // Exactamente UNA sola comprensión conversacional de partida.
    final baseResult = await compose(
      notification,
      decisionContext: decisionContext,
    );
    if (baseResult == null || !baseResult.hasReply) {
      return const [];
    }

    final baseText = baseResult.text.trim();
    final suggestions = <String>[baseText];

    // 1. Si es fast-path de saludo, ofrecer variantes cotidianas naturales.
    if (baseResult.isFastPath) {
      const naturalGreetings = [
        'Hola, ¿cómo estás?',
        'Buenas, ¿qué tal todo?',
        'Hola, un gusto saludarte.',
      ];
      for (final g in naturalGreetings) {
        if (!suggestions.contains(g) && suggestions.length < maxSuggestions) {
          suggestions.add(g);
        }
      }
      return suggestions.take(maxSuggestions).toList(growable: false);
    }

    // 2. Si el texto base contiene múltiples oraciones, generar variante concisa (primera oración).
    // Evitar truncar si la primera oración omite respuestas a preguntas del mensaje original (H-09).
    if (baseText.contains('.') ||
        baseText.contains('?') ||
        baseText.contains('!')) {
      final sentences = baseText
          .split(RegExp(r'(?<=[.?!])\s+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (sentences.length > 1) {
        final inputHasQuestions = notification.text.contains('?') ||
            notification.text.toLowerCase().contains('cuanto') ||
            notification.text.toLowerCase().contains('precio') ||
            notification.text.toLowerCase().contains('horario');
        final firstIsJustGreeting = sentences.first.length < 25 &&
            (sentences.first.toLowerCase().contains('hola') ||
                sentences.first.toLowerCase().contains('buenas'));

        final candidateSentence = (inputHasQuestions && firstIsJustGreeting && sentences.length > 1)
            ? sentences.sublist(1).join(' ')
            : sentences.first;

        final concise = LanguageAssistService.safeCleanOutput(candidateSentence);
        if (concise.isNotEmpty && !suggestions.contains(concise)) {
          suggestions.add(concise);
        }
      }
    }

    // 3. Variante sin partículas coloquiales directas (más sobria).
    if (suggestions.length < maxSuggestions) {
      final cleanFormal = LanguageAssistService.safeCleanOutput(
        baseText
            .replaceAll(
              RegExp(
                r'\b(parce|pana|jaja|jajaja|bro)\b',
                caseSensitive: false,
              ),
              '',
            )
            .replaceAll(RegExp(r'\s{2,}'), ' ')
            .trim(),
      );
      if (cleanFormal.isNotEmpty && !suggestions.contains(cleanFormal)) {
        suggestions.add(cleanFormal);
      }
    }

    return suggestions.take(maxSuggestions).toList(growable: false);
  }
}
