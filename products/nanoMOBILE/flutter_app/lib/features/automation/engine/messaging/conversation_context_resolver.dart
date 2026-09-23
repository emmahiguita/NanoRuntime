/// Resuelve el contexto factual de una conversación aunque WhatsApp cambie
/// entre nombre visible, shortcut `@lid` o JID para el mismo chat.
///
/// Solo combina evidencia que Nano observó y guardó con permiso mediante las
/// notificaciones Android. No intenta leer ni simular la base privada de WhatsApp.
library;

import '../notifications/notification_object.dart';
import 'conversation_key.dart' show canonicalConversationId;
import 'conversation_memory.dart';
import 'incoming_message.dart';

abstract final class ConversationContextResolver {
  static const _maxEntries = 60;

  /// Devuelve una ventana unificada y cronológica para razonamiento y prompt.
  /// El mensaje actual se excluye porque ya entra separado como input.
  static ConversationMemory? resolve({
    required ConversationMemoryStore? store,
    required String conversationId,
    required NotificationObject notification,
  }) {
    if (store == null) return null;
    final primaryId = canonicalConversationId(conversationId);
    final direct = store.memoryFor(primaryId);
    final memories = <ConversationMemory>[];
    final seenScopes = <String>{};

    void add(ConversationMemory? memory) {
      if (memory != null && seenScopes.add(memory.scopeId)) {
        memories.add(memory);
      }
    }

    add(direct);
    for (final knownId in store.knownConversationIds()) {
      final canonical = canonicalConversationId(knownId);
      if (canonical == primaryId ||
          !_sameIdentityScope(canonical, primaryId, notification)) {
        continue;
      }
      final memory = store.memoryFor(canonical);
      if (memory == null) continue;
      // Un alias solo es válido si ambos IDs aportan evidencia estable. El
      // nombre visible etiqueta el chat, pero nunca demuestra identidad.
      final sameIdentity =
          _hasStrongIdentity(canonical) &&
          _hasStrongIdentity(primaryId) &&
          _fingerprint(canonical) == _fingerprint(primaryId);
      if (sameIdentity) add(memory);
    }
    if (memories.isEmpty) return null;

    final current = IncomingMessage.fromNotification(notification);
    final entries = <ConversationMemoryEntry>[];
    for (final memory in memories) {
      for (final entry in memory.entries) {
        if (_isCurrent(entry, current)) continue;
        final duplicate = entries.any((saved) => _sameEvent(saved, entry));
        if (!duplicate) entries.add(entry);
      }
    }
    entries.sort((a, b) => a.atMs.compareTo(b.atMs));
    if (entries.length > _maxEntries) {
      entries.removeRange(0, entries.length - _maxEntries);
    }

    final newest = memories.reduce((a, b) => a.lastAtMs >= b.lastAtMs ? a : b);
    final obligations = <String>{
      for (final memory in memories) ...memory.unresolvedObligations,
    };
    final manualAt = memories
        .map((memory) => memory.lastManualInterventionMs ?? 0)
        .reduce((a, b) => a >= b ? a : b);
    return ConversationMemory(
      conversationId: primaryId,
      scopeId: direct?.scopeId ?? newest.scopeId,
      agentId: direct?.agentId ?? newest.agentId,
      entries: List.unmodifiable(entries),
      lastAtMs: entries.isEmpty ? 0 : entries.last.atMs,
      unresolvedObligations: List.unmodifiable(obligations),
      activeTopic: newest.activeTopic,
      lastManualInterventionMs: manualAt == 0 ? null : manualAt,
    );
  }

  /// Exige paquete y cuenta explícitos en ambos IDs. Los IDs históricos sin
  /// ámbito se conservan como memoria directa, pero no contaminan otro chat.
  static bool _sameIdentityScope(
    String candidate,
    String primary,
    NotificationObject notification,
  ) {
    final candidateParts = candidate.split('/');
    final primaryParts = primary.split('/');
    if (candidateParts.length < 4 || primaryParts.length < 4) return false;
    return candidateParts[1] == notification.packageName &&
        primaryParts[1] == notification.packageName &&
        candidateParts[2] == primaryParts[2];
  }

  /// Solo locus/shortcut/person/conversation/notificación/JID son puentes.
  /// Título, grupo visible y nombre humano pueden repetirse entre personas.
  static bool _hasStrongIdentity(String raw) {
    final canonical = canonicalConversationId(raw).toLowerCase();
    if (canonical.split('/').length < 4) return false;
    return const [
      'locus:',
      'shortcut:',
      'person:',
      'conv:',
      'notification:',
      'jid:',
    ].any((prefix) => canonical.contains('/$prefix'));
  }

  static String _fingerprint(String raw) {
    var value = canonicalConversationId(raw).toLowerCase();
    if (value.contains('/')) value = value.split('/').last;
    for (final prefix in const [
      'locus:',
      'shortcut:',
      'person:',
      'conv:',
      'notification:',
      'jid:',
    ]) {
      if (value.startsWith(prefix)) return value.substring(prefix.length);
    }
    return value;
  }

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

  static bool _sameEvent(ConversationMemoryEntry a, ConversationMemoryEntry b) {
    if (a.eventId.isNotEmpty && b.eventId.isNotEmpty) {
      return a.eventId == b.eventId;
    }
    final sameDirection =
        (a.kind == ConversationMemoryEntryKind.inbound) ==
        (b.kind == ConversationMemoryEntryKind.inbound);
    return sameDirection &&
        (a.atMs - b.atMs).abs() <= 2000 &&
        a.text.trim().toLowerCase() == b.text.trim().toLowerCase();
  }
}
