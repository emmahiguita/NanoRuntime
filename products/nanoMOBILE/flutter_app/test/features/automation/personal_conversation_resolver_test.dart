import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/conversation/turn_context_router.dart';
import 'package:nanoai/features/automation/engine/conversation/understanding_frame.dart';
import 'package:nanoai/features/automation/engine/language/whatsapp_text_normalizer.dart';
import 'package:nanoai/features/automation/engine/messaging/social_context_retriever.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_object.dart';
import 'package:nanoai/features/automation/personal_agent/application/conversation_decision_guards.dart';
import 'package:nanoai/features/automation/personal_agent/application/personal_conversation_resolver.dart';
import 'package:nanoai/features/automation/personal_agent/domain/personal_daily_agenda.dart';

NotificationObject _createNotification({required String text}) {
  return NotificationObject(
    key: 'test_${text.hashCode}',
    packageName: 'com.whatsapp',
    title: 'Contacto',
    text: text,
    messageText: text,
    messageTimestamp: DateTime.now().millisecondsSinceEpoch,
    sender: 'Contacto',
    senderKey: 'contacto_k',
    senderUri: '',
    conversationTitle: 'Contacto',
    conversationId: 'whatsapp/com.whatsapp/-/shortcut:1',
    shortcutId: 'shortcut:1',
    locusId: 'locus:1',
    accountHint: '',
    isGroup: false,
    isSummary: false,
    postTime: DateTime.now().millisecondsSinceEpoch,
    canReply: true,
    remoteInputKey: 'key_reply',
    actionIndex: 0,
    actions: const ['Responder'],
    ongoing: false,
  );
}

