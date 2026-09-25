import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/conversation/conversation_reply_composer.dart';
import 'package:nanoai/features/automation/engine/conversation/personal_style_formatter.dart';
import 'package:nanoai/features/automation/engine/conversation/turn_knowledge_router.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_object.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_agent_role.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_autonomy_mode.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_decision.dart';

void main() {
  group('TurnKnowledgeRouter & PersonalStyleFormatter Tests', () {
    final knowledgeRouter = RuntimeTurnKnowledgeRouter();
    const styleFormatter = RuntimePersonalStyleFormatter();

    test('TurnKnowledgeRouter detecta necesidad de conocimiento externo', () {
      expect(
        knowledgeRouter.needsExternalKnowledge('¿Viste qué pasó hoy con Android 17?'),
        isTrue,
      );
      expect(
        knowledgeRouter.needsExternalKnowledge('¿Cuánto está el precio del dólar?'),
        isTrue,
      );
      expect(
        knowledgeRouter.needsExternalKnowledge('¿Cómo quedó el partido de hoy?'),
        isTrue,
      );
      expect(
        knowledgeRouter.needsExternalKnowledge('Hola emma cómo vas?'),
        isFalse,
      );
      expect(
        knowledgeRouter.needsExternalKnowledge('¿Cuánto vale el teléfono negro?'),
        isFalse,
      );
    });

    test('PersonalStyleFormatter formatea hechos crudos en estilo auténtico', () {
      const rawFacts =
          '### 🌐 Búsqueda Web: "Android 17"\n\n'
          'Google presentó la primera vista previa para desarrolladores de Android 17 hoy. '
          'Incluye mejoras en gestión de memoria y seguridad.\n\n'
          '**Puntos destacados:**\n• Mejoras de memoria';

      final styled = styleFormatter.formatKnowledge(
        rawFacts: rawFacts,
        query: 'Android 17',
      );

      expect(styled.text, isNotEmpty);
      expect(styled.text.contains('### 🌐'), isFalse);
      expect(styled.text.contains('**Puntos destacados:**'), isFalse);
      expect(styled.suggestions.length, greaterThanOrEqualTo(2));
      expect(styled.understanding.intent, 'external_knowledge_styled');
      expect(styled.understanding.hasReply, isTrue);
    });

    test('ConversationReplyComposer resuelve preguntas de conocimiento externo sin LLM', () async {
      final mockKnowledgeRouter = _MockKnowledgeRouter(
        facts: 'Google lanzó hoy la primera beta para desarrolladores de Android 17.',
      );

      final composer = RuntimeConversationReplyComposer(
        draftSource: (n) async => null, // LLM apagado o no disponible
        knowledgeRouter: mockKnowledgeRouter,
        styleFormatter: const RuntimePersonalStyleFormatter(),
        decisionContext: (n) => const ConversationDecisionContext(
          agentRole: ConversationAgentRole.personal,
          autonomyMode: ConversationAutonomyMode.safeAuto,
          identityConfidence: 1.0,
        ),
      );

      final notif = _createNotification(
        text: '¿Viste qué pasó hoy con Android 17?',
      );
      final result = await composer.compose(notif);

      expect(result, isNotNull);
      expect(result!.isFastPath, isTrue);
      expect(result.text, contains('Android 17'));
      expect(result.text.contains('Pillá') || result.text.contains('vi') || result.text.contains('mirando'), isTrue);
      expect(result.decision.disposition, ConversationDisposition.autoSend);
    });
  });
}

final class _MockKnowledgeRouter implements TurnKnowledgeRouter {
  final String facts;
  _MockKnowledgeRouter({required this.facts});

  @override
  bool needsExternalKnowledge(String text) =>
      text.toLowerCase().contains('android 17');

  @override
  Future<ExternalKnowledgeResult> fetchKnowledge(String text) async {
    return ExternalKnowledgeResult(
      query: text,
      rawKnowledge: facts,
      source: 'mock_provider',
    );
  }

  @override
  Future<void> dispose() async {}
}

NotificationObject _createNotification({
  required String text,
  String packageName = 'com.whatsapp',
  String sender = 'Carlos P.',
}) {
  return NotificationObject(
    key: 'wa_test_${text.hashCode}',
    packageName: packageName,
    title: sender,
    text: text,
    messageText: text,
    messageTimestamp: DateTime.now().millisecondsSinceEpoch,
    sender: sender,
    senderKey: 'carlos_p',
    senderUri: '',
    conversationTitle: sender,
    conversationId: 'wa_carlos',
    shortcutId: 'shortcut_wa_carlos',
    locusId: 'locus_wa_carlos',
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
