import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/business/business_facts.dart';
import 'package:nanoai/features/automation/engine/business/fact_selector.dart';
import 'package:nanoai/features/automation/engine/language/turn_complexity_classifier.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_agent.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_group_resolver.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_hub_providers.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_key.dart';
import 'package:nanoai/features/automation/presentation/messaging_center/messaging_dedup_merger.dart';

void main() {
  group('identidad real y deduplicacion de conversaciones', () {
    test(
      'el control humano usa la identidad canonica y no el prefijo visual',
      () {
        expect(
          canonicalConversationId(
            'live:whatsapp/com.whatsapp/-/shortcut:grupo-infinity@g.us',
          ),
          'whatsapp/com.whatsapp/-/shortcut:grupo-infinity@g.us',
        );
      },
    );

    test(
      'une la identidad canonica persistida con la identidad cruda en vivo',
      () {
        const persisted = ConversationSummaryItem(
          conversationId:
              'whatsapp/com.whatsapp/-/shortcut:grupo-infinity@g.us',
          displayName: 'Infinity',
          packageName: 'com.whatsapp',
          lastMessage: 'Mensaje anterior',
          lastAtMs: 1000,
          agentId: ConversationAgentId.personal,
          isGroup: true,
          groupTitle: 'Infinity',
        );
        const live = ConversationSummaryItem(
          conversationId: 'live:grupo-infinity@g.us',
          displayName: 'Grupo de WhatsApp',
          packageName: 'com.whatsapp',
          lastMessage: 'Mensaje nuevo',
          lastAtMs: 2000,
          agentId: ConversationAgentId.personal,
          isGroup: true,
        );

        expect(
          MessagingDedupMerger.areSameConversation(persisted, live),
          isTrue,
        );
        final result = MessagingDedupMerger.deduplicateAndSort([
          persisted,
          live,
        ]);
        expect(result, hasLength(1));
        expect(result.single.displayName, 'Infinity');
      },
    );

    test(
      'no colapsa dos conversaciones reales distintas con el mismo nombre',
      () {
        const first = ConversationSummaryItem(
          conversationId: 'whatsapp/com.whatsapp/-/shortcut:contact-a',
          displayName: 'Soporte',
          packageName: 'com.whatsapp',
          lastMessage: 'A',
          lastAtMs: 1000,
          agentId: ConversationAgentId.personal,
        );
        const second = ConversationSummaryItem(
          conversationId: 'whatsapp/com.whatsapp/-/shortcut:contact-b',
          displayName: 'Soporte',
          packageName: 'com.whatsapp',
          lastMessage: 'B',
          lastAtMs: 2000,
          agentId: ConversationAgentId.personal,
        );

        expect(
          MessagingDedupMerger.areSameConversation(first, second),
          isFalse,
        );
        expect(
          MessagingDedupMerger.deduplicateAndSort([first, second]),
          hasLength(2),
        );
      },
    );

    test('conserva el nombre real publicado para un grupo', () {
      final info = ConversationGroupResolver.resolveGroupInfo(
        convId: 'grupo-infinity@g.us',
        conversationTitle: 'Infinity (3 mensajes)',
        sender: 'Emmanuel',
      );

      expect(info.groupTitle, 'Infinity');
      expect(info.lastSender, 'Emmanuel');
    });
  });

  group('comprension formal e informal', () {
    const facts = BusinessFacts(
      products: [
        BusinessProduct(
          id: 'nano',
          name: 'Nano Pro',
          details: 'negro',
          price: 120000,
        ),
      ],
      delivery: 'Domicilio nacional',
    );

    test('entiende una solicitud comercial formal', () {
      final selected = selectFactsForMessage(
        '¿Podría indicarme qué productos ofrecen y cuáles son sus precios?',
        facts,
      );

      expect(selected.products, hasLength(1));
    });

    test('entiende abreviaciones informales de precio y domicilio', () {
      final selected = selectFactsForMessage(
        'q precios manejan y hacen domi?',
        facts,
      );

      expect(selected.products, hasLength(1));
      expect(selected.delivery, 'Domicilio nacional');
    });

    test(
      'clasifica saludos formales e informales como conversacion social',
      () {
        expect(
          turnComplexityClassifier
              .classify('Cordial saludo, ¿cómo se encuentra usted?')
              .eligibleForSocialPrompt,
          isTrue,
        );
        expect(
          turnComplexityClassifier
              .classify('ola q tal todo bn?')
              .eligibleForSocialPrompt,
          isTrue,
        );
      },
    );
  });
}
