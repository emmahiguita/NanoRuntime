// conversation_memory_hydration.dart
//
// QUÉ HACE:
// Extensión y métodos de serialización e hidratación de eventos para `_MemoryCore`.
//
// CÓMO FUNCIONA:
// - Genera IDs de evento deterministas para mensajes salientes (`_outboundEventId`).
// - Produce snapshots serializables en JSON (`_snapshot`).
// - Hidrata el estado en frío deduplicando por `eventId` (`_hydrate`, `_deduplicateByEventId`).
//
// POR QUÉ:
// Mantiene las funciones de serialización y sanitización separadas de la estructura de datos,
// garantizando archivos limpios y estrictamente menores a 200 líneas (Clean Architecture - SRP).

part of 'conversation_memory.dart';

extension _MemoryCoreHydration on _MemoryCore {
  String _outboundEventId(String scopeId, String text, int atMs, String ruleId) {
    final digest = sha256
        .convert(utf8.encode('$scopeId\u0000$atMs\u0000$ruleId\u0000$text'))
        .toString();
    return 'out:${digest.substring(0, 32)}';
  }

  Map<String, Object?> _snapshot() => {
    for (final e in _byConversation.entries)
      if (e.value.isNotEmpty)
        e.key: ConversationMemory(
          conversationId: _conversationIdByScope[e.key] ?? e.key,
          scopeId: e.key,
          agentId: _agentByScope[e.key],
          entries: e.value,
          lastAtMs: e.value.last.atMs,
          unresolvedObligations: _obligationsByConversation[e.key] ?? const [],
          activeTopic: _topicByConversation[e.key],
          lastManualInterventionMs: _manualAtByConversation[e.key],
        ).toJson(),
  };

  bool _hydrate(Map<String, Object?> raw) {
    var repairedDuplicates = false;
    for (final e in raw.entries) {
      final m = (e.value as Map).cast<String, dynamic>();
      final memory = ConversationMemory.fromJson(m);
      if (memory.conversationId.isNotEmpty && memory.entries.isNotEmpty) {
        final scopeId = memory.scopeId.isNotEmpty ? memory.scopeId : _scopeFor(memory.conversationId);
        _conversationIdByScope[scopeId] = memory.conversationId;
        final agent = memory.agentId ?? _assignments?.agentForConversationId(memory.conversationId);
        if (agent != null) _agentByScope[scopeId] = agent;
        final deduplicated = _deduplicateByEventId(memory.entries);
        repairedDuplicates |= deduplicated.length != memory.entries.length;
        _byConversation[scopeId] = deduplicated;
        if (memory.unresolvedObligations.isNotEmpty) {
          _obligationsByConversation[scopeId] = List.of(memory.unresolvedObligations);
        }
        if (memory.activeTopic != null && memory.activeTopic!.isNotEmpty) {
          _topicByConversation[scopeId] = memory.activeTopic!;
        }
        if (memory.lastManualInterventionMs != null) {
          _manualAtByConversation[scopeId] = memory.lastManualInterventionMs!;
        }
      }
    }
    return repairedDuplicates;
  }

  List<ConversationMemoryEntry> _deduplicateByEventId(List<ConversationMemoryEntry> entries) {
    final seen = <String>{};
    final reversed = <ConversationMemoryEntry>[];
    for (final entry in entries.reversed) {
      final eventId = entry.eventId.trim();
      final key = eventId.isNotEmpty
          ? eventId
          : '${entry.kind.name}:${entry.atMs}:${entry.sender}:${entry.text}';
      if (!seen.add(key)) continue;
      reversed.add(entry);
    }
    final deduplicated = reversed.reversed.toList(growable: true);
    if (deduplicated.length > maxEntriesPerConversation) {
      deduplicated.removeRange(0, deduplicated.length - maxEntriesPerConversation);
    }
    return deduplicated;
  }
}
