// QUÉ HACE: agrega y reconcilia entradas de memoria conversacional.
// CÓMO: deduplica eventos, limita texto y confirma salidas observadas.
// POR QUÉ: separa el historial del ciclo de persistencia y mantiene SRP.

part of 'conversation_memory.dart';

const _maxConversationText = 2000;

String _boundConversationText(String raw) => raw.length <= _maxConversationText
    ? raw
    : raw.substring(0, _maxConversationText);

void _appendInboundMemory(
  _MemoryCore store,
  IncomingMessage message,
  int atMs,
) {
  if (message.conversation.key.id.isEmpty || message.text.trim().isEmpty) {
    return;
  }
  final convId = message.conversation.key.id;
  final scopeId = store._scopeFor(convId);
  final eventId = message.eventId.trim();
  final duplicateEvent =
      eventId.isNotEmpty &&
      (store._byConversation[scopeId]?.any((e) => e.eventId == eventId) ??
          false);
  if (duplicateEvent) return;
  final cleanText = _boundConversationText(message.text.trim());
  final duplicateText =
      store._byConversation[scopeId]?.any(
        (e) =>
            e.kind == ConversationMemoryEntryKind.inbound &&
            e.text == cleanText &&
            (atMs - e.atMs).abs() <= 1000,
      ) ??
      false;
  if (duplicateText) return;

  final entry = ConversationMemoryEntry(
    kind: ConversationMemoryEntryKind.inbound,
    text: _boundConversationText(message.text),
    sender: _boundConversationText(message.sender),
    atMs: atMs,
    eventId: message.eventId,
  );
  store._listFor(convId).add(entry);
  store._persistNormalizedEntry(scopeId, entry);
  store._evictColdestIfNeeded();
  store._markDirty();
}

void _appendOutboundMemory(
  _MemoryCore store,
  String conversationId,
  String text,
  ConversationMemoryEntryKind kind,
  String? ruleId,
  int atMs,
) {
  if (conversationId.isEmpty || text.trim().isEmpty) return;
  final clean = text.trim();
  final scopeId = store._scopeFor(conversationId);
  // Evita que dos callbacks del mismo ciclo registren el mismo envío dos veces.
  // La ventana es corta para no ocultar mensajes legítimos repetidos del dueño.
  final duplicate =
      store._byConversation[scopeId]?.any(
        (entry) =>
            entry.kind == kind &&
            entry.ruleId == (ruleId ?? '') &&
            (atMs - entry.atMs).abs() <= 2000 &&
            entry.text.trim().toLowerCase() == clean.toLowerCase(),
      ) ??
      false;
  if (duplicate) return;
  final entry = ConversationMemoryEntry(
    kind: kind,
    text: _boundConversationText(clean),
    atMs: atMs,
    eventId: store._outboundEventId(scopeId, clean, atMs, ruleId ?? ''),
    ruleId: ruleId ?? '',
  );
  store._listFor(conversationId).add(entry);
  store._persistNormalizedEntry(scopeId, entry);
  store.clearObligations(conversationId);
  store._evictColdestIfNeeded();
  store._markDirty();
}

void _reconcileOutboundMemory(
  _MemoryCore store,
  String conversationId,
  String text,
  int atMs,
) {
  if (conversationId.isEmpty || text.trim().isEmpty) return;
  final clean = text.trim();
  final scopeId = store._scopeFor(conversationId);
  final list = store._listFor(conversationId);
  final norm = clean.toLowerCase();
  int? matchedIndex;
  for (var i = list.length - 1; i >= 0; i--) {
    final entry = list[i];
    final isOutbound =
        entry.kind == ConversationMemoryEntryKind.outboundDispatched ||
        entry.kind == ConversationMemoryEntryKind.outboundVerified ||
        entry.kind == ConversationMemoryEntryKind.outboundObservedManual;
    if (isOutbound &&
        (atMs - entry.atMs).abs() <= 30000 &&
        entry.text.trim().toLowerCase() == norm) {
      matchedIndex = i;
      break;
    }
  }
  if (matchedIndex != null) {
    final previous = list[matchedIndex];
    // Un eco repetido ya verificado no es un nuevo mensaje ni aprendizaje.
    if (previous.kind != ConversationMemoryEntryKind.outboundDispatched) return;
    list[matchedIndex] = ConversationMemoryEntry(
      kind: ConversationMemoryEntryKind.outboundVerified,
      text: previous.text,
      sender: previous.sender,
      atMs: atMs > 0 ? atMs : previous.atMs,
      eventId: previous.eventId,
      ruleId: previous.ruleId,
    );
    store._persistNormalizedEntry(scopeId, list[matchedIndex]);
  } else {
    final entry = ConversationMemoryEntry(
      kind: ConversationMemoryEntryKind.outboundObservedManual,
      text: _boundConversationText(clean),
      atMs: atMs,
      eventId: store._outboundEventId(scopeId, clean, atMs, 'manual'),
    );
    list.add(entry);
    store._persistNormalizedEntry(scopeId, entry);
    store.recordManualIntervention(conversationId, atMs);
  }
  store._evictColdestIfNeeded();
  store._markDirty();
}
