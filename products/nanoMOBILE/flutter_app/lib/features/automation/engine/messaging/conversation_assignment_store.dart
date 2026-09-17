/// Asignación durable de conversaciones a Personal o Negocios.
///
/// La asignación se decide una vez, antes de responder, y permanece estable
/// hasta una transferencia explícita. El mensaje no puede cambiar de agente
/// por contener accidentalmente una palabra de ventas.
library;

import '../storage/automation_db_store_client.dart';
import 'conversation_agent.dart';
import 'conversation_key.dart';

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

/// Implementación pura para pruebas y previews.
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
    final address = ConversationAddress.fromKey(key);
    final assignment = ConversationAssignment(
      address: address,
      agentId: ConversationAgentId.defaultFor(
        channel: address.channel,
        appPackage: address.appPackage,
      ),
      assignedAtMs: DateTime.now().millisecondsSinceEpoch,
      reason: 'canal inicial',
    );
    assignments[key.id] = assignment;
    return assignment;
  }

  @override
  Future<ConversationAssignment> ensureAssignmentForConversationId(
    String conversationId,
  ) async {
    final current = assignments[conversationId];
    if (current != null) return current;
    final address = ConversationAddress.fromConversationId(conversationId);
    final assignment = ConversationAssignment(
      address: address,
      agentId: ConversationAgentId.defaultFor(
        channel: address.channel,
        appPackage: address.appPackage,
      ),
      assignedAtMs: DateTime.now().millisecondsSinceEpoch,
      reason: 'migración v1',
    );
    assignments[conversationId] = assignment;
    return assignment;
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
    final address =
        previous?.address ??
        ConversationAddress.fromConversationId(conversationId);
    final assignment = ConversationAssignment(
      address: address,
      agentId: target,
      assignedAtMs: atMs ?? DateTime.now().millisecondsSinceEpoch,
      reason: reason.trim(),
    );
    assignments[conversationId] = assignment;
    return assignment;
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
}

/// Persistencia normalizada en SQLite. La cache permite consultas síncronas
/// durante la composición; [load] forma parte de la barrera de hidratación.
final class SqliteConversationAssignmentStore
    extends MemoryConversationAssignmentStore {
  SqliteConversationAssignmentStore({AutomationDbStoreClient? client})
    : _client = client ?? AutomationDbStoreClient.instance;

  final AutomationDbStoreClient _client;
  Future<void>? _loading;
  Future<void> _writeTail = Future<void>.value();

  @override
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    final rows = await _client.listConversationAssignments();
    for (final row in rows) {
      final conversationId = row['conversationId'] as String? ?? '';
      if (conversationId.isEmpty) continue;
      final address = ConversationAddress(
        ownerId: row['ownerId'] as String? ?? ConversationAddress.localOwnerId,
        channel: row['channel'] as String? ?? '',
        appPackage: row['appPackage'] as String? ?? '',
        channelAccountId: row['channelAccountId'] as String? ?? '',
        conversationId: conversationId,
      );
      if (!address.isValid) continue;
      assignments[conversationId] = ConversationAssignment(
        address: address,
        agentId: ConversationAgentId.fromName(row['agentId'] as String? ?? ''),
        assignedAtMs: (row['assignedAtMs'] as num?)?.toInt() ?? 0,
        reason: row['reason'] as String? ?? '',
      );
    }
  }

  @override
  Future<ConversationAssignment> ensureAssignment(ConversationKey key) async {
    final current = assignmentFor(key.id);
    if (current != null) return current;
    final assignment = await super.ensureAssignment(key);
    await _persist(assignment);
    return assignment;
  }

  @override
  Future<ConversationAssignment> ensureAssignmentForConversationId(
    String conversationId,
  ) async {
    final current = assignmentFor(conversationId);
    if (current != null) return current;
    final assignment = await super.ensureAssignmentForConversationId(
      conversationId,
    );
    await _persist(assignment);
    return assignment;
  }

  @override
  Future<ConversationAssignment> transfer(
    String conversationId,
    ConversationAgentId target, {
    required String reason,
    String minimalContext = '',
    int? atMs,
  }) async {
    final previous = assignmentFor(conversationId);
    final next = await super.transfer(
      conversationId,
      target,
      reason: reason,
      minimalContext: minimalContext,
      atMs: atMs,
    );
    final write = _writeTail.then(
      (_) => _client.assignConversation(
        addressKey: next.address.addressKey,
        scopeId: next.scope.id,
        ownerId: next.address.ownerId,
        agentId: next.agentId.name,
        previousAgentId: previous?.agentId.name,
        channel: next.address.channel,
        appPackage: next.address.appPackage,
        channelAccountId: next.address.channelAccountId,
        conversationId: next.address.conversationId,
        assignedAtMs: next.assignedAtMs,
        reason: next.reason,
        minimalContext: minimalContext,
      ),
    );
    _writeTail = write.then<void>((ok) {
      if (!ok) throw StateError('Transfer persistence rejected');
    });
    await _writeTail;
    return next;
  }

  Future<void> _persist(ConversationAssignment assignment) async {
    final write = _writeTail.then(
      (_) => _client.assignConversation(
        addressKey: assignment.address.addressKey,
        scopeId: assignment.scope.id,
        ownerId: assignment.address.ownerId,
        agentId: assignment.agentId.name,
        channel: assignment.address.channel,
        appPackage: assignment.address.appPackage,
        channelAccountId: assignment.address.channelAccountId,
        conversationId: assignment.address.conversationId,
        assignedAtMs: assignment.assignedAtMs,
        reason: assignment.reason,
      ),
    );
    _writeTail = write.then<void>((ok) {
      if (!ok) throw StateError('Assignment persistence rejected');
    });
    await _writeTail;
  }
}
