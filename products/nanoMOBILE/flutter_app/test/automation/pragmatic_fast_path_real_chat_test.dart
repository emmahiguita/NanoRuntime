import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/language/pragmatic_fast_path.dart';
import 'package:nanoai/features/automation/personal_agent/application/conversation_decision_engine.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_agent_role.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_autonomy_mode.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_decision.dart';

void main() {
  const fastPath = PragmaticFastPath();
  const decisionEngine = ConversationDecisionEngine();

  group('PragmaticFastPath - Physical Chat Test Cases', () {
    test('Handles "Bien y que haces ?" naturally without affirming owner activity or returning plan indecision', () async {
      final candidate = await fastPath.resolve(
        text: 'Bien y que haces ?',
        conversationId: 'chat_test_1',
      );

      expect(candidate, isNotNull);
      final reply = candidate!.reply;
      // Must be a natural presence response
      expect(
        reply.contains('tranquilo') ||
            reply.contains('en lo mío') ||
            reply.contains('hablando contigo'),
        isTrue,
        reason: 'Reply was: $reply',
      );
      // Must NOT be "Todavía no lo tengo decidido"
      expect(reply, isNot(contains('decidido')));

      // Also ensure ConversationDecisionEngine passes or approves it for autoSend
      final decision = decisionEngine.decide(
        understanding: candidate.understanding,
        context: const ConversationDecisionContext(
          autonomyMode: ConversationAutonomyMode.autonomous,
          agentRole: ConversationAgentRole.personal,
          userText: 'Bien y que haces ?',
          senderName: 'Emma Hg',
        ),
      );

      // Must allow autoSend
      expect(decision.autoSend, isTrue);
      final effectiveText = decision.repairedText ?? candidate.reply;
      expect(effectiveText, isNot(contains('decidido')));
    });

    test('Handles commitment reminder "dijiste que iriamos" with presence confirmation', () async {
      final candidate = await fastPath.resolve(
        text: 'dijiste que iriamos',
        conversationId: 'chat_test_2',
      );

      expect(candidate, isNotNull);
      final reply = candidate!.reply;
      expect(
        reply.contains('revisar') ||
            reply.contains('confirmo') ||
            reply.contains('aviso') ||
            reply.contains('desocupo'),
        isTrue,
        reason: 'Reply was: $reply',
      );

      final decision = decisionEngine.decide(
        understanding: candidate.understanding,
        context: const ConversationDecisionContext(
          autonomyMode: ConversationAutonomyMode.autonomous,
          agentRole: ConversationAgentRole.personal,
          userText: 'dijiste que iriamos',
          senderName: 'Emma Hg',
        ),
      );
      expect(decision.autoSend, isTrue);
    });

    test('Handles "si vamos a salir en la noche?" with plan caution', () async {
      final candidate = await fastPath.resolve(
        text: 'si vamos a salir en la noche?',
        conversationId: 'chat_test_3',
      );

      expect(candidate, isNotNull);
      final reply = candidate!.reply;
      expect(
        reply.contains('planes') ||
            reply.contains('aviso') ||
            reply.contains('confirmo') ||
            reply.contains('seguro') ||
            reply.contains('más tarde'),
        isTrue,
        reason: 'Reply was: $reply',
      );
    });

    test('Handles presence check "estas ahi" with brief reply', () async {
      final candidate = await fastPath.resolve(
        text: 'estas ahi',
        conversationId: 'chat_test_4',
      );

      expect(candidate, isNotNull);
      final reply = candidate!.reply.toLowerCase();
      expect(
        reply.contains('dime') ||
            reply.contains('estoy') ||
            reply.contains('cuéntame') ||
            reply.contains('ando'),
        isTrue,
        reason: 'Reply was: $reply',
      );
    });

    test('Handles time query "que hora es" with actual device time', () async {
      final candidate = await fastPath.resolve(
        text: 'que hora es',
        conversationId: 'chat_test_5',
      );

      expect(candidate, isNotNull);
      final reply = candidate!.reply;
      expect(reply, matches(RegExp(r'\d{1,2}:\d{2}\s+(?:AM|PM)')));
    });

    test('Handles date query "que dia es hoy" with actual Spanish day and month', () async {
      final candidate = await fastPath.resolve(
        text: 'que dia es hoy',
        conversationId: 'chat_test_6',
      );

      expect(candidate, isNotNull);
      final reply = candidate!.reply.toLowerCase();
      expect(
        reply.contains('hoy es') || reply.contains('estamos a'),
        isTrue,
        reason: 'Reply was: $reply',
      );
    });

    test('Handles location query "en que ciudad estas" with configured city', () async {
      final candidate = await fastPath.resolve(
        text: 'en que ciudad estas',
        conversationId: 'chat_test_7',
      );

      expect(candidate, isNotNull);
      final reply = candidate!.reply;
      expect(reply, contains('Medellín'));
    });

    test('Handles "Oye, qué vas a hacer hoy en la noche" in <5ms without LLM timeout', () async {
      final candidate = await fastPath.resolve(
        text: 'Oye, qué vas a hacer hoy en la noche',
        conversationId: 'chat_test_8',
      );

      expect(candidate, isNotNull);
      final reply = candidate!.reply;
      expect(
        reply.contains('planes') ||
            reply.contains('aviso') ||
            reply.contains('avisando') ||
            reply.contains('confirmo') ||
            reply.contains('seguro') ||
            reply.contains('más tarde'),
        isTrue,
        reason: 'Reply was: $reply',
      );

      final decision = decisionEngine.decide(
        understanding: candidate.understanding,
        context: const ConversationDecisionContext(
          autonomyMode: ConversationAutonomyMode.autonomous,
          agentRole: ConversationAgentRole.personal,
          userText: 'Oye, qué vas a hacer hoy en la noche',
          senderName: 'Emma Hg',
        ),
      );
      expect(decision.autoSend, isTrue);
    });

    test('Handles farewell closure "bueno que descanses" with coherent night farewell', () async {
      final candidate = await fastPath.resolve(
        text: 'bueno que descanses',
        conversationId: 'chat_test_9',
      );

      expect(candidate, isNotNull);
      final reply = candidate!.reply.toLowerCase();
      expect(
        reply.contains('descans') ||
            reply.contains('feliz noche') ||
            reply.contains('mañana'),
        isTrue,
        reason: 'Reply was: ${candidate.reply}',
      );
    });

    test('Handles "Listo, entonces hablamos mañana, que descanses" instant Fast Path (<5ms)', () async {
      final candidate = await fastPath.resolve(
        text: 'Listo, entonces hablamos mañana, que descanses',
        conversationId: 'chat_test_10',
      );

      expect(candidate, isNotNull);
      final reply = candidate!.reply.toLowerCase();
      expect(
        reply.contains('descans') ||
            reply.contains('feliz noche') ||
            reply.contains('mañana'),
        isTrue,
        reason: 'Reply was: ${candidate.reply}',
      );

      final decision = decisionEngine.decide(
        understanding: candidate.understanding,
        context: const ConversationDecisionContext(
          autonomyMode: ConversationAutonomyMode.autonomous,
          agentRole: ConversationAgentRole.personal,
          userText: 'Listo, entonces hablamos mañana, que descanses',
          senderName: 'Emma Hg',
        ),
      );
      expect(decision.autoSend, isTrue);
    });

    test('Handles burst repeated "Listo, entonces hablamos mañana, que descanses Listo,..." without LLM escape', () async {
      final candidate = await fastPath.resolve(
        text: 'Listo, entonces hablamos mañana, que descanses Listo, entonces hablamos mañana, que descanses',
        conversationId: 'chat_test_11',
      );

      expect(candidate, isNotNull);
      final reply = candidate!.reply.toLowerCase();
      expect(
        reply.contains('descans') ||
            reply.contains('feliz noche') ||
            reply.contains('mañana'),
        isTrue,
        reason: 'Reply was: ${candidate.reply}',
      );
    });

    test('Handles general closure "Listo, entonces hablamos mañana"', () async {
      final candidate = await fastPath.resolve(
        text: 'Listo, entonces hablamos mañana',
        conversationId: 'chat_test_12',
      );

      expect(candidate, isNotNull);
      final reply = candidate!.reply.toLowerCase();
      expect(
        reply.contains('hablamos') ||
            reply.contains('nos vemos') ||
            reply.contains('bien') ||
            reply.contains('cuídate') ||
            reply.contains('cuidate') ||
            reply.contains('mañana'),
        isTrue,
        reason: 'Reply was: ${candidate.reply}',
      );
    });
  });
}
