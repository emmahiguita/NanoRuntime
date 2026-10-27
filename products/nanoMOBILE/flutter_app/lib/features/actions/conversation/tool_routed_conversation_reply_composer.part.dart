part of 'conversation_actions.dart';

/// Production bridge: every conversation composition enters the formal
/// ToolRouter while the actual intelligence remains in the existing composer.
final class ToolRoutedConversationReplyComposer
    implements ConversationReplyComposer {
  const ToolRoutedConversationReplyComposer(this.router);

  final ToolRouter router;

  @override
  // Composición automática conserva su evento y el control de deduplicación.
  Future<ConversationDraftResult?> compose(
    NotificationObject notification, {
    ConversationDecisionContext? decisionContext,
  }) async {
    final output = await _dispatch(notification, decisionContext);
    return output is ConversationDraftResult ? output : null;
  }

  // Mantiene ToolRouter y permisos también para previews; no impone Personal
  // si el caller no dio contexto: el compositor resuelve la asignación real.
  Future<Object?> _dispatch(
    NotificationObject notification,
    ConversationDecisionContext? decisionContext, {
    bool previewOnly = false,
  }) async {
    final identity = resolveConversationIdentity(notification);
    final eventId = IncomingMessage.fromNotification(notification).eventId;
    final result = await router.dispatchTyped(
      TypedToolRequest(
        toolId: 'conversation.composePersonal',
        arguments: ComposePersonalReplyArguments(
          notification: notification,
          decisionContext: decisionContext,
          previewOnly: previewOnly,
        ),
        caller: const AgentIdentity(role: AgentCallerRole.system),
        environment: ToolExecutionEnvironment(
          mode: previewOnly
              ? ToolExecutionMode.foreground
              : ToolExecutionMode.background,
          userPresent: previewOnly,
        ),
        conversation: ToolConversationIdentity(
          id: identity.key.id,
          platform: notification.packageName,
          participant: notification.sender,
        ),
        // La regeneración manual es una solicitud nueva, no replay del inbound.
        correlationId: previewOnly
            ? 'preview:$eventId:${DateTime.now().microsecondsSinceEpoch}'
            : eventId,
      ),
    );
    if (!result.executionSucceeded) return null;
    return result.output;
  }

  @override
  // Solo devuelve las variantes del modelo: esta ruta no envía ni marca eventos.
  Future<List<String>> composeSuggestions(
    NotificationObject notification, {
    int maxSuggestions = 3,
    ConversationDecisionContext? decisionContext,
  }) async {
    if (maxSuggestions <= 0) return const [];
    final output = await _dispatch(
      notification,
      decisionContext,
      previewOnly: true,
    );
    return output is List
        ? output
              .whereType<String>()
              .take(maxSuggestions)
              .toList(growable: false)
        : const [];
  }
}
