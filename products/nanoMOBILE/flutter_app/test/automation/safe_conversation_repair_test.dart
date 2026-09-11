import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/language/safe_conversation_repair.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_decision.dart';

void main() {
  group('SafeConversationRepair WA-LIVE-STATE-REPAIR-01', () {
    const repairer = SafeConversationRepair();

    test('Repara liveStateAffirmed y liveStateQuestionMirror con respuesta honesta segura', () {
      final r1 = repairer.repair(
        RepairCase.liveStateAffirmed,
        reply: 'Estoy grabando en el estudio',
        userText: '¿Qué haces?',
      );
      expect(r1, equals('Por acá tranquilo por ahora.'));

      final r2 = repairer.repair(
        RepairCase.liveStateQuestionMirror,
        reply: '¿Vas a salir hoy?',
        userText: '¿Vas a salir hoy?',
      );
      expect(r2, equals('Todavía no sé si voy a ir hoy.'));
    });

    test('Repara callCenterPhrase eliminando muletilla de operador', () {
      final r = repairer.repair(
        RepairCase.callCenterPhrase,
        reply: '¡Hola! ¿Cómo puedo ayudarte hoy?',
        userText: 'Hola',
      );
      expect(r, equals('¡Hola!'));
    });

    test('Echo del cliente devuelve null (retiene de forma genuina)', () {
      final r = repairer.repair(
        RepairCase.echoReply,
        reply: 'bien y tu como estas?',
        userText: 'bien y tu como estas?',
      );
      expect(r, isNull);
    });

    test('ConversationDecision con qualityRepair y repairedText habilita autoSend', () {
      const decision = ConversationDecision(
        disposition: ConversationDisposition.qualityRepair,
        risk: ConversationRisk.low,
        confidence: 0.8,
        reasons: ['calidad reparada: LIVE STATE corregido'],
        repairedText: 'Todavía no lo tengo decidido.',
      );

      expect(decision.autoSend, isTrue);
      expect(decision.repairedText, equals('Todavía no lo tengo decidido.'));
    });

    test('ConversationDecision con qualityRepair sin repairedText NO habilita autoSend', () {
      const decision = ConversationDecision(
        disposition: ConversationDisposition.qualityRepair,
        risk: ConversationRisk.medium,
        confidence: 0.0,
        reasons: ['fallo irreparable'],
        repairedText: null,
      );

      expect(decision.autoSend, isFalse);
    });
  });
}
