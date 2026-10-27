// QUÉ: persiste en SQLite la asignación Personal/Negocios por conversación.
// CÓMO: serializa escrituras y actualiza la caché solo después de confirmar SQLite.
// POR QUÉ: una falla durable no debe dejar a la UI y al motor con agentes distintos.
library;

import '../storage/automation_db_store_client.dart';
import 'conversation_agent.dart';
import 'conversation_assignment_models.dart';
import 'conversation_key.dart';
import 'memory_conversation_assignment_store.dart';

final class SqliteConversationAssignmentStore
    extends MemoryConversationAssignmentStore {
  SqliteConversationAssignmentStore({AutomationDbStoreClient? client})
    : _client = client ?? AutomationDbStoreClient.instance;

  final AutomationDbStoreClient _client;
  Future<void>? _loading;
  Future<void> _writeTail = Future<void>.value();
  final Map<String, Future<ConversationAssignment>> _pending = {};

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
    final pending = _pending[key.id];
    if (pending != null) return pending;
    return _remember(
      key.id,
      _persistInitial(
        buildInitial(ConversationAddress.fromKey(key), 'canal inicial'),
      ),
    );
  }

  @override
  Future<ConversationAssignment> ensureAssignmentForConversationId(
    String conversationId,
  ) async {
    final current = assignmentFor(conversationId);
    if (current != null) return current;
    final pending = _pending[conversationId];
    if (pending != null) return pending;
    return _remember(
      conversationId,
      _persistInitial(
        buildInitial(
          ConversationAddress.fromConversationId(conversationId),
          'migración v1',
        ),
      ),
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
    final prior = _pending[conversationId];
    final operation = () async {
      if (prior != null) await prior;
      final previous = assignmentFor(conversationId);
      final next = ConversationAssignment(
        address:
            previous?.address ??
            ConversationAddress.fromConversationId(conversationId),
        agentId: target,
        assignedAtMs: atMs ?? DateTime.now().millisecondsSinceEpoch,
        reason: reason.trim(),
      );
      await _persist(next, previous: previous, minimalContext: minimalContext);
      assignments[conversationId] = next;
      return next;
    }();
    return _remember(conversationId, operation);
  }

  Future<ConversationAssignment> _persistInitial(
    ConversationAssignment assignment,
  ) async {
    await _persist(assignment);
    assignments[assignment.address.conversationId] = assignment;
    return assignment;
  }

  Future<void> _persist(
    ConversationAssignment assignment, {
    ConversationAssignment? previous,
    String minimalContext = '',
  }) async {
    final accepted = await _enqueueWrite(
      () => _client.assignConversation(
        addressKey: assignment.address.addressKey,
        scopeId: assignment.scope.id,
        ownerId: assignment.address.ownerId,
        agentId: assignment.agentId.name,
        previousAgentId: previous?.agentId.name,
        channel: assignment.address.channel,
        appPackage: assignment.address.appPackage,
        channelAccountId: assignment.address.channelAccountId,
        conversationId: assignment.address.conversationId,
        assignedAtMs: assignment.assignedAtMs,
        reason: assignment.reason,
        minimalContext: minimalContext,
      ),
    );
    if (!accepted) throw StateError('Assignment persistence rejected');
  }

  Future<bool> _enqueueWrite(Future<bool> Function() operation) {
    // Una operación fallida no envenena la cola: la siguiente aún puede persistir.
    final run = _writeTail.catchError((Object _) {}).then((_) => operation());
    _writeTail = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  Future<ConversationAssignment> _remember(
    String conversationId,
    Future<ConversationAssignment> operation,
  ) {
    _pending[conversationId] = operation;
    operation.then<void>(
      (_) {
        if (identical(_pending[conversationId], operation)) {
          _pending.remove(conversationId);
        }
      },
      onError: (Object _) {
        if (identical(_pending[conversationId], operation)) {
          _pending.remove(conversationId);
        }
      },
    );
    return operation;
  }
}
