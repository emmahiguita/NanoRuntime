import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/notifications/conversation_understanding.dart';
import 'package:nanoai/features/automation/personal_agent/application/conversation_decision_engine.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_agent_role.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_autonomy_mode.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_decision.dart';

void main() {
  const engine = ConversationDecisionEngine();
  const personal = ConversationDecisionContext(
    agentRole: ConversationAgentRole.personal,
    userText: 'Hola',
  );

  ConversationUnderstanding draft({
    String reply = '¡Hola! ¿Cómo puedo ayudarte hoy?',
    String intent = 'greeting',
    String relation = 'nuevo',
    List<String> questions = const [],
    List<String> missingFacts = const [],
    bool requiresAction = false,
  }) => ConversationUnderstanding(
    reply: reply,
    intent: intent,
    relation: relation,
    questions: questions,
    missingFacts: missingFacts,
    requiresAction: requiresAction,
  );

  group('Repaired replies keep the complete decision contract', () {
    test('a safe greeting repair still sends with validated confidence', () {
      final decision = engine.decide(understanding: draft(), context: personal);
      expect(decision.disposition, ConversationDisposition.qualityRepair);
      expect(decision.repairedText, '¡Hola!');
      expect(decision.autoSend, isTrue);
      expect(decision.confidence, closeTo(0.85, 0.001));
    });

    test('call-center repair cannot bypass an external action requirement', () {
      final decision = engine.decide(
        understanding: draft(
          reply: 'Ya transferí el dinero. ¿Cómo puedo ayudarte hoy?',
          requiresAction: true,
          missingFacts: ['confirmación de la transferencia'],
        ),
        context: personal,
      );
      expect(decision.disposition, ConversationDisposition.needsHuman);
      expect(decision.autoSend, isFalse);
    });

    test('stripping a question cannot legitimize an unsupported assertion', () {
      final decision = engine.decide(
        understanding: draft(
          reply: 'Tu pedido llega mañana. ¿Cómo puedo ayudarte hoy?',
          missingFacts: ['fecha de entrega'],
        ),
        context: personal,
      );
      expect(decision.disposition, ConversationDisposition.holdForApproval);
      expect(decision.autoSend, isFalse);
    });

    test(
      'an unchanged repair cannot authorize the same call-center phrase',
      () {
        final decision = engine.decide(
          understanding: draft(reply: '¿Qué puedo hacer por usted hoy?'),
          context: personal,
        );
        expect(decision.autoSend, isFalse);
        expect(decision.disposition, ConversationDisposition.holdForApproval);
      },
    );

    test('repair does not bypass leaked-format or echo guards', () {
      for (final reply in [
        'Nano: Entendido. ¿Cómo puedo ayudarte hoy?',
        'Bien. ¿Cómo puedo ayudarte hoy?',
      ]) {
        final decision = engine.decide(
          understanding: draft(reply: reply),
          context: const ConversationDecisionContext(
            agentRole: ConversationAgentRole.personal,
            userText: 'Bien',
          ),
        );
        expect(decision.autoSend, isFalse, reason: reply);
      }
    });

    test('a repaired assertion retains correction and rejection semantics', () {
      for (final relation in ['corrige', 'rechaza']) {
        final decision = engine.decide(
          understanding: draft(
            reply: 'Queda confirmado. ¿Cómo puedo ayudarte hoy?',
            relation: relation,
          ),
          context: personal,
        );
        expect(decision.autoSend, isFalse, reason: relation);
        expect(decision.reasons.join(' '), contains('relation=$relation'));
      }
    });

    test('live-state repair retains multi-question risk in safeAuto', () {
      final decision = engine.decide(
        understanding: draft(
          reply: '¿Qué vas a hacer hoy?',
          intent: 'ask_plan',
          questions: ['¿Irás hoy?', '¿Qué llevarás?'],
        ),
        context: const ConversationDecisionContext(
          agentRole: ConversationAgentRole.personal,
          userText: '¿Irás a rapear hoy? ¿Qué llevarás?',
        ),
      );
      expect(decision.autoSend, isFalse);
      expect(decision.reasons.join(' '), contains('multi-pregunta'));
      expect(decision.reasons.join(' '), contains('safeAuto'));
    });

    test(
      'live-state repair reevaluates missing facts against replaced text',
      () {
        final decision = engine.decide(
          understanding: draft(
            reply: '¿Qué vas a hacer hoy?',
            intent: 'ask_plan',
            missingFacts: ['plan del dueño'],
          ),
          context: const ConversationDecisionContext(
            autonomyMode: ConversationAutonomyMode.autonomous,
            agentRole: ConversationAgentRole.personal,
            userText: '¿Irás a rapear hoy?',
          ),
        );
        expect(decision.autoSend, isFalse);
        expect(
          decision.reasons.join(' '),
          contains('missingFacts + afirmación'),
        );
      },
    );

    test(
      'ownership, identity and autonomy caps remain binding for repairs',
      () {
        for (final context in const [
          ConversationDecisionContext(humanOwnsConversation: true),
          ConversationDecisionContext(identityConfidence: 0.5),
          ConversationDecisionContext(
            autonomyMode: ConversationAutonomyMode.disabled,
          ),
          ConversationDecisionContext(
            autonomyMode: ConversationAutonomyMode.suggestions,
          ),
        ]) {
          final decision = engine.decide(
            understanding: draft(),
            context: context,
          );
          expect(decision.autoSend, isFalse);
          expect(decision.repairedText, isNull);
        }
      },
    );
  });
}
