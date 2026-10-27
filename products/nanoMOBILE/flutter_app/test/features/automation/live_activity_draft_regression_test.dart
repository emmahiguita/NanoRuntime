import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_draft_writer.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_object.dart';
import 'package:nanoai/features/automation/personal_agent/application/conversation_decision_engine.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_agent_role.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_autonomy_mode.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_decision.dart';

void main() {
  final notification = NotificationObject.fromMap({
    'key': 'activity-regression',
    'packageName': 'com.whatsapp',
    'text': 'que haces?',
    'messageText': 'que haces?',
  });
  const context = ConversationDecisionContext(
    userText: 'que haces?',
    agentRole: ConversationAgentRole.personal,
    autonomyMode: ConversationAutonomyMode.autonomous,
  );
  for (final reply in [
    'No estoy seguro.',
    'No lo sé con certeza.',
    'No tengo esa información.',
    'No tengo información sobre su actividad actual.',
    'No cuento con datos actuales.',
    'No dispongo de esa información.',
    'No ha informado de su actividad actual.',
    'No hay información sobre su actividad actual.',
  ]) {
    test('Actividad desconocida admite texto natural: $reply', () {
      final draft = parseNotificationDraftOutput(
        reply,
        notification,
        'activity-regression',
        allowPlainText: true,
      );
      expect(draft, isNotNull);
      final decision = const ConversationDecisionEngine().decide(
        understanding: draft!.understanding,
        context: context,
        allowRepair: false,
      );
      expect(decision.autoSend, isTrue, reason: decision.reasons.join('; '));
    });
  }
  test('Texto natural no autoriza inventar actividad', () {
    final draft = parseNotificationDraftOutput(
      'Estoy trabajando en casa.',
      notification,
      'activity-regression',
      allowPlainText: true,
    );
    expect(draft, isNotNull);
    final decision = const ConversationDecisionEngine().decide(
      understanding: draft!.understanding,
      context: context,
      allowRepair: false,
    );
    expect(decision.disposition, ConversationDisposition.holdForApproval);
  });
  for (final reply in [
    'Aquí conversando contigo. ¿Cómo va tu día?',
    'Estoy aquí conversando contigo. ¿Y tú?',
    'Estoy charlando contigo, cuéntame cómo vas.',
    'Estoy conversando contigo. ¿Qué estás haciendo?',
    'Estoy aquí, ¿y tú?',
    // Salida real del fixture Gemma GPU ante «que estas hciendo ?».
    'Estoy aquí, listo para ayudarte con lo que necesites.',
  ]) {
    test('Presencia en el chat permite respuesta natural: $reply', () {
      final draft = parseNotificationDraftOutput(
        reply,
        notification,
        'activity-regression',
        allowPlainText: true,
      );
      expect(draft, isNotNull);
      final decision = const ConversationDecisionEngine().decide(
        understanding: draft!.understanding,
        context: context,
        allowRepair: false,
      );
      expect(decision.autoSend, isTrue, reason: decision.reasons.join('; '));
    });
  }
  test('Presencia en el chat no oculta actividad física añadida', () {
    final draft = parseNotificationDraftOutput(
      'Estoy conversando contigo, estoy en casa.',
      notification,
      'activity-regression',
      allowPlainText: true,
    );
    final decision = const ConversationDecisionEngine().decide(
      understanding: draft!.understanding,
      context: context,
      allowRepair: false,
    );
    expect(decision.disposition, ConversationDisposition.holdForApproval);
  });
  test('Admitir desconocimiento no oculta actividad inventada', () {
    final draft = parseNotificationDraftOutput(
      'No estoy seguro, estoy en casa.',
      notification,
      'activity-regression',
      allowPlainText: true,
    );
    expect(draft, isNotNull);
    final decision = const ConversationDecisionEngine().decide(
      understanding: draft!.understanding,
      context: context,
      allowRepair: false,
    );
    expect(decision.disposition, ConversationDisposition.holdForApproval);
  });
}
