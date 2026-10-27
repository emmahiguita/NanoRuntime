// Persistencia JSON de respaldo para entornos sin AutomationStore SQLite.
part of 'conversation_memory.dart';

class SharedPrefsConversationMemoryStore extends _MemoryCore {
  static const _key = 'automation.conversation_memory.v1';

  SharedPrefsConversationMemoryStore({
    super.maxEntriesPerConversation,
    super.maxConversations,
    super.assignments,
  });

  @override
  Future<void> load() async {
    var repaired = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        repaired = _hydrate((jsonDecode(raw) as Map).cast<String, dynamic>());
      }
    } catch (e) {
      debugPrint('[convmem] load fallo: $e');
    }
    _loaded = true;
    if (repaired) {
      try {
        await _write();
      } catch (_) {}
    }
  }

  @override
  void _markDirty() {
    if (!_loaded) return;
    unawaited(_write());
  }

  Future<void> _write() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_snapshot()));
  }

  @override
  Future<bool> _persistConversationRemoval(
    String scopeId,
    String snapshotJson,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_key, snapshotJson);
  }
}
