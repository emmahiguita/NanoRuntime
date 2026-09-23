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
// Aplica Clean Architecture (SRP/DIP) separando el núcleo en memoria de la persistencia (< 200 líneas).

part of 'conversation_memory.dart';

abstract class _MemoryCore with _MemoryObligationsMixin implements ConversationMemoryStore {
  _MemoryCore({
    this.maxEntriesPerConversation = defaultMaxEntries,
    this.maxConversations = defaultMaxConversations,
    ConversationAssignmentStore? assignments,
  }) : _assignments = assignments;

  static const int defaultMaxEntries = 60;
  static const int defaultMaxConversations = 100;
  static const int _maxTextField = 2000;

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
    final memory = memoryFor(conversationId);
    if (memory != null) _persistNormalizedState(memory.scopeId, memory);
  }

  static String _boundText(String raw) =>
      raw.length <= _maxTextField ? raw : raw.substring(0, _maxTextField);

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
      unresolvedObligations: List.unmodifiable(_obligationsByConversation[scopeId] ?? const []),
      activeTopic: _topicByConversation[scopeId],
      lastManualInterventionMs: _manualAtByConversation[scopeId],
    );
  }

  @override
  Set<String> knownConversationIds({ConversationAgentId? agentId}) => Set.unmodifiable(
        _byConversation.keys
            .where((s) => _byConversation[s]!.isNotEmpty && (agentId == null || _agentByScope[s] == agentId))
            .map((s) => _conversationIdByScope[s] ?? s),
      );

  @override
  void appendInbound(IncomingMessage message, {required int atMs}) {
    if (message.conversation.key.id.isEmpty || message.text.trim().isEmpty) return;
    final convId = message.conversation.key.id;
    final scopeId = _scopeFor(convId);
    final eventId = message.eventId.trim();
    if (eventId.isNotEmpty && (_byConversation[scopeId]?.any((e) => e.eventId == eventId) ?? false)) return;
    final cleanText = _boundText(message.text.trim());
    if (_byConversation[scopeId]?.any((e) =>
            e.kind == ConversationMemoryEntryKind.inbound &&
            e.text == cleanText &&
            (atMs - e.atMs).abs() <= 1000) ??
        false) {
      return;
    }

    final entry = ConversationMemoryEntry(
      kind: ConversationMemoryEntryKind.inbound,
      text: _boundText(message.text),
      sender: _boundText(message.sender),
      atMs: atMs,
      eventId: message.eventId,
    );
    _listFor(convId).add(entry);
    _persistNormalizedEntry(scopeId, entry);
    _evictColdestIfNeeded();
    _markDirty();
  }

  @override
  void appendOutbound(
    String conversationId,
    String text, {
    required ConversationMemoryEntryKind kind,
    String? ruleId,
    required int atMs,
  }) {
    if (conversationId.isEmpty || text.trim().isEmpty) return;
    final clean = text.trim();
    final scopeId = _scopeFor(conversationId);
    final entry = ConversationMemoryEntry(
      kind: kind,
      text: _boundText(clean),
      atMs: atMs,
      eventId: _outboundEventId(scopeId, clean, atMs, ruleId ?? ''),
      ruleId: ruleId ?? '',
    );
    _listFor(conversationId).add(entry);
    _persistNormalizedEntry(scopeId, entry);
    clearObligations(conversationId);
    _evictColdestIfNeeded();
    _markDirty();
  }

  @override
  void reconcileOutbound(String conversationId, String text, {required int atMs}) {
    if (conversationId.isEmpty || text.trim().isEmpty) return;
    final clean = text.trim();
    final scopeId = _scopeFor(conversationId);
    final list = _listFor(conversationId);
    final norm = clean.toLowerCase();

    int? matchedIndex;
    for (var i = list.length - 1; i >= 0; i--) {
      final entry = list[i];
      if (entry.kind == ConversationMemoryEntryKind.outboundDispatched &&
          (atMs - entry.atMs).abs() <= 30000 &&
          entry.text.toLowerCase() == norm) {
        matchedIndex = i;
        break;
      }
    }

    if (matchedIndex != null) {
      final prev = list[matchedIndex];
      list[matchedIndex] = ConversationMemoryEntry(
        kind: ConversationMemoryEntryKind.outboundVerified,
        text: prev.text,
        sender: prev.sender,
        atMs: atMs > 0 ? atMs : prev.atMs,
        eventId: prev.eventId,
        ruleId: prev.ruleId,
      );
      _persistNormalizedEntry(scopeId, list[matchedIndex]);
    } else {
      final entry = ConversationMemoryEntry(
        kind: ConversationMemoryEntryKind.outboundObservedManual,
        text: _boundText(clean),
        atMs: atMs,
        eventId: _outboundEventId(scopeId, clean, atMs, 'manual'),
      );
      list.add(entry);
      _persistNormalizedEntry(scopeId, entry);
      recordManualIntervention(conversationId, atMs);
    }
    _evictColdestIfNeeded();
    _markDirty();
  }
}
