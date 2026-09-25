// sqlite_conversation_memory_store.dart
//
// QUÉ HACE:
// Implementación transaccional y durable de `ConversationMemoryStore` sobre SQLite
// (`AutomationDbStoreClient`) y variantes para testing o shared_preferences.
//
// CÓMO FUNCIONA:
// - Serializa las escrituras mediante una cola Future encadenada (`_persistenceQueue`).
// - Implementa reintentos con backoff progresivo (100ms, 200ms, 300ms) si la base de datos está ocupada.
// - Persiste tanto el snapshot global de la sección `memory` como eventos normalizados individuales.
//
// POR QUÉ:
// Resuelve el hallazgo AUT-P1-09 (escrituras de memoria concurrentes) asegurando consistencia (< 175 líneas).

part of 'conversation_memory.dart';

/// Store en memoria (preview/tests). Determinista, sin persistencia.
class MemoryConversationMemoryStore extends _MemoryCore {
  MemoryConversationMemoryStore({
    super.maxEntriesPerConversation,
    super.maxConversations,
    super.assignments,
  });
  @override
  Future<void> load() async {
    _loaded = true;
  }

  @override
  void _markDirty() {}
}

/// Persistencia transaccional SQLite con cola durable serializada (WA-PROD-02 / AUT-P1-09).
class SqliteConversationMemoryStore extends _MemoryCore {
  static const _section = 'memory';
  static const _legacyKey = 'automation.conversation_memory.v1';

  SqliteConversationMemoryStore({
    super.maxEntriesPerConversation,
    super.maxConversations,
    super.assignments,
  });

  @override
  Future<void> load() async {
    var repaired = false;
    try {
      var raw = await AutomationDbStoreClient.instance.section(_section);
      if (raw == null || raw.isEmpty) raw = await _migrateLegacyPrefs();
      if (raw != null && raw.isNotEmpty) {
        repaired = _hydrate((jsonDecode(raw) as Map).cast<String, dynamic>());
      }
    } catch (e) {
      debugPrint('[convmem] load SQLite fallo: $e');
    }
    _loaded = true;
    if (repaired) {
      try {
        await _write();
      } catch (_) {}
    }
  }

  Future<String?> _migrateLegacyPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_legacyKey);
      if (raw == null || raw.isEmpty) return null;
      final ok = await AutomationDbStoreClient.instance.putSection(
        _section,
        raw,
      );
      if (ok) await prefs.remove(_legacyKey);
      return ok ? raw : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistenceQueue = Future<void>.value();
  bool _dirty = false;

  @override
  void _markDirty() {
    if (!_loaded) return;
    _dirty = true;
    _scheduleWrite();
  }

  Future<bool> _write() => AutomationDbStoreClient.instance.putSection(
    _section,
    jsonEncode(_snapshot()),
  );

  void _scheduleWrite() {
    _persistenceQueue = _persistenceQueue
        .then((_) async {
          if (!_dirty) return;
          int attempts = 0;
          while (_dirty && attempts < 3) {
            attempts++;
            if (await _write()) {
              _dirty = false;
              break;
            }
            await Future.delayed(Duration(milliseconds: 100 * attempts));
          }
        })
        .catchError((Object e) {
          debugPrint('[conversation-memory] cola persistencia: $e');
        });
  }

  void _scheduleQueueTask(Future<bool> Function() task) {
    _persistenceQueue = _persistenceQueue
        .then((_) async {
          int attempts = 0;
          while (attempts < 3) {
            attempts++;
            if (await task()) break;
            await Future.delayed(Duration(milliseconds: 100 * attempts));
          }
        })
        .catchError((Object e) {
          debugPrint('[conversation-memory] cola tarea: $e');
        });
  }

  @override
  void _persistNormalizedEntry(String scopeId, ConversationMemoryEntry entry) {
    final direction = entry.kind == ConversationMemoryEntryKind.inbound
        ? 'inbound'
        : 'outbound';
    final deliveryState = switch (entry.kind) {
      ConversationMemoryEntryKind.inbound => 'observed',
      ConversationMemoryEntryKind.outboundVerified => 'verified',
      ConversationMemoryEntryKind.outboundDispatched => 'dispatched',
      ConversationMemoryEntryKind.outboundObservedManual => 'manual',
      ConversationMemoryEntryKind.effectUnknown => 'unknown',
    };
    final eventId = entry.eventId.isNotEmpty
        ? entry.eventId
        : _outboundEventId(scopeId, entry.text, entry.atMs, entry.ruleId);
    _scheduleQueueTask(
      () => AutomationDbStoreClient.instance.appendConversationMessage(
        scopeId: scopeId,
        eventId: eventId,
        direction: direction,
        deliveryState: deliveryState,
        sender: entry.sender,
        body: entry.text,
        atMs: entry.atMs,
        ruleId: entry.ruleId,
      ),
    );
  }

  @override
  void _persistNormalizedState(String scopeId, ConversationMemory memory) {
    _scheduleQueueTask(
      () => AutomationDbStoreClient.instance.putConversationDialogueState(
        scopeId: scopeId,
        stateJson: jsonEncode(memory.toJson()),
        updatedAtMs: memory.lastAtMs,
      ),
    );
  }

  @override
  Future<bool> _persistConversationRemoval(
    String scopeId,
    String snapshotJson,
  ) {
    final operation = _persistenceQueue.then(
      (_) => ConversationCleanupClient.instance.clear(
        scopeId: scopeId,
        memoryJson: snapshotJson,
      ),
    );
    // La cola continúa aunque esta operación falle; el Future original se
    // conserva para que la interfaz informe el error de forma honesta.
    _persistenceQueue = operation.then<void>((_) {}).catchError((Object e) {
      debugPrint('[conversation-memory] borrado persistente: $e');
    });
    return operation;
  }
}
