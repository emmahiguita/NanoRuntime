import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_agent.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_hub_providers.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_memory.dart';
import 'package:nanoai/features/automation/engine/messaging/incoming_message.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_object.dart';
import 'package:nanoai/features/automation/presentation/widgets/conversation_history_resolver.dart';

void main() {
  group('Messaging Center & Conversation Detail Modularity (< 200 lines)', () {
    test('Archivos modulares clave tienen estrictamente <= 200 líneas', () {
      final paths = [
        'lib/features/automation/presentation/messaging_center/messaging_center_view.dart',
        'lib/features/automation/presentation/messaging_center/messaging_center_banners.dart',
        'lib/features/automation/presentation/messaging_center/messaging_contacts_view.dart',
        'lib/features/automation/presentation/messaging_center/messaging_conversations_view.dart',
        'lib/features/automation/presentation/messaging_center/messaging_dedup_merger.dart',
        'lib/features/automation/presentation/messaging_center/messaging_center_providers.dart',
        'lib/features/automation/presentation/widgets/conversation_detail_sheet.dart',
        'lib/features/automation/presentation/widgets/conversation_detail_header_view.dart',
        'lib/features/automation/presentation/widgets/conversation_detail_empty_view.dart',
        'lib/features/automation/presentation/widgets/conversation_detail_chat_view.dart',
        'lib/features/automation/presentation/widgets/conversation_detail_input_view.dart',
        'lib/features/automation/presentation/widgets/conversation_detail_agent_picker.dart',
        'lib/features/automation/presentation/widgets/conversation_detail_dialogs.dart',
        'lib/features/automation/presentation/widgets/conversation_detail_attachments.dart',
        'lib/features/automation/presentation/widgets/conversation_detail_notifications.dart',
        'lib/features/automation/presentation/widgets/conversation_detail_controller.dart',
        'lib/features/automation/presentation/widgets/conversation_detail_sender.dart',
        'lib/features/automation/presentation/widgets/conversation_history_resolver.dart',
        'lib/features/automation/presentation/widgets/conversation_phone_resolver.dart',
        'lib/features/automation/engine/execution/agent_tool_command_router.dart',
        'lib/features/automation/engine/execution/agent_tool_execution_router.dart',
      ];

      final oversized = <String, int>{};
      for (final p in paths) {
        final f = File(p);
        expect(f.existsSync(), isTrue, reason: 'El archivo $p debe existir');
        final lines = f.readAsLinesSync().length;
        if (lines > 200) {
          oversized[p] = lines;
        }
      }

      expect(oversized, isEmpty, reason: 'Archivos que superan las 200 líneas: $oversized');
    });

    test('Procesos zombie y vistas monolíticas obsoletas eliminadas', () {
      final zombiePaths = [
        'lib/features/automation/presentation/notification_automation_section.dart',
        'lib/features/automation/presentation/notification_automation_widgets.dart',
        'lib/features/automation/presentation/notification_automation_pending.dart',
        'lib/features/automation/presentation/widgets/conversation_detail_sheet_view.dart',
      ];

      for (final p in zombiePaths) {
        expect(File(p).existsSync(), isFalse, reason: '$p no debe existir en el codebase');
      }
    });

    test('ConversationHistoryResolver fusiona notificaciones en vivo y SQLite sin truncar', () {
      final store = MemoryConversationMemoryStore();
      final now = DateTime.now().millisecondsSinceEpoch;

      final notif = NotificationObject.fromMap({
        'key': 'n_18636023784',
        'package': 'com.whatsapp',
        'title': 'Emm',
        'text': 'Mensaje de ayer en SQLite',
        'postTime': now - 86400000,
        'conversationId': 'whatsapp/com.whatsapp/-/18636023784',
      });
      final inbound = IncomingMessage.fromNotification(notif);

      // Historial persistente en SQLite
      store.appendInbound(inbound, atMs: now - 86400000);
      store.appendOutbound(
        inbound.conversation.key.id,
        'Respuesta previa en SQLite',
        kind: ConversationMemoryEntryKind.outboundDispatched,
        atMs: now - 86000000,
      );

      // Notificación activa en la barra de Android
      final liveEntries = [
        ConversationMemoryEntry(
          kind: ConversationMemoryEntryKind.inbound,
          text: 'Nuevo mensaje en barra de notificaciones',
          sender: 'Emm',
          atMs: now,
        ),
      ];

      final summaryItem = ConversationSummaryItem(
        conversationId: 'whatsapp/com.whatsapp/-/18636023784',
        displayName: 'Emm',
        lastMessage: 'Nuevo mensaje en barra de notificaciones',
        lastAtMs: now,
        packageName: 'com.whatsapp',
        agentId: ConversationAgentId.business,
      );

      final resolved = ConversationHistoryResolver.resolve(
        item: summaryItem,
        store: store,
        liveEntries: liveEntries,
      );

      // Debe incluir AMBOS: el historial previo de SQLite y el mensaje vivo
      expect(resolved.length, equals(3));
      expect(resolved[0].text, equals('Mensaje de ayer en SQLite'));
      expect(resolved[1].text, equals('Respuesta previa en SQLite'));
      expect(resolved[2].text, equals('Nuevo mensaje en barra de notificaciones'));
    });
  });
}
