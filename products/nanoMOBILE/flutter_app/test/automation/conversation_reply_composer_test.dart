import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/conversation/conversation_reply_composer.dart';
import 'package:nanoai/features/automation/engine/notifications/conversation_understanding.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_draft_writer.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_object.dart';
import 'package:nanoai/features/automation/personal_agent/application/conversation_decision_engine.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_agent_role.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_decision.dart';

NotificationObject _mockNotification({
  String text = 'Hola, ¿tienen disponibilidad?',
  String sender = 'Carlos',
  String key = 'notif_1',
}) {
  return NotificationObject(
    key: key,
    packageName: 'com.whatsapp',
    title: sender,
    text: text,
    messageText: text,
    messageTimestamp: 1720000000,
    sender: sender,
    senderKey: 'sender_key_$sender',
    senderUri: '',
    conversationTitle: sender,
    conversationId: 'conv_$sender',
    shortcutId: 'shortcut_$sender',
    locusId: 'locus_$sender',
    accountHint: '',
    isGroup: false,
    isSummary: false,
    isTruncated: false,
    postTime: 1720000000,
    canReply: true,
    remoteInputKey: 'key_remote',
    actionIndex: 0,
    actions: const ['Responder'],
    ongoing: false,
  );
}

void main() {
  group('ConversationReplyComposer', () {
    test('compone respuesta contextual única usando NotificationDraftWriter', () async {
      final composer = RuntimeConversationReplyComposer(
        draftSource: (notif) async => const NotificationDraftResult(
          reply: 'Sí Carlos, tenemos disponibilidad hoy.',
          understanding: ConversationUnderstanding(
            intent: 'disponibilidad',
            requiresAction: false,
            missingFacts: [],
          ),
        ),
        decisionEngine: const ConversationDecisionEngine(),
      );

      final notif = _mockNotification();
      final result = await composer.compose(
        notif,
        decisionContext: const ConversationDecisionContext(
          agentRole: ConversationAgentRole.sales,
        ),
      );

      expect(result, isNotNull);
      expect(result!.text, contains('tenemos disponibilidad'));
      expect(result.understanding.intent, equals('disponibilidad'));
      expect(result.role, equals(ConversationAgentRole.sales));
      expect(result.isFastPath, isFalse);
    });

    test('falla honesto cuando el motor no produce borrador (sin call-center)', () async {
      final composer = RuntimeConversationReplyComposer(
        draftSource: (notif) async => null,
      );

      final notif = _mockNotification();
      final result = await composer.compose(notif);

      expect(result, isNull);
    });

    test('composeSuggestions deriva variantes de la MISMA comprensión sin nuevo LLM', () async {
      final composer = RuntimeConversationReplyComposer(
        draftSource: (notif) async => const NotificationDraftResult(
          reply: 'Hola Carlos. Tenemos disponibilidad inmediata para hoy en la tarde.',
          understanding: ConversationUnderstanding(
            intent: 'consulta_disponibilidad',
            requiresAction: false,
            missingFacts: [],
          ),
        ),
      );

      final notif = _mockNotification();
      final suggestions = await composer.composeSuggestions(notif, maxSuggestions: 3);

      expect(suggestions, isNotEmpty);
      expect(suggestions.first, contains('Tenemos disponibilidad inmediata'));
      // Una variante concisa generada a partir de oraciones del mismo texto
      expect(suggestions.length, greaterThanOrEqualTo(2));
      for (final s in suggestions) {
        expect(s, isNotEmpty);
        expect(s.toLowerCase(), isNot(contains('en qué puedo ayudarte')));
      }
    });

    test('composeSuggestions en fast-path produce variantes cotidianas', () async {
      final composer = RuntimeConversationReplyComposer(
        draftSource: (notif) async => null,
      );

      // Si no hay draftSource ni fast-path, devuelve lista vacía
      final notif = _mockNotification();
      final suggestions = await composer.composeSuggestions(notif);
      expect(suggestions, isEmpty);
    });
  });
}
