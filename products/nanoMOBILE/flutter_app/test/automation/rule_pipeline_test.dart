import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/domain/automation_goal.dart';
import 'package:nanoai/features/automation/domain/automation_result.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_object.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_memory.dart';
import 'package:nanoai/features/automation/engine/scheduling/event_dedupe_store.dart';
import 'package:nanoai/features/automation/engine/scheduling/rule_dispatcher.dart';
import 'package:nanoai/features/automation/engine/scheduling/rule_engine.dart';
import 'package:nanoai/features/automation/engine/scheduling/rule_pipeline.dart';
import 'package:nanoai/features/automation/engine/scheduling/rule_registry.dart';
import 'package:nanoai/features/automation/engine/scheduling/scheduled_rule.dart';
import 'package:nanoai/features/automation/engine/scheduling/trigger.dart';

NotificationObject notif({
  String sender = 'Juan',
  String pkg = 'com.whatsapp',
}) => NotificationObject.fromMap({
  'key': 'k1',
  'package': pkg,
  'sender': sender,
  'conversationTitle': '$sender P',
  'title': 'WhatsApp',
  'text': 'hola',
  'messageText': 'hola',
  'remoteInputKey': 'ri1',
  'canReply': true,
  'postTime': 1,
  'isGroup': false,
  'isSummary': false,
  'actions': <String>[],
  'ongoing': false,
});

const ok = AutomationResult(
  executionId: 'x',
  status: AutomationResultStatus.completed,
  reason: 'ok',
);

void main() {
  ScheduledRule rule({
    RuleAction action = RuleAction.reply,
    String message = 'ahora te escribo',
    String sender = 'juan',
  }) => ScheduledRule(
    id: 'r1',
    trigger: NotificationTrigger(
      packageName: 'com.whatsapp',
      senderMatch: sender,
    ),
    action: action,
    message: message,
    createdAt: DateTime(2026),
  );

  group('RuleDispatcher', () {
    test(
      'reply → ejecuta goal grounded en remitente + texto autorizado',
      () async {
        final goals = <String>[];
        final dispatcher = RuleDispatcher((
          goal, {
          AutomationOptions? options,
        }) async {
          goals.add(goal.text);
          return ok;
        });
        final r = await dispatcher.dispatch(rule(), notif());
        expect(r.outcome, RuleOutcome.replyVerified);
        expect(goals, ['responde a Juan que ahora te escribo']);
      },
    );

    test('reply sin mensaje → failed', () async {
      final dispatcher = RuleDispatcher(
        (_, {AutomationOptions? options}) async => ok,
      );
      final r = await dispatcher.dispatch(rule(message: ''), notif());
      expect(r.outcome, RuleOutcome.failed);
    });

    test('notify → notified sin ejecutar goal', () async {
      var called = false;
      final dispatcher = RuleDispatcher((
        _, {
        AutomationOptions? options,
      }) async {
        called = true;
        return ok;
      });
      final r = await dispatcher.dispatch(
        rule(action: RuleAction.notify),
        notif(),
      );
      expect(r.outcome, RuleOutcome.notified);
      expect(called, isFalse);
    });

    test('draft → drafted', () async {
      final dispatcher = RuleDispatcher(
        (_, {AutomationOptions? options}) async => ok,
      );
      final r = await dispatcher.dispatch(
        rule(action: RuleAction.draft),
        notif(),
      );
      expect(r.outcome, RuleOutcome.drafted);
    });

    test('coordinator falla → failed', () async {
      final dispatcher = RuleDispatcher(
        (_, {AutomationOptions? options}) async => const AutomationResult(
          executionId: 'x',
          status: AutomationResultStatus.failed,
          reason: 'x',
        ),
      );
      final r = await dispatcher.dispatch(rule(), notif());
      expect(r.outcome, RuleOutcome.failed);
    });
  });

  group('RulePipeline', () {
    test('notificación de Juan → match → dispatch → markFired', () async {
      final registry = RuleRegistry(MemoryRuleStore());
      await registry.load();
      registry.add(rule());

      final goals = <String>[];
      final dispatcher = RuleDispatcher((
        goal, {
        AutomationOptions? options,
      }) async {
        goals.add(goal.text);
        return ok;
      });
      final pipeline = RulePipeline(
        registry: registry,
        engine: const RuleEngine(),
        dedupe: MemoryEventDedupeStore(),
        memory: MemoryConversationMemoryStore(),
        dispatcher: dispatcher,
      );

      final results = await pipeline.onNotification(notif(sender: 'Juan'));
      expect(results, hasLength(1));
      expect(results.first.outcome, RuleOutcome.replyVerified);
      expect(registry.rules.first.lastFiredAt, isNotNull);
      expect(goals, ['responde a Juan que ahora te escribo']);
    });

    test(
      'notificación de otro remitente → sin match → vacío y sin markFired',
      () async {
        final registry = RuleRegistry(MemoryRuleStore());
        await registry.load();
        registry.add(rule());

        final dispatcher = RuleDispatcher(
          (_, {AutomationOptions? options}) async => ok,
        );
        final pipeline = RulePipeline(
          registry: registry,
          engine: const RuleEngine(),
          dedupe: MemoryEventDedupeStore(),
          memory: MemoryConversationMemoryStore(),
          dispatcher: dispatcher,
        );

        final results = await pipeline.onNotification(notif(sender: 'María'));
        expect(results, isEmpty);
        expect(registry.rules.first.lastFiredAt, isNull);
      },
    );
  });
}
