import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/web_bridge/whatsapp_web_conversation_decoder.dart';
import 'package:nanoai/features/automation/engine/web_bridge/whatsapp_web_conversation_snapshot.dart';

void main() {
  const base = WhatsAppWebConversationSummary(
    id: 'waweb:negro-flex',
    displayName: 'Negro Flex',
    lastMessage: 'Hola',
    timeLabel: '11:18',
    lastAtMs: 1000,
    unreadCount: 1,
    isGroup: false,
  );

  test('ignora un snapshot Web idéntico', () {
    expect(
      WhatsAppWebConversationSnapshot.same(const [base], const [base]),
      isTrue,
    );
  });

  test('publica cuando cambia el mensaje visible', () {
    const changed = WhatsAppWebConversationSummary(
      id: 'waweb:negro-flex',
      displayName: 'Negro Flex',
      lastMessage: 'Mensaje nuevo',
      timeLabel: '11:19',
      lastAtMs: 2000,
      unreadCount: 2,
      isGroup: false,
    );
    expect(
      WhatsAppWebConversationSnapshot.same(const [base], const [changed]),
      isFalse,
    );
  });
}
