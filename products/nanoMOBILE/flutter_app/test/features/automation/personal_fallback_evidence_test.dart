import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/conversation/turn_context_router.dart';
import 'package:nanoai/features/automation/engine/conversation/turn_knowledge_router.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_object.dart';
import 'package:nanoai/features/automation/personal_agent/application/personal_conversation_resolver.dart';

class _KnowledgeSpy implements TurnKnowledgeRouter {
  int calls = 0;
  @override
  bool needsExternalKnowledge(String text) => true;
  @override
  Future<ExternalKnowledgeResult> fetchKnowledge(String text) async {
    calls++;
    return ExternalKnowledgeResult.empty;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  for (final text in ['qué haces', 'donde estas?']) {
    test('Estado personal no se busca en Web: $text', () async {
      final spy = _KnowledgeSpy();
      final analysis = const TurnContextRouter().analyze(
        notification: NotificationObject.fromMap({
          'text': text,
          'messageText': text,
          'packageName': 'com.whatsapp',
        }),
        memory: null,
        isBusinessChannel: false,
      );
      final reply = await PersonalConversationResolver(knowledgeRouter: spy)
          .resolveFallbackTurn(
            analysis: analysis,
            memory: null,
            conversationId: 'synthetic',
          );
      expect(reply, isNull);
      expect(spy.calls, 0);
    });
  }
  test('Una pregunta general conserva el respaldo configurado', () async {
    final spy = _KnowledgeSpy();
    final analysis = const TurnContextRouter().analyze(
      notification: NotificationObject.fromMap({
        'text': 'explicame la fotosintesis',
        'messageText': 'explicame la fotosintesis',
        'packageName': 'com.whatsapp',
      }),
      memory: null,
      isBusinessChannel: false,
    );
    await PersonalConversationResolver(
      knowledgeRouter: spy,
    ).resolveFallbackTurn(
      analysis: analysis,
      memory: null,
      conversationId: 'synthetic',
    );
    expect(spy.calls, greaterThan(0));
  });
}