void main() {
  group('PersonalConversationResolver Live Context Tests', () {
    const resolver = PersonalConversationResolver();
    const router = TurnContextRouter();

    test('Delega la hora al modelo sin fabricar una respuesta fija', () async {
      final notif = _createNotification(text: '¿Qué hora es?');
      final analysis = router.analyze(
        notification: notif,
        memory: null,
        isBusinessChannel: false,
      );

      final reply = await resolver.resolveEarlyTurn(
        notification: notif,
        analysis: analysis,
        memory: null,
        conversationId: 'whatsapp/com.whatsapp/-/shortcut:1',
      );

      expect(
        reply,
        isNull,
      ); // La hora real entra por RuntimePersonalLiveContext.
    });

    test('Delega la fecha al modelo sin fabricar una respuesta fija', () async {
      final notif = _createNotification(text: '¿Qué fecha es hoy?');
      final analysis = router.analyze(
        notification: notif,
        memory: null,
        isBusinessChannel: false,
      );

      final reply = await resolver.resolveEarlyTurn(
        notification: notif,
        analysis: analysis,
        memory: null,
        conversationId: 'whatsapp/com.whatsapp/-/shortcut:1',
      );

      expect(
        reply,
        isNull,
      ); // La fecha real entra por RuntimePersonalLiveContext.
    });

    test(
      'Resuelve rol y tareas de Nano sin confundir con el usuario',
      () async {
        final notif = _createNotification(text: '¿Tú qué harás hoy?');
        final analysis = router.analyze(
          notification: notif,
          memory: null,
          isBusinessChannel: false,
        );

        final reply = await resolver.resolveEarlyTurn(
          notification: notif,
          analysis: analysis,
          memory: null,
          conversationId: 'whatsapp/com.whatsapp/-/shortcut:1',
        );

        expect(
          reply,
          isNull,
        ); // No atribuir al dueño una frase prefabricada de Nano.
      },
    );

    test(
      'Detecta redundancia cuando el contacto ya afirmó un gusto (ej. fútbol)',
      () {
        expect(
          ConversationDecisionGuards.isRedundantStateQuestion(
            'Me gusta el fútbol',
            '¡Genial! ¿Eres fan del fútbol?',
          ),
          isTrue,
        );
        expect(
          ConversationDecisionGuards.isRedundantStateQuestion(
            'Me gusta el fútbol',
            '¡Genial! Eres fan del fútbol',
          ),
          isTrue,
        );
        expect(
          ConversationDecisionGuards.isRedundantStateQuestion(
            'Me gusta el fútbol',
            '¡Qué bien! ¿De qué equipo eres hincha?',
          ),
          isFalse,
        );
      },
    );

    test(
      'Inyecta el cronograma del día con la hora actual cuando está activo',
      () async {
        final now = DateTime(2026, 10, 16, 12, 30);
        final block = PersonalDailyAgenda.promptBlock({
          'agendaEnabled': 'true',
          'agendaDate': '2026-10-16',
          'agendaToday':
              '08:00-12:00 trabajando; 12:00-13:00 almorzando; tarde en casa descansando',
        }, now);
        expect(block, contains('12:30'));
        expect(block, contains('12:00-13:00 almorzando'));
        expect(block, contains('tarde en casa descansando'));
      },
    );

    test(
      'FASE 2: UnderstandingFrame distingue sujeto, tareas, seguimientos, correcciones y prohibiciones',
      () {
        final f1 = UnderstandingFrame.analyze(
          conversationId: 'chat_1',
          rawText: '¿Qué harás hoy?',
        );
        expect(f1.subject, equals(UnderstandingSubject.nano));
        expect(f1.discourseAct, equals(UnderstandingDiscourseAct.taskQuery));

        final f2 = UnderstandingFrame.analyze(
          conversationId: 'chat_1',
          rawText: '¿Qué tengo que hacer hoy?',
        );
        expect(f2.subject, equals(UnderstandingSubject.user));
        expect(f2.discourseAct, equals(UnderstandingDiscourseAct.taskQuery));

        final f3 = UnderstandingFrame.analyze(
          conversationId: 'chat_1',
          rawText: '¿Y a qué hora?',
          recentInboundInSameChat: const ['Juan dijo que mañana trae el carro'],
        );
        expect(
          f3.discourseAct,
          equals(UnderstandingDiscourseAct.followUpReference),
        );
        expect(f3.referencedTopicOrEntity, isNotNull);
        expect(f3.referencedTopicOrEntity!.toLowerCase(), contains('juan'));

        // Aislamiento entre chats distintos
        final f3OtherChat = UnderstandingFrame.analyze(
          conversationId: 'chat_2',
          rawText: '¿Y a qué hora?',
          recentInboundInSameChat: const [],
        );
        expect(f3OtherChat.referencedTopicOrEntity, isNull);

        final f4 = UnderstandingFrame.analyze(
          conversationId: 'chat_1',
          rawText: 'No, eso te toca a ti',
        );
        expect(f4.subject, equals(UnderstandingSubject.nano));
        expect(f4.isCorrectionOrNegation, isTrue);

        final f5 = UnderstandingFrame.analyze(
          conversationId: 'chat_1',
          rawText: 'Tú eres quien debe vigilar',
        );
        expect(f5.subject, equals(UnderstandingSubject.nano));
        expect(
          f5.discourseAct,
          equals(UnderstandingDiscourseAct.taskAssignmentOrRole),
        );

        final f6 = UnderstandingFrame.analyze(
          conversationId: 'chat_1',
          rawText: 'No hagas eso',
        );
        expect(f6.subject, equals(UnderstandingSubject.nano));
        expect(f6.isProhibition, isTrue);
        expect(f6.discourseAct, equals(UnderstandingDiscourseAct.prohibition));
      },
    );

    test(
      'FASE 3: Normalización conservadora de WhatsApp y trigramas sin dañar originalText',
      () {
        const original = 'q vas acer oy en Av. 5 x Calle 10 con Xavier';
        final frame = UnderstandingFrame.analyze(
          conversationId: 'chat_1',
          rawText: original,
        );
        expect(frame.originalText, equals(original));
        expect(
          frame.normalizedText,
          equals('que vas hacer hoy en av 5 x calle 10 con xavier'),
        );

        // Trigram similarity tolerates typos like "fubol" vs "futbol" or "almorsando" vs "almorzando"
        final sim = WhatsAppTextNormalizer.tokenTrigramSimilarity(
          'almorsando',
          'almorzando',
        );
        expect(sim, greaterThan(0.60));

        final score = SocialContextRetriever.scoreThematicRelevance(
          'q vas acer oy en el fubol',
          'Hoy a las 5 tenemos partido de fútbol con los amigos',
        );
        expect(score, greaterThan(0.10));
      },
    );
  });
}
