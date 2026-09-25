/// WA-HUB-01 — modelo y providers para el Centro Universal de Conversaciones.
///
/// **QUÉ HACE:**
/// Agrega de forma unificada:
/// - `ConversationMemoryStore`: historial y conversaciones conocidas en SQLite.
/// - `PendingReplyStore`: borradores pendientes de aprobación.
/// - `SqliteConversationOwnershipStore`: estado de control (humano vs bot).
/// - `PersonaContext`: nombres visibles y perfiles de relación.
///
/// **CÓMO FUNCIONA:**
/// Resuelve grupos mediante [ConversationGroupResolver] sin confundir miembros o menciones,
/// manteniendo la lista reactiva ordenada cronológicamente sin duplicados.
///
/// **POR QUÉ:**
/// Cumple SOLID y la regla de mantener archivos estrictamente menores a 200 líneas.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import '../../application/automation_coordinator_provider.dart';
import '../../personal_agent/application/persona_context.dart'
    show personaContextProvider;
import '../../personal_agent/application/conversation_ownership_policy.dart';
import '../agent_dependencies.dart';
import '../messaging/conversation_agent.dart';
import '../messaging/conversation_memory.dart';
import '../messaging/messaging_package.dart';
import 'conversation_group_resolver.dart';
import 'conversation_summary_item.dart';

export 'conversation_summary_item.dart';

final conversationHubVersionProvider = StateProvider<int>((ref) => 0);

final conversationHubListProvider = FutureProvider.autoDispose
    .family<List<ConversationSummaryItem>, ConversationAgentId>((
      ref,
      requestedAgent,
    ) async {
      ref.watch(conversationHubVersionProvider);
      final settings = ref.watch(settingsProvider);
      final memoryStore = ref.watch(conversationMemoryStoreProvider);
      final pendingStore = ref.watch(pendingReplyStoreProvider);
      final ownershipStore = ref.watch(conversationOwnershipStoreProvider);
      final assignmentStore = ref.watch(conversationAssignmentStoreProvider);
      final personaContext = ref.watch(personaContextProvider);
      await assignmentStore.load();

      final pendingList = await pendingStore.allPending();
      final pendingMap = {for (final p in pendingList) p.conversationId: p};

      final memoryIds = memoryStore.knownConversationIds(
        agentId: requestedAgent,
      );
      final allIds = <String>{...memoryIds, ...pendingMap.keys};

      final items = <ConversationSummaryItem>[];
      for (final convId in allIds) {
        if (convId.contains('status@broadcast') ||
            convId.contains('@newsletter')) {
          continue;
        }
        final assignedAgent = assignmentStore.agentForConversationId(convId);
        if (assignedAgent != requestedAgent) continue;
        final memory = memoryStore.memoryFor(convId);
        final entries = memory?.entries ?? const <ConversationMemoryEntry>[];
        final lastEntry = entries.isNotEmpty ? entries.last : null;
        final pending = pendingMap[convId];
        final assignment = assignmentStore.assignmentFor(convId);

        final lastMessage = pending?.originalMessage.isNotEmpty == true
            ? pending!.originalMessage
            : (lastEntry?.text ?? '');

        final lastAtMs = pending != null
            ? pending.createdAt.millisecondsSinceEpoch
            : (memory?.lastAtMs ?? 0);

        // Un historial no se presenta como WhatsApp sin evidencia real. La
        // asignación normalizada conserva el paquete observado por Android.
        final pendingPackage = pending?.packageName.trim() ?? '';
        final assignedPackage = assignment?.address.appPackage.trim() ?? '';
        final packageName = isKnownMessagingPackage(pendingPackage)
            ? pendingPackage
            : assignedPackage;
        if (!isKnownMessagingPackage(packageName)) continue;

        final senderName = pending?.sender.isNotEmpty == true
            ? pending!.sender
            : (lastEntry?.sender.isNotEmpty == true ? lastEntry!.sender : '');

        final isGroup =
            convId.contains('@g.us') ||
            convId.contains('group:') ||
            (pending != null && pending.conversationId.contains('@g.us')) ||
            ConversationGroupResolver.getCachedGroupTitle(convId) != null;

        String displayName;
        String? groupTitle;
        if (isGroup) {
          final groupInfo = ConversationGroupResolver.resolveGroupInfo(
            convId: convId,
            conversationTitle: pending?.conversationId.isNotEmpty == true
                ? pending!.conversationId
                : null,
            title: convId,
            sender: senderName,
          );
          groupTitle = groupInfo.groupTitle;
          displayName = groupTitle;
        } else {
          final rel = personaContext.relationshipFor(
            senderName,
            conversationId: convId,
          );
          final rawName = rel?.displayName.isNotEmpty == true
              ? rel!.displayName
              : (senderName.isNotEmpty ? senderName : convId);
          displayName = _sanitizeName(rawName, convId);
        }

        final lastSender = entries.isNotEmpty
            ? entries.last.sender
            : (pending?.sender ?? '');
        final ownership = ownershipStore.ownershipFor(convId);
        final humanOwns = ConversationOwnershipPolicy.humanOwns(
          targetContactsMode: settings.waTargetContactsMode,
          ownership: ownership,
        );

        items.add(
          ConversationSummaryItem(
            conversationId: convId,
            displayName: displayName,
            packageName: packageName,
            lastMessage: lastMessage,
            lastAtMs: lastAtMs > 0
                ? lastAtMs
                : DateTime.now().millisecondsSinceEpoch,
            hasPendingReply: pending != null,
            pendingReplyId: pending?.id,
            pendingReplyText: pending?.draftText,
            pendingSuggestions: pending?.suggestions ?? const [],
            humanOwns: humanOwns,
            activeRole: assignedAgent.name,
            agentId: assignedAgent,
            entryCount: entries.length,
            notificationKey: pending?.notificationKey,
            isGroup: isGroup,
            groupTitle: groupTitle,
            lastSender: lastSender.isNotEmpty ? lastSender : null,
          ),
        );
      }

      items.sort((a, b) => b.lastAtMs.compareTo(a.lastAtMs));
      return items;
    });

String _sanitizeName(String raw, String convId) {
  var s = raw;
  if (s.contains('|')) s = s.split('|').first;
  if (s.contains(':') && s.split(':').first.contains('.')) {
    s = s.split(':').last;
  }
  for (final p in const [
    'title:',
    'group:',
    'conv:',
    'live:',
    'shortcut:',
    'person:',
    'jid:',
  ]) {
    if (s.toLowerCase().startsWith(p)) s = s.substring(p.length).trim();
  }
  if (s.contains('@g.us') || convId.contains('@g.us')) {
    final clean = ConversationGroupResolver.cleanTitle(s);
    if (clean.isNotEmpty && !ConversationGroupResolver.isGenericTitle(clean)) {
      return clean;
    }
    return 'Grupo de WhatsApp';
  }
  if (s.contains('shortcut:') ||
      s.contains('@s.whatsapp.net') ||
      s.startsWith('whatsapp/')) {
    final digits = RegExp(r'\d{8,15}').firstMatch(s)?.group(0);
    if (digits != null) return 'Contacto WhatsApp ($digits)';
    return 'Chat de WhatsApp';
  }
  return s.trim();
}
