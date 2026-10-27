import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/messaging/canonical_prompt_memory.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_memory_models.dart';
import 'package:nanoai/features/automation/engine/notifications/native_conversation_history.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_object.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.nanoai/automation_store');
  test(
    'Canónico conserva despacho sin elevarlo a entrega y omite efecto incierto',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method != 'canonicalMessageList') {
              return <Map<String, Object?>>[];
            }
            return [
              {
                'id': 'in',
                'conversationId': 'synthetic',
                'provider': 'android_notification',
                'direction': 'inbound',
                'body': 'Aprendo guitarra.',
                'occurredAtMs': 100,
                'deliveryState': 'observed',
              },
              {
                'id': 'out',
                'conversationId': 'synthetic',
                'provider': 'android_notification',
                'direction': 'outbound',
                'body': '¿Desde cuándo practicas?',
                'occurredAtMs': 200,
                'deliveryState': 'dispatched',
              },
              {
                'id': 'unknown',
                'conversationId': 'synthetic',
                'provider': 'android_notification',
                'direction': 'outbound',
                'body': 'Texto incierto.',
                'occurredAtMs': 250,
                'deliveryState': 'unknown',
              },
            ];
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final memory = await CanonicalPromptMemory.load(
        conversationId: 'synthetic',
        notification: NotificationObject.fromMap({
          'text': 'Desde ayer.',
          'messageText': 'Desde ayer.',
          'messageTimestamp': 300,
          'postTime': 300,
          'packageName': 'com.whatsapp',
        }),
      );
      expect(memory, isNotNull);
      expect(memory!.entries.map((e) => e.kind), [
        ConversationMemoryEntryKind.inbound,
        ConversationMemoryEntryKind.outboundDispatched,
      ]);
      final turns = nativeConversationHistory(memory.entries);
      expect(turns.map((t) => t['role']), ['user', 'assistant']);
      expect(turns.last['content'], contains('entrega no verificada'));
      expect(turns.last['content'], contains('¿Desde cuándo practicas?'));
      expect(memory.historyNotice, contains('entrega sin confirmar'));
    },
  );

  test(
    'Ventana nativa acota tamaño y no convierte efectos desconocidos en diálogo',
    () {
      final turns = nativeConversationHistory(
        [
          const ConversationMemoryEntry(
            kind: ConversationMemoryEntryKind.inbound,
            text: 'Dato anterior',
            atMs: 1,
          ),
          ConversationMemoryEntry(
            kind: ConversationMemoryEntryKind.outboundDispatched,
            text: 'x' * 500,
            atMs: 2,
          ),
          const ConversationMemoryEntry(
            kind: ConversationMemoryEntryKind.effectUnknown,
            text: 'No confirmado',
            atMs: 3,
          ),
        ],
        maxMessages: 1,
        maxChars: 180,
      );
      expect(turns, hasLength(1));
      expect(turns.single['content']!.length, lessThanOrEqualTo(180));
      expect(
        turns.single['content'],
        startsWith('[Mensaje despachado por Nano; entrega no verificada]'),
      );
      expect(turns.single['content'], contains('[historial parcial]'));
    },
  );
}
