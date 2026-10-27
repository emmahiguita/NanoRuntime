import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/personal_agent/domain/group_mention_policy.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_decision.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_autonomy_mode.dart';
import 'package:nanoai/features/automation/engine/scheduling/rule_dispatcher.dart';
import 'package:nanoai/features/automation/engine/scheduling/scheduled_rule.dart';
import 'package:nanoai/features/automation/engine/scheduling/trigger.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_object.dart';
import 'package:nanoai/features/automation/domain/automation_result.dart';

void main() {
  bool addressed(String text, {bool group = true}) => GroupMentionPolicy.allows(
    isGroup: group,
    text: text,
    ownerName: 'Emmanuel Higuita',
    nickname: 'Emma',
    aliases: 'Emmanuel, 573001234567; @Manu',
  );

  test('Solo grupos requieren mención propia explícita', () {
    for (final text in [
      'Hola',
      '@Juan hola',
      'Emmanuel, hola',
      '@Emmanuelito',
      'emma@example.com',
      'juan@Emma.com',
      '@Emma_otra',
      '@5730012345678',
    ]) {
      expect(addressed(text), isFalse, reason: text);
      expect(addressed(text, group: false), isTrue, reason: text);
    }
    for (final text in [
      '@Emmanuel Higuita ¿vienes?',
      'Hola @Emma!',
      '@EMMANUEL, hola',
      '¿@Manu?',
      '@573001234567 hola',
    ]) {
      expect(addressed(text), isTrue, reason: text);
    }
    expect(
      GroupMentionPolicy.allows(isGroup: true, text: '@Juan', ownerName: ''),
      isFalse,
    );
  });

  test('Tolera tildes, pero no confunde otra persona ni cualquier arroba', () {
    expect(
      GroupMentionPolicy.allows(
        isGroup: true,
        text: '@Jose Luis hola',
        ownerName: 'José Luis',
      ),
      isTrue,
    );
    expect(addressed('@todo el mundo'), isFalse);
    expect(addressed('@@Emma'), isFalse);
  });

  NotificationObject notification(String text, {bool group = true}) =>
      NotificationObject.fromMap({
        'key': 'event',
        'package': 'com.whatsapp',
        'title': 'Juan',
        'sender': 'Juan',
        'messageText': text,
        'text': text,
        'shortcutId': group ? '123@g.us' : 'juan',
        'isGroup': group,
        'canReply': true,
        'remoteInputKey': 'reply',
        'actionIndex': 0,
        'actions': ['Responder'],
        'postTime': DateTime.now().millisecondsSinceEpoch,
      });
  ScheduledRule rule({
    bool dynamic = false,
    RuleAction action = RuleAction.reply,
  }) => ScheduledRule(
    id: 'group',
    trigger: const NotificationTrigger(),
    action: action,
    message: dynamic ? '' : 'Hola',
    dynamicReply: dynamic,
    createdAt: DateTime.now(),
  );

  test(
    'Sin mención no genera ni envía: dinámico, fijo y archivo; privado continúa',
    () async {
      var drafts = 0, sends = 0, media = 0;
      final dispatcher = RuleDispatcher(
        (goal, {options}) async {
          sends++;
          return const AutomationResult(
            executionId: 'test',
            status: AutomationResultStatus.failed,
            reason: 'test',
          );
        },
        draftSource: (_) async {
          drafts++;
          return null;
        },
        shareMedia: (_, __, ___) async {
          media++;
          return true;
        },
        decisionContext: (n) => ConversationDecisionContext(
          autonomyMode: ConversationAutonomyMode.autonomous,
          groupReplyAllowed: addressed(n.interpretableText, group: n.isGroup),
        ),
      );
      for (final r in [
        rule(dynamic: true),
        rule(),
        rule(action: RuleAction.sendMedia),
      ]) {
        final result = await dispatcher.dispatch(r, notification('Hola @Juan'));
        expect(result.outcome, RuleOutcome.ignored);
      }
      expect(drafts, 0);
      expect(sends, 0);
      expect(media, 0);
      await dispatcher.dispatch(rule(), notification('Hola', group: false));
      expect(sends, 1);
      await dispatcher.dispatch(rule(), notification('@Emma hola'));
      expect(sends, 2);
    },
  );

  test('Revisa permiso de grupo también después de la pausa', () async {
    var allowed = true, sends = 0;
    final dispatcher = RuleDispatcher(
      (goal, {options}) async {
        sends++;
        return const AutomationResult(
          executionId: 'test',
          status: AutomationResultStatus.failed,
          reason: 'test',
        );
      },
      decisionContext: (_) => ConversationDecisionContext(
        autonomyMode: ConversationAutonomyMode.autonomous,
        groupReplyAllowed: allowed,
      ),
      replyDelay: () {
        allowed = false;
        return const Duration(milliseconds: 1);
      },
    );
    final result = await dispatcher.dispatch(
      rule(),
      notification('@Emma hola'),
    );
    expect(result.outcome, RuleOutcome.ignored);
    expect(sends, 0);
  });
}
