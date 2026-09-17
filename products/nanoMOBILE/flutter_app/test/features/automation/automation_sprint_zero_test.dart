import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_key.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_memory.dart';
import 'package:nanoai/features/automation/engine/messaging/incoming_message.dart';
import 'package:nanoai/features/automation/engine/model/automation_model.dart';
import 'package:nanoai/features/automation/engine/model/automation_model_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('memoria idempotente por eventId', () {
    test('ignora el mismo evento presentado por un reintento', () async {
      final store = MemoryConversationMemoryStore();
      await store.load();
      final message = _message(eventId: 'evt-1', text: 'hola');

      store.appendInbound(message, atMs: 10);
      store.appendInbound(message, atMs: 20);

      final entries = store.memoryFor(message.conversation.key.id)!.entries;
      expect(entries, hasLength(1));
      expect(entries.single.eventId, 'evt-1');
    });

    test(
      'repara duplicados persistidos y conserva la versión más reciente',
      () async {
        const key = 'automation.conversation_memory.v1';
        SharedPreferences.setMockInitialValues({
          key: jsonEncode({
            'conversation-1': {
              'id': 'conversation-1',
              'entries': [
                {'k': 'inbound', 't': 'hola', 'a': 10, 'e': 'evt-1'},
                {'k': 'inbound', 't': 'hola', 'a': 20, 'e': 'evt-1'},
              ],
              'lastAtMs': 20,
            },
          }),
        });
        final store = SharedPrefsConversationMemoryStore();

        await store.load();

        final entries = store.memoryFor('conversation-1')!.entries;
        expect(entries, hasLength(1));
        expect(entries.single.atMs, 20);
        final prefs = await SharedPreferences.getInstance();
        final repaired =
            jsonDecode(prefs.getString(key)!) as Map<String, dynamic>;
        final conversation = repaired['conversation-1'] as Map<String, dynamic>;
        expect(conversation['entries'] as List<dynamic>, hasLength(1));
      },
    );
  });

  test('migra la selección legacy al estado durable para headless', () async {
    SharedPreferences.setMockInitialValues({
      'nanoai_active_model': 'fixture.gguf',
      'nanoai_active_model_path': '/models/fixture.gguf',
      'nanoai_settings': jsonEncode(<String, Object?>{}),
    });
    final repository = SettingsRepository();
    await repository.init();

    final loaded = await repository.load();
    expect(loaded.chatModelId, 'fixture.gguf');
    expect(loaded.chatModelPath, '/models/fixture.gguf');

    await repository.save(loaded);
    final prefs = await SharedPreferences.getInstance();
    final persisted =
        jsonDecode(prefs.getString('nanoai_settings')!) as Map<String, dynamic>;
    expect(persisted['chatModelPath'], '/models/fixture.gguf');
  });

  test('resolver rechaza una ruta seleccionada que ya no existe', () {
    final resolver = AutomationModelResolver(
      mode: () => AutomationModelMode.sameAsChat,
      chatModelPath: () => '/models/missing.gguf',
      automationModelPath: () => '',
      modelPathExists: (_) => false,
    );

    final result = resolver.resolveFor(AutomationModelRole.draftWriter);
    expect(result.modelPath, '/models/missing.gguf');
    expect(result.llmAllowed, isFalse);
  });
}

IncomingMessage _message({required String eventId, required String text}) {
  const key = ConversationKey(
    channel: 'whatsapp',
    appPackage: 'com.whatsapp',
    accountFingerprint: 'account-fixture',
    conversationFingerprint: 'conversation-1',
  );
  return IncomingMessage(
    eventId: eventId,
    conversation: const ConversationIdentity(
      key: key,
      confidence: 1,
      evidenceUsed: {'fixture'},
    ),
    notificationKey: 'notification-fixture',
    packageName: 'com.whatsapp',
    sender: 'Fixture',
    text: text,
    messageTimestamp: 10,
    receivedAt: 10,
    replyCapability: null,
    rawEvidence: const {},
  );
}
