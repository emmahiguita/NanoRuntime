// QUÉ: define la asignación estable de una conversación a Personal o Negocios.
// CÓMO: expone un contrato independiente de SQLite y del estado en memoria.
// POR QUÉ: el contenido del mensaje nunca debe cambiar de agente implícitamente.
library;

import 'conversation_agent.dart';
import 'conversation_key.dart';

/// Resultado inmutable de asignar una conversación a un agente.
final class ConversationAssignment {
  final ConversationAddress address;
  final ConversationAgentId agentId;
  final int assignedAtMs;
  final String reason;

  const ConversationAssignment({
    required this.address,
    required this.agentId,
    required this.assignedAtMs,
    required this.reason,
  });

  AgentConversationScope get scope =>
      AgentConversationScope(address: address, agentId: agentId);
}

/// Puerto usado por composición, memoria y UI sin conocer la persistencia.
abstract interface class ConversationAssignmentStore {
  Future<void> load();

  ConversationAssignment? assignmentFor(String conversationId);

  Future<ConversationAssignment> ensureAssignment(ConversationKey key);

  Future<ConversationAssignment> ensureAssignmentForConversationId(
    String conversationId,
  );

  Future<ConversationAssignment> transfer(
    String conversationId,
    ConversationAgentId target, {
    required String reason,
    String minimalContext = '',
    int? atMs,
  });

  AgentConversationScope scopeForConversationId(String conversationId);

  ConversationAgentId agentForConversationId(String conversationId);
}
