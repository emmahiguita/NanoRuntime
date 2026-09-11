/// WA-HUB-01 — modelo y providers para el Centro Universal de Conversaciones.
///
/// Agrega de forma unificada:
/// - `ConversationMemoryStore`: historial y conversaciones conocidas.
/// - `PendingReplyStore`: borradores pendientes de aprobación.
/// - `SqliteConversationOwnershipStore`: estado de control (humano vs bot).
/// - `PersonaContext`: nombres visibles y perfiles de relación.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/automation_coordinator_provider.dart';
import '../agent_dependencies.dart';
import '../messaging/conversation_memory.dart';
import '../messaging/pending_reply.dart';
import '../../personal_agent/application/persona_context.dart'
    show personaContextProvider;

final class ConversationSummaryItem {
  final String conversationId;
  final String displayName;
  final String packageName;
  final String lastMessage;
  final int lastAtMs;
  final bool hasPendingReply;
  final String? pendingReplyId;
  final String? pendingReplyText;
  final bool humanOwns;
  final String activeRole;
  final String? activeProductName;
  final int entryCount;

  const ConversationSummaryItem({
    required this.conversationId,
    required this.displayName,
    this.packageName = 'com.whatsapp',
    required this.lastMessage,
    required this.lastAtMs,
    this.hasPendingReply = false,
    this.pendingReplyId,
    this.pendingReplyText,
    this.humanOwns = false,
    this.activeRole = 'general',
    this.activeProductName,
    this.entryCount = 0,
  });

  String get appLabel => switch (packageName) {
    'com.whatsapp' => 'WhatsApp',
    'com.whatsapp.w4b' => 'WhatsApp Business',
    'org.telegram.messenger' => 'Telegram',
    'com.instagram.android' => 'Instagram',
    _ => 'Mensajería',
  };
}

/// Proveedor de la lista agregada y ordenada de conversaciones activas.
final conversationHubListProvider =
    FutureProvider.autoDispose<List<ConversationSummaryItem>>((ref) async {
  final memoryStore = ref.watch(conversationMemoryStoreProvider);
  final pendingStore = ref.watch(pendingReplyStoreProvider);
  final ownershipStore = ref.watch(conversationOwnershipStoreProvider);
  final personaContext = ref.watch(personaContextProvider);

  final pendingList = await pendingStore.allPending();
  final pendingMap = <String, PendingReply>{};
  for (final p in pendingList) {
    pendingMap[p.conversationId] = p;
  }

  final memoryIds = memoryStore.knownConversationIds();
  final allIds = <String>{
    ...memoryIds,
    ...pendingMap.keys,
  };

  final items = <ConversationSummaryItem>[];

  for (final convId in allIds) {
    final memory = memoryStore.memoryFor(convId);
    final pending = pendingMap[convId];

    final entries = memory?.entries ?? const <ConversationMemoryEntry>[];
    final lastEntry = entries.isNotEmpty ? entries.last : null;

    final lastMessage = pending?.originalMessage.isNotEmpty == true
        ? pending!.originalMessage
        : (lastEntry?.text ?? 'Conversación iniciada');

    final lastAtMs = pending != null
        ? pending.createdAt.millisecondsSinceEpoch
        : (memory?.lastAtMs ?? 0);

    final packageName = pending?.packageName.isNotEmpty == true
        ? pending!.packageName
        : 'com.whatsapp';

    final senderName = pending?.sender.isNotEmpty == true
        ? pending!.sender
        : (lastEntry?.sender.isNotEmpty == true ? lastEntry!.sender : '');

    final rel = personaContext.relationshipFor(senderName, conversationId: convId);
    final rawName = rel?.displayName.isNotEmpty == true
        ? rel!.displayName
        : (senderName.isNotEmpty ? senderName : convId);
    final displayName = _sanitizeName(rawName, convId);

    final ownership = ownershipStore.ownershipFor(convId);
    final humanOwns = ownership?.humanOwns ?? false;

    items.add(
      ConversationSummaryItem(
        conversationId: convId,
        displayName: displayName,
        packageName: packageName,
        lastMessage: lastMessage,
        lastAtMs: lastAtMs > 0 ? lastAtMs : DateTime.now().millisecondsSinceEpoch,
        hasPendingReply: pending != null,
        pendingReplyId: pending?.id,
        pendingReplyText: pending?.draftText,
        humanOwns: humanOwns,
        activeRole: 'sales',
        entryCount: entries.length,
      ),
    );
  }

  items.sort((a, b) => b.lastAtMs.compareTo(a.lastAtMs));
  return items;
});

String _sanitizeName(String raw, String convId) {
  var s = raw;
  if (s.contains('|')) {
    s = s.split('|').last;
  }
  if (s.contains('shortcut:') || s.contains('@g.us') || s.contains('@s.whatsapp.net') || s.startsWith('whatsapp/')) {
    final digits = RegExp(r'\d{8,15}').firstMatch(s)?.group(0);
    if (digits != null) {
      return 'Contacto WhatsApp ($digits)';
    }
    return 'Chat de WhatsApp';
  }
  return s;
}
