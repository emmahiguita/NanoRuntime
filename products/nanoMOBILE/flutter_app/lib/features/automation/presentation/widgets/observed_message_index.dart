import '../../engine/messaging/conversation_memory.dart';

/// Índice por identidad o instante exacto: evita comparar todo el historial por parejas.
final class ObservedMessageIndex {
  final _ids = <String>{};
  final _events = <(int, bool, String), List<ConversationMemoryEntry>>{};

  /// Dos IDs explícitos distintos o dos horas distintas no son el mismo mensaje.
  bool add(ConversationMemoryEntry entry) {
    if (entry.eventId.isNotEmpty && !_ids.add(entry.eventId)) return false;
    final key = (
      entry.atMs,
      entry.kind == ConversationMemoryEntryKind.inbound,
      entry.text.trim(),
    );
    final candidates = _events.putIfAbsent(key, () => []);
    final duplicate = candidates.any((saved) {
      if (saved.eventId.isNotEmpty && entry.eventId.isNotEmpty) return false;
      final a = saved.sender.trim().toLowerCase();
      final b = entry.sender.trim().toLowerCase();
      return a.isEmpty || b.isEmpty || a == b;
    });
    if (duplicate) return false;
    candidates.add(entry);
    return true;
  }
}
