import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/services/conversation_reply_quality.dart';
import 'package:nanoai/features/automation/engine/language/runtime_personal_live_context.dart';
import 'package:nanoai/features/automation/engine/messaging/canonical_message.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_agent.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.nanoai/automation_store');
  test(
    'Fuentes remotas conservan cuenta y agente al resolver su dirección',
    () {
      final personal = ConversationAddress.fromConversationId(
        'whatsapp-mcp/account-a/juan',
      );
      final business = ConversationAddress.fromConversationId(
        'meta/account-a/juan',
      );
      final otherAccount = ConversationAddress.fromConversationId(
        'meta/account-b/juan',
      );
      expect(personal.channelAccountId, 'whatsapp-mcp:account-a');
      expect(business.channelAccountId, 'meta:account-a');
      expect(business.addressKey, isNot(otherAccount.addressKey));
      expect(
        ConversationAgentId.defaultFor(
          channel: personal.channel,
          appPackage: personal.appPackage,
        ),
        ConversationAgentId.personal,
      );
      expect(
        ConversationAgentId.defaultFor(
          channel: business.channel,
          appPackage: business.appPackage,
        ),
        ConversationAgentId.business,
      );
    },
  );
  test('Un contacto no activa lecturas de agenda ni de otros chats', () async {
    var ownerReads = 0;
    var storeReads = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          storeReads++;
          return [];
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final context = RuntimePersonalLiveContext(
      clock: () => DateTime(2026, 10, 16, 14),
      ownerFactsFor: () async {
        ownerReads++;
        return {'private': 'NO DIVULGAR'};
      },
    );
    for (final text in [
      'qué haces',
      'quien te escribió hoy?',
      'que tienes pendiente en whatsapp?',
    ]) {
      final evidence = await context.resolve(text, [], scopeId: 'contact-a');
      expect(evidence.block, isNot(contains('NO DIVULGAR')));
      expect(evidence.block, isNot(contains('WhatsApp pendientes')));
    }
    expect(ownerReads, 0);
    expect(storeReads, 0);
  });

  test(
    'IDs iguales de cuentas/conversaciones o fuentes distintas no colisionan',
    () {
      CanonicalMessage message(
        String conversation,
        CanonicalMessageProvider provider,
      ) => CanonicalMessage.observed(
        conversationId: conversation,
        provider: provider,
        providerMessageId: 'same-id',
        body: 'sí',
        occurredAtMs: 100,
      );
      final a = message(
        'personal/account-a/juan',
        CanonicalMessageProvider.whatsappMcp,
      );
      final b = message(
        'personal/account-b/juan',
        CanonicalMessageProvider.whatsappMcp,
      );
      final business = message(
        'business/account-c/juan',
        CanonicalMessageProvider.metaCloud,
      );
      expect({a.id, b.id, business.id}, hasLength(3));
      expect(
        message(
          'personal/account-a/juan',
          CanonicalMessageProvider.whatsappMcp,
        ).id,
        a.id,
      );
    },
  );

  test('El modelo no puede apropiarse del nombre que dio el contacto', () {
    expect(
      ConversationReplyQuality.rejectionReason(
        input: 'ola me llamo Lucas y aprendo guitarra',
        reply: 'Hola, soy Lucas y aprendo guitarra.',
      ),
      'speaker_confusion',
    );
    expect(
      ConversationReplyQuality.rejectionReason(
        input: 'perdon me equivoque, soy Sara, no Lucas',
        reply: 'Soy Sara y estoy aprendiendo.',
      ),
      'speaker_confusion',
    );
    expect(
      ConversationReplyQuality.rejectionReason(
        input: 'me llamo Lucas',
        reply: 'Encantado, Lucas. ¿Qué te gusta hacer?',
      ),
      isNull,
    );
    expect(
      ConversationReplyQuality.rejectionReason(
        input: 'me llamo Lucas',
        reply: 'Dijiste que te llamas Lucas.',
      ),
      isNull,
    );
  });
}
