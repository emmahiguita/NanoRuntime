// QUÉ: conserva asignaciones en memoria para consumidores síncronos.
// CÓMO: crea una asignación inicial por canal y solo cambia con transferencia explícita.
// POR QUÉ: separa la política de agente del mecanismo durable de SQLite.
library;

import 'conversation_agent.dart';
import 'conversation_assignment_models.dart';
import 'conversation_key.dart';

class MemoryConversationAssignmentStore implements ConversationAssignmentStore {
  final Map<String, ConversationAssignment> assignments = {};

  @override
  Future<void> load() async {}

  @override
  ConversationAssignment? assignmentFor(String conversationId) =>
      assignments[conversationId];

  @override
  Future<ConversationAssignment> ensureAssignment(ConversationKey key) async {
    final current = assignments[key.id];
    if (current != null) return current;
    return _cacheInitial(ConversationAddress.fromKey(key), 'canal inicial');
  }

  @override
  Future<ConversationAssignment> ensureAssignmentForConversationId(
    String conversationId,
  ) async {
    final current = assignments[conversationId];
    if (current != null) return current;
    return _cacheInitial(
      ConversationAddress.fromConversationId(conversationId),
      'migración v1',
    );
  }

  @override
  Future<ConversationAssignment> transfer(
    String conversationId,
    ConversationAgentId target, {
    required String reason,
    String minimalContext = '',
    int? atMs,
  }) async {
    if (conversationId.isEmpty || reason.trim().isEmpty) {
      throw ArgumentError('conversationId y reason son obligatorios');
    }
    final previous = assignments[conversationId];
    final next = ConversationAssignment(
      address:
          previous?.address ??
          ConversationAddress.fromConversationId(conversationId),
      agentId: target,
      assignedAtMs: atMs ?? DateTime.now().millisecondsSinceEpoch,
      reason: reason.trim(),
    );
    assignments[conversationId] = next;
    return next;
  }

  @override
  AgentConversationScope scopeForConversationId(String conversationId) {
    final current = assignments[conversationId];
    if (current != null) return current.scope;
    final address = ConversationAddress.fromConversationId(conversationId);
    return AgentConversationScope(
      address: address,
      agentId: ConversationAgentId.defaultFor(
        channel: address.channel,
        appPackage: address.appPackage,
      ),
    );
  }

  @override
  ConversationAgentId agentForConversationId(String conversationId) =>
      scopeForConversationId(conversationId).agentId;

  ConversationAssignment buildInitial(
    ConversationAddress address,
    String reason,
  ) => ConversationAssignment(
    address: address,
    agentId: ConversationAgentId.defaultFor(
      channel: address.channel,
      appPackage: address.appPackage,
    ),
    assignedAtMs: DateTime.now().millisecondsSinceEpoch,
    reason: reason,
  );

  ConversationAssignment _cacheInitial(
    ConversationAddress address,
    String reason,
  ) {
    final assignment = buildInitial(address, reason);
    assignments[address.conversationId] = assignment;
    return assignment;
  }
}
