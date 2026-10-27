// conversation_memory_core.dart
//
// QUÉ HACE:
// Núcleo algorítmico en memoria (`_MemoryCore`) para gestión acotada de conversaciones,
// deduplicación, reconciliación de envíos y límites de capacidad.
//
// CÓMO FUNCIONA:
// - Mantiene mapas en memoria indexados por scopeId (paquete/cuenta).
// - Aplica evicción LRU (`_evictColdestIfNeeded`) cuando se supera `maxConversations`.
// - Trunca el historial a `maxEntriesPerConversation` (60 entradas más recientes).
// - Reconcilia mensajes observados de salida con confirmaciones verified o intervenciones manuales.
//
// POR QUÉ:
// Aplica Clean Architecture (SRP/DIP) separando el núcleo en memoria de la persistencia (< 175 líneas).

part of 'conversation_memory.dart';

abstract class _MemoryCore
    with _MemoryObligationsMixin
    implements ConversationMemoryStore {
  _MemoryCore({
    this.maxEntriesPerConversation = defaultMaxEntries,
    this.maxConversations = defaultMaxConversations,
    ConversationAssignmentStore? assignments,
  }) : _assignments = assignments;

  static const int defaultMaxEntries = 60;
  static const int defaultMaxConversations = 100;

  final int maxEntriesPerConversation;
  final int maxConversations;
  final ConversationAssignmentStore? _assignments;
  final Map<String, List<ConversationMemoryEntry>> _byConversation = {};
  final Map<String, String> _conversationIdByScope = {};
  final Map<String, ConversationAgentId> _agentByScope = {};
  bool _loaded = false;

  @override
  void _markDirty();
  void _persistNormalizedEntry(String scopeId, ConversationMemoryEntry entry) {}
  void _persistNormalizedState(String scopeId, ConversationMemory memory) {}
  @override
  void _persistStateFor(String conversationId) {
    final m = memoryFor(conversationId);
    if (m != null) _persistNormalizedState(m.scopeId, m);
  }

  @override
  String _scopeFor(String conversationId) {
    if (_assignments == null) return conversationId;
    final scope = _assignments.scopeForConversationId(conversationId);
    _conversationIdByScope[scope.id] = conversationId;
    _agentByScope[scope.id] = scope.agentId;
    return scope.id;
  }

  List<ConversationMemoryEntry> _listFor(String conversationId) {
    final scopeId = _scopeFor(conversationId);
    final list = _byConversation.putIfAbsent(scopeId, () => []);
    if (list.length >= maxEntriesPerConversation) {
      list.removeRange(0, list.length - maxEntriesPerConversation + 1);
    }
    return list;
  }

  void _evictColdestIfNeeded() {
    if (_byConversation.length <= maxConversations) return;
    String? coldest;
    int coldestAt = 0;
    for (final e in _byConversation.entries) {
      final at = e.value.isEmpty ? 0 : e.value.last.atMs;
      if (coldest == null || at < coldestAt) {
        coldest = e.key;
        coldestAt = at;
      }
    }
    if (coldest != null) {
      _byConversation.remove(coldest);
      _obligationsByConversation.remove(coldest);
      _topicByConversation.remove(coldest);
      _manualAtByConversation.remove(coldest);
      _conversationIdByScope.remove(coldest);
      _agentByScope.remove(coldest);
    }
  }

  @override
  ConversationMemory? memoryFor(String conversationId) {
    if (conversationId.isEmpty) return null;
    final scopeId = _scopeFor(conversationId);
    final list = _byConversation[scopeId];
    if (list == null || list.isEmpty) return null;
    return ConversationMemory(
      conversationId: conversationId,
      scopeId: scopeId,
      agentId: _agentByScope[scopeId],
      entries: List.unmodifiable(list),
      lastAtMs: list.last.atMs,
      unresolvedObligations: List.unmodifiable(
        _obligationsByConversation[scopeId] ?? const [],
      ),
      activeTopic: _topicByConversation[scopeId],
      lastManualInterventionMs: _manualAtByConversation[scopeId],
    );
  }

  @override
  Set<String> knownConversationIds({ConversationAgentId? agentId}) =>
      Set.unmodifiable(
        _byConversation.keys
            .where(
              (s) =>
                  _byConversation[s]!.isNotEmpty &&
                  (agentId == null || _agentByScope[s] == agentId),
            )
            .map((s) => _conversationIdByScope[s] ?? s),
      );

  @override
  Future<void> clearConversation(String conversationId) =>
      _clearConversationMemory(this, conversationId);

  /// Persiste el borrado completo. SQLite sobrescribe este hook para borrar
  /// el snapshot y las tablas normalizadas dentro de una misma transacción.
  Future<bool> _persistConversationRemoval(
    String scopeId,
    String snapshotJson,
  ) async => true;

  @override
  void appendInbound(IncomingMessage message, {required int atMs}) =>
      _appendInboundMemory(this, message, atMs);

  @override
  void appendOutbound(
    String conversationId,
    String text, {
    required ConversationMemoryEntryKind kind,
    String? ruleId,
    required int atMs,
  }) => _appendOutboundMemory(this, conversationId, text, kind, ruleId, atMs);

  @override
  void reconcileOutbound(
    String conversationId,
    String text, {
    required int atMs,
  }) => _reconcileOutboundMemory(this, conversationId, text, atMs);
}
