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
      if (memory != null && seenScopes.add(memory.scopeId)) memories.add(memory);
    }

    add(direct);
    final sender = _humanName(notification);
    final isGroup = notification.isGroup || _isGroupId(primaryId);
    for (final knownId in store.knownConversationIds()) {
      final canonical = canonicalConversationId(knownId);
      if (canonical == primaryId || !_samePackage(canonical, notification)) {
        continue;
      }
      final memory = store.memoryFor(canonical);
      if (memory == null) continue;
      final sameIdentity = _fingerprint(canonical) == _fingerprint(primaryId);
      final samePerson =
          !isGroup && sender.isNotEmpty && memory.entries.any((entry) => _normalizeName(entry.sender) == sender);
      if (sameIdentity || samePerson) add(memory);
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
    final obligations = <String>{for (final memory in memories) ...memory.unresolvedObligations};
    final manualAt = memories.map((memory) => memory.lastManualInterventionMs ?? 0).reduce((a, b) => a >= b ? a : b);
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

  static bool _samePackage(String id, NotificationObject notification) {
    if (!id.contains('/')) return true; // Compatibilidad con IDs históricos.
    return id.contains('/${notification.packageName}/');
  }

  static bool _isGroupId(String id) => id.contains('@g.us') || id.contains('/group:');

  static String _fingerprint(String raw) {
    var value = canonicalConversationId(raw).toLowerCase();
    if (value.contains('/')) value = value.split('/').last;
    for (final prefix in const ['locus:', 'shortcut:', 'person:', 'conv:', 'jid:', 'group:', 'title:']) {
      if (value.startsWith(prefix)) return value.substring(prefix.length);
    }
    return value;
  }

  static String _humanName(NotificationObject notification) {
    for (final raw in [notification.sender, notification.title, notification.conversationTitle]) {
      final normalized = _normalizeName(raw);
      if (normalized.isNotEmpty) return normalized;
    }
    return '';
  }

  static String _normalizeName(String raw) {
    final lower = raw.trim().toLowerCase();
    final value = lower
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]+', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (value.length < 2 ||
        value == 'whatsapp' ||
        value.startsWith('chat de whatsapp') ||
        value.startsWith('contacto whatsapp') ||
        lower.contains('@lid') ||
        lower.contains('@g.us') ||
        lower.contains('@s.whatsapp.net')) {
      return '';
    }
    return value;
  }

  static bool _isCurrent(ConversationMemoryEntry entry, IncomingMessage current) {
    if (entry.kind != ConversationMemoryEntryKind.inbound) return false;
    if (entry.eventId.isNotEmpty && entry.eventId == current.eventId) return true;
    final stamp = current.messageTimestamp > 0 ? current.messageTimestamp : current.receivedAt;
    return stamp > 0 &&
        (entry.atMs - stamp).abs() <= 2000 &&
        entry.text.trim().toLowerCase() == current.text.trim().toLowerCase();
  }

  static bool _sameEvent(ConversationMemoryEntry a, ConversationMemoryEntry b) {
    if (a.eventId.isNotEmpty && b.eventId.isNotEmpty) {
      return a.eventId == b.eventId;
    }
    final sameDirection =
        (a.kind == ConversationMemoryEntryKind.inbound) == (b.kind == ConversationMemoryEntryKind.inbound);
    return sameDirection &&
        (a.atMs - b.atMs).abs() <= 2000 &&
        a.text.trim().toLowerCase() == b.text.trim().toLowerCase();
  }
}
