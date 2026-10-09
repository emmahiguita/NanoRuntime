/// QUÉ: ordena y deduplica evidencia de un scope ya resuelto por identidad.
/// CÓMO: IDs reales en O(1), reconciliación manual/verificada por fecha y texto.
/// POR QUÉ: SQL y RAM comparten las mismas reglas, sin duplicar el mensaje actual.
library;

import 'conversation_memory.dart';
import 'incoming_message.dart';

abstract final class ConversationEvidenceWindow {
  static List<ConversationMemoryEntry> resolve(
    Iterable<ConversationMemoryEntry> source,
    IncomingMessage current,
  ) {
    final entries = <ConversationMemoryEntry>[];
    final seenEventIds = <String>{};
    final outbound = <(int, String), int>{};
    for (final entry in source) {
      if (_isCurrent(entry, current)) continue;
      if (entry.eventId.isNotEmpty && !seenEventIds.add(entry.eventId)) {
        continue;
      }
      final observed =
          entry.kind == ConversationMemoryEntryKind.outboundVerified ||
          entry.kind == ConversationMemoryEntryKind.outboundObservedManual;
      final key = (entry.atMs, entry.text.trim());
      final index = observed ? outbound[key] : null;
      // Solo dos estados del mismo instante observado; una repetición posterior vale.
      if (entry.atMs > 0 &&
          index != null &&
          entries[index].kind != entry.kind) {
        if (entry.kind == ConversationMemoryEntryKind.outboundVerified) {
          entries[index] = entry;
        }
        continue;
      }
      if (entry.eventId.isNotEmpty ||
          !entries.any((saved) => _sameEvent(saved, entry))) {
        if (observed) outbound[key] = entries.length;
        entries.add(entry);
      }
    }
    entries.sort((a, b) => a.atMs.compareTo(b.atMs));
    if (entries.length > 60) entries.removeRange(0, entries.length - 60);
    return entries;
  }

  // No elimina un mensaje posterior por compartir texto con el actual.
  static bool _isCurrent(
    ConversationMemoryEntry entry,
    IncomingMessage current,
  ) {
    if (entry.kind != ConversationMemoryEntryKind.inbound) return false;
    if (entry.eventId.isNotEmpty && entry.eventId == current.eventId) {
      return true;
    }
    final stamp = current.messageTimestamp > 0
        ? current.messageTimestamp
        : current.receivedAt;
    return stamp > 0 &&
        (entry.atMs - stamp).abs() <= 2000 &&
        entry.text.trim().toLowerCase() == current.text.trim().toLowerCase();
  }

  // Compatibilidad con entradas legacy sin ID; los IDs diferentes son eventos distintos.
  static bool _sameEvent(ConversationMemoryEntry a, ConversationMemoryEntry b) {
    if (a.eventId.isNotEmpty && b.eventId.isNotEmpty) {
      return a.eventId == b.eventId;
    }
    return (a.kind == ConversationMemoryEntryKind.inbound) ==
            (b.kind == ConversationMemoryEntryKind.inbound) &&
        (a.atMs - b.atMs).abs() <= 2000 &&
        a.text.trim().toLowerCase() == b.text.trim().toLowerCase();
  }
}
