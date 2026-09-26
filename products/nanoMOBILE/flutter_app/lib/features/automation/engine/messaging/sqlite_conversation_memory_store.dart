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
  late final _persistenceQueue = ConversationPersistenceQueue(
    lastStoreError: () => AutomationDbStoreClient.instance.lastError,
  );

  SqliteConversationMemoryStore({
    super.maxEntriesPerConversation,
    super.maxConversations,
    super.assignments,
  });

  @override
  Future<void> load() async {
    var repaired = false;
    try {
      // La lectura estricta evita confundir un error SQLite con memoria vacía.
      var raw = await AutomationDbStoreClient.instance.requiredSection(
        _section,
      );
      if (raw == null || raw.isEmpty) raw = await _migrateLegacyPrefs();
      if (raw != null && raw.isNotEmpty) {
        repaired = _hydrate((jsonDecode(raw) as Map).cast<String, dynamic>());
      }
    } catch (e, stackTrace) {
      debugPrint('[conversation-memory][load.hydrate] ${e.runtimeType}: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
    _loaded = true;
    if (repaired) {
      await _persistenceQueue.run('memory.load.repair', _write);
    }
  }

  Future<String?> _migrateLegacyPrefs() async {
    // Solo migra si la escritura durable confirmó; así no se borra la única copia legacy.
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_legacyKey);
    if (raw == null || raw.isEmpty) return null;
    final ok = await AutomationDbStoreClient.instance.putSection(_section, raw);
    if (!ok) {
      throw StateError(
        'SQLite rechazó la migración legacy: '
        '${AutomationDbStoreClient.instance.lastError ?? 'causa desconocida'}',
      );
    }
    try {
      await prefs.remove(_legacyKey);
    } catch (error, stackTrace) {
      // SQLite ya conserva la copia; el aviso permite limpiar el duplicado en otra sesión.
      debugPrint(
        '[conversation-memory][legacy.cleanup] ${error.runtimeType}: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
    return raw;
  }

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
    // El snapshot usa la misma cola que mensajes normalizados para conservar orden causal.
    unawaited(
      _persistenceQueue.run('memory.snapshot', () async {
        if (!_dirty) return true;
        final saved = await _write();
        if (saved) _dirty = false;
        return saved;
      }),
    );
  }

  void _scheduleQueueTask(String phase, Future<bool> Function() task) =>
      unawaited(_persistenceQueue.run(phase, task));

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
      'memory.message.append',
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
      'memory.dialogue_state.persist',
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
    // El borrado es idempotente y espera a que terminen las escrituras pendientes.
    return _persistenceQueue.run(
      'memory.conversation.cleanup',
      () => ConversationCleanupClient.instance.clear(
        scopeId: scopeId,
        memoryJson: snapshotJson,
      ),
      rethrowAfterRetries: true,
    );
  }
}
