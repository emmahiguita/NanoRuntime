import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_object.dart';
import 'package:nanoai/features/automation/engine/messaging/incoming_message.dart';
import 'package:nanoai/features/automation/domain/notification_source_fragment.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_evidence_window.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_memory.dart';

// Fragmentos observados: comprobación exacta de fecha, texto y autor.
void main() {
  test(
    'Una ráfaga no duplica sus fragmentos en historial ni borra el de otro autor',
    () {
      final current =
          NotificationObject.fromMap({
            'package': 'com.whatsapp',
            'key': 'burst',
            'isGroup': true,
            'messageTimestamp': 2000,
            'messageText': 'Hola\nPregunta',
            'sender': 'Juan',
          }).withText(
            'Hola\nPregunta',
            sourceFragments: const [
              NotificationSourceFragment(
                text: 'Hola',
                atMs: 1000,
                sender: 'Juan',
              ),
              NotificationSourceFragment(
                text: 'Pregunta',
                atMs: 2000,
                sender: 'Juan',
              ),
            ],
          );
      final history = ConversationEvidenceWindow.resolve(const [
        ConversationMemoryEntry(
          kind: ConversationMemoryEntryKind.inbound,
          text: 'Hola',
          atMs: 1000,
          sender: 'Juan',
        ),
        ConversationMemoryEntry(
          kind: ConversationMemoryEntryKind.inbound,
          text: 'Hola',
          atMs: 1000,
          sender: 'Luz',
        ),
        ConversationMemoryEntry(
          kind: ConversationMemoryEntryKind.inbound,
          text: 'Pregunta',
          atMs: 2000,
          sender: 'Juan',
        ),
      ], IncomingMessage.fromNotification(current));
      expect(history.single.sender, 'Luz');
    },
  );
}
