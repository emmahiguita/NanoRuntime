import '../../engine/messaging/conversation_assignment_models.dart';
import '../../engine/messaging/conversation_hub_providers.dart';
import '../../engine/messaging/conversation_agent.dart';
import 'messaging_conversation_keys.dart';

/// Usa la transferencia persistida, no la intención del texto, para etiquetar al agente.
ConversationAgentId messagingAssignedAgent(
  ConversationSummaryItem item,
  ConversationAssignmentStore store,
) {
  ConversationAssignment? assignment;
  for (final key in messagingConversationKeys(item)) {
    final found = store.assignmentFor(key);
    if (found != null &&
        (assignment == null || found.assignedAtMs > assignment.assignedAtMs)) {
      assignment = found;
    }
  }
  return assignment?.agentId ?? item.agentId;
}
