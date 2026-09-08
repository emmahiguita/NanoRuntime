import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/services/device_metrics.dart';
import 'package:nanoai/features/automation/engine/language/pragmatic_fast_path.dart';
import 'package:nanoai/features/automation/personal_agent/application/conversation_decision_engine.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_autonomy_mode.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_decision.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_agent_role.dart';

void main() {
  group('PragmaticFastPath Linguistic Logic', () {
    const fastPath = PragmaticFastPath();
    const decisionEngine = ConversationDecisionEngine();

    test('resolves reciprocal wellbeing: "bien y tu"', () async {
      final res = await fastPath.resolve(text: 'bien y tu', conversationId: 'conv-123');
      expect(res, isNotNull);
      expect(res!.reply, isNotEmpty);
      expect(res.reply.contains('¿'), isTrue);
      // Ensures it does not sound like a call center
      expect(res.reply.toLowerCase().contains('puedo ayudarte'), isFalse);

      // Verify that decision engine approves it for autoSend in safeAuto
      final decision = decisionEngine.decide(
        understanding: res.understanding,
        context: const ConversationDecisionContext(
          autonomyMode: ConversationAutonomyMode.safeAuto,
          identityConfidence: 1.0,
          agentRole: ConversationAgentRole.personal,
          userText: 'bien y tu',
        ),
      );
      expect(decision.autoSend, isTrue, reason: 'Failed reasons: ${decision.reasons}');
    });

    test('resolves reciprocal wellbeing: "todo bien y vos"', () async {
      final res = await fastPath.resolve(text: 'todo bien y vos', conversationId: 'conv-456');
      expect(res, isNotNull);
      expect(res!.reply, isNotEmpty);

      final decision = decisionEngine.decide(
        understanding: res.understanding,
        context: const ConversationDecisionContext(
          autonomyMode: ConversationAutonomyMode.safeAuto,
          identityConfidence: 1.0,
          agentRole: ConversationAgentRole.personal,
          userText: 'todo bien y vos',
        ),
      );
      expect(decision.autoSend, isTrue, reason: 'Failed reasons: ${decision.reasons}');
    });

    test('resolves pure greeting: "hola emma"', () async {
      final res = await fastPath.resolve(text: 'hola emma', conversationId: 'conv-123');
      expect(res, isNotNull);
      expect(res!.reply.toLowerCase().contains('hola') || res.reply.toLowerCase().contains('buenas'), isTrue);

      final decision = decisionEngine.decide(
        understanding: res.understanding,
        context: const ConversationDecisionContext(
          autonomyMode: ConversationAutonomyMode.safeAuto,
          identityConfidence: 1.0,
          agentRole: ConversationAgentRole.personal,
          userText: 'hola emma',
        ),
      );
      expect(decision.autoSend, isTrue, reason: 'Failed reasons: ${decision.reasons}');
    });

    test('resolves wellbeing inquiry: "cómo estás"', () async {
      final res = await fastPath.resolve(text: 'cómo estás', conversationId: 'conv-123');
      expect(res, isNotNull);
      expect(res!.reply, isNotEmpty);

      final decision = decisionEngine.decide(
        understanding: res.understanding,
        context: const ConversationDecisionContext(
          autonomyMode: ConversationAutonomyMode.safeAuto,
          identityConfidence: 1.0,
          agentRole: ConversationAgentRole.personal,
          userText: 'cómo estás',
        ),
      );
      expect(decision.autoSend, isTrue, reason: 'Failed reasons: ${decision.reasons}');
    });

    test('resolves activity inquiry: "qué haces"', () async {
      final res = await fastPath.resolve(text: 'qué haces', conversationId: 'conv-123');
      expect(res, isNotNull);
      expect(res!.reply, isNotEmpty);

      final decision = decisionEngine.decide(
        understanding: res.understanding,
        context: const ConversationDecisionContext(
          autonomyMode: ConversationAutonomyMode.safeAuto,
          identityConfidence: 1.0,
          agentRole: ConversationAgentRole.personal,
          userText: 'qué haces',
        ),
      );
      expect(decision.autoSend, isTrue, reason: 'Failed reasons: ${decision.reasons}');
    });

    test('resolves day inquiry: "qué tal va tu día"', () async {
      final res = await fastPath.resolve(text: 'qué tal va tu día', conversationId: 'conv-123');
      expect(res, isNotNull);
      expect(res!.reply, isNotEmpty);
    });

    test('resolves presence question: "estás ahí"', () async {
      final res = await fastPath.resolve(text: 'estás ahí', conversationId: 'conv-123');
      expect(res, isNotNull);
      expect(res!.reply, isNotEmpty);
    });

    test('resolves help request: "parce lo necesito para una tarea"', () async {
      final res = await fastPath.resolve(text: 'parce lo necesito para una tarea', conversationId: 'conv-123');
      final lower = res!.reply.toLowerCase();
      expect(
        lower.contains('tarea') || lower.contains('dime') || lower.contains('cuentame') || lower.contains('hagale'),
        isTrue,
      );
    });

    test('resolves training question honestly without hallucination: "vas a ir hoy a entrenar?"', () async {
      final res = await fastPath.resolve(text: 'vas a ir hoy a entrenar?', conversationId: 'conv-123');
      expect(res, isNotNull);
      final lower = res!.reply.toLowerCase().replaceAll('é', 'e');
      expect(
        lower.contains('no se') ||
            lower.contains('no lo se') ||
            lower.contains('no estoy seguro'),
        isTrue,
        reason: 'Reply was: ${res.reply}',
      );

      final decision = decisionEngine.decide(
        understanding: res.understanding,
        context: const ConversationDecisionContext(
          autonomyMode: ConversationAutonomyMode.safeAuto,
          identityConfidence: 1.0,
          agentRole: ConversationAgentRole.personal,
          userText: 'vas a ir hoy a entrenar?',
        ),
      );
      expect(decision.autoSend, isTrue, reason: 'Failed reasons: ${decision.reasons}');
    });

    test('resolves negation cleanly: "no gracias"', () async {
      final res = await fastPath.resolve(text: 'no gracias', conversationId: 'conv-123');
      expect(res, isNotNull);
      expect(res!.reply, isNotEmpty);
      final decision = decisionEngine.decide(
        understanding: res.understanding,
        context: const ConversationDecisionContext(
          autonomyMode: ConversationAutonomyMode.safeAuto,
          identityConfidence: 1.0,
          agentRole: ConversationAgentRole.personal,
          userText: 'no gracias',
        ),
      );
      expect(decision.autoSend, isTrue);
    });

    test('resolves on-demand battery inquiry using DeviceMetrics: "cuánta batería tienes"', () async {
      final fastPathWithMetrics = PragmaticFastPath(
        metricsSource: () async => const DeviceMetricsData(
          ramAvailableMb: 2048,
          ramTotalMb: 4096,
          batteryPct: 74.0,
          isCharging: true,
          storageTotalGb: 64,
          storageFreeGb: 32,
          cpuTempC: 36.5,
          cpuCores: 8,
        ),
      );
      final res = await fastPathWithMetrics.resolve(
        text: 'cuánta batería tienes',
        conversationId: 'conv-batt',
      );
      expect(res, isNotNull);
      expect(res!.reply.contains('74%'), isTrue);
      expect(res.reply.contains('cargando'), isTrue);

      final decision = decisionEngine.decide(
        understanding: res.understanding,
        context: const ConversationDecisionContext(
          autonomyMode: ConversationAutonomyMode.safeAuto,
          identityConfidence: 1.0,
          agentRole: ConversationAgentRole.personal,
          userText: 'cuánta batería tienes',
        ),
      );
      expect(decision.autoSend, isTrue);
    });

    test('resolves multi-intent integrated message cleanly', () async {
      final res = await fastPath.resolve(
        text: 'hola emma cómo estás, qué tal va tu día, vas a ir hoy a entrenar?',
        conversationId: 'conv-multi',
      );
      expect(res, isNotNull);
      expect(res!.reply, isNotEmpty);
      expect(res.reply.split(' ').length, lessThanOrEqualTo(25));

      final decision = decisionEngine.decide(
        understanding: res.understanding,
        context: const ConversationDecisionContext(
          autonomyMode: ConversationAutonomyMode.safeAuto,
          identityConfidence: 1.0,
          agentRole: ConversationAgentRole.personal,
          userText: 'hola emma cómo estás, qué tal va tu día, vas a ir hoy a entrenar?',
        ),
      );
      expect(decision.autoSend, isTrue, reason: 'Failed reasons: ${decision.reasons}');
    });

    test('escapes commercial intent to LLM / catalog: "cuánto vale el negro?"', () async {
      final res = await fastPath.resolve(text: 'cuánto vale el negro?', conversationId: 'conv-123');
      expect(res, isNull);
    });

    test('escapes support complaints to LLM / support: "el pedido me llegó malo"', () async {
      final res = await fastPath.resolve(text: 'el pedido me llegó malo', conversationId: 'conv-123');
      expect(res, isNull);
    });

    test('escapes automation commands: "abre WhatsApp"', () async {
      final res = await fastPath.resolve(text: 'abre WhatsApp', conversationId: 'conv-123');
      expect(res, isNull);
    });
  });
}
