import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/notifications/conversation_understanding.dart';
import 'package:nanoai/features/automation/personal_agent/application/conversation_decision_engine.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_agent_role.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_autonomy_mode.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_decision.dart';

void main() {
  const engine = ConversationDecisionEngine();
  for (final input in ['Hola, ¿todo bien?', 'ola!! todo bn??', 'bien y tu ?']) {
    test('Bienestar cotidiano llega a envío: $input', () {
      final decision = engine.decide(
        understanding: const ConversationUnderstanding(
          reply: 'Estoy bien, gracias por preguntar.',
        ),
        context: ConversationDecisionContext(
          userText: input,
          agentRole: ConversationAgentRole.personal,
          autonomyMode: ConversationAutonomyMode.autonomous,
        ),
        allowRepair: false,
      );
      expect(decision.autoSend, isTrue, reason: decision.reasons.join('; '));
    });
  }

  for (final reply in [
    'Estoy bien en casa.',
    'Estoy bien, estoy trabajando.',
    'Estoy muy bien y voy para el centro.',
    'Estoy bien pero tengo hambre.',
    'No estoy seguro, estoy en casa.',
  ]) {
    test('La cortesía no oculta actividad: $reply', () {
      final decision = engine.decide(
        understanding: ConversationUnderstanding(reply: reply),
        context: const ConversationDecisionContext(
          userText: 'Hola, ¿todo bien?',
          agentRole: ConversationAgentRole.personal,
          autonomyMode: ConversationAutonomyMode.autonomous,
        ),
        allowRepair: false,
      );
      expect(decision.disposition, ConversationDisposition.holdForApproval);
      expect(decision.autoSend, isFalse);
    });
  }
}
