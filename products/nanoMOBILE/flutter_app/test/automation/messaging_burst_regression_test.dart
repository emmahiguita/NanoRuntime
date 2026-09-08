import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_object.dart';
import 'package:nanoai/features/automation/engine/scheduling/burst_turn_gate.dart';
import 'package:nanoai/features/automation/engine/scheduling/rule_dispatcher.dart';
import 'package:nanoai/features/automation/engine/scheduling/rule_pipeline.dart';
import 'package:nanoai/features/automation/engine/scheduling/rule_registry.dart';
import 'package:nanoai/features/automation/engine/scheduling/rule_engine.dart';
import 'package:nanoai/features/automation/engine/scheduling/scheduled_rule.dart';
import 'package:nanoai/features/automation/engine/scheduling/trigger.dart';
import 'package:nanoai/features/automation/engine/scheduling/event_dedupe_store.dart';
import 'package:nanoai/features/automation/engine/scheduling/contact_rate_limiter.dart';
import 'package:nanoai/features/automation/engine/scheduling/turn_supersede_guard.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_memory.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_key.dart';
import 'package:nanoai/features/automation/domain/automation_result.dart';

NotificationObject event(
  int i, {
  String contact = 'Juan',
  String? text,
  String package = 'com.whatsapp',
}) => NotificationObject.fromMap({
  'key': contact,
  'package': package,
  'sender': contact,
  'shortcutId': contact,
  'title': contact,
  'text': text ?? 'M$i',
  'messageText': text ?? 'M$i',
  'messageTimestamp': i,
  'postTime': i,
  'canReply': true,
  'remoteInputKey': 'reply',
});

class Rate extends Fake implements ContactRateLimiter {
  @override
  ContactRatePolicy get policy => const ContactRatePolicy();
  @override
  Future<int> replyCount(ConversationKey key, {required DateTime at}) async =>
      0;
  @override
  Future<void> recordReply(ConversationKey key, {required DateTime at}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('empty batch resolves without a timer', () async {
    expect(await BurstTurnGate().submitAll([], (_) async => []), isEmpty);
  });
  testWidgets('20 fragments wait for settle and retain long first message', (
    tester,
  ) async {
    final turns = <NotificationObject>[];
    final gate = BurstTurnGate();
    final fragments = [
      event(1, text: 'contexto ${'largo ' * 400}'),
      for (var i = 2; i <= 20; i++) event(i),
    ];
    final pending = gate.submitAll(fragments, (n) async {
      turns.add(n);
      return [];
    });
    expect(turns, isEmpty);
    await tester.pump(const Duration(milliseconds: 799));
    expect(turns, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    await pending;
    expect(turns, hasLength(1));
    expect(turns.single.text, fragments.map((n) => n.text.trim()).join('\n'));
  });
  testWidgets('timestamp order and separate conversations', (tester) async {
    final turns = <NotificationObject>[];
    final gate = BurstTurnGate();
    final pending = gate.submitAll(
      [event(3), event(1), event(2), event(4, contact: 'Sara')],
      (n) async {
        turns.add(n);
        return [];
      },
    );
    await tester.pump(const Duration(seconds: 1));
    await pending;
    expect(turns.map((n) => n.text), containsAll(['M1\nM2\nM3', 'M4']));
  });
  testWidgets('new fragments during inference form one following turn', (
    tester,
  ) async {
    final hold = Completer<List<RuleDispatchResult>>();
    final turns = <String>[];
    final gate = BurstTurnGate();
    Future<List<RuleDispatchResult>> run(NotificationObject n) async {
      turns.add(n.text);
      return turns.length == 1 ? hold.future : [];
    }

    final first = gate.submit(event(1), run);
    await tester.pump(const Duration(seconds: 1));
    final next = gate.submitAll([for (var i = 2; i <= 21; i++) event(i)], run);
    await tester.pump(const Duration(seconds: 4));
    expect(turns, hasLength(1));
    hold.complete([]);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await Future.wait([first, next]);
    expect(turns, hasLength(2));
    expect(turns.last.split('\n'), hasLength(20));
  });
  testWidgets('continuous fragments respect maxWait', (tester) async {
    var turns = 0;
    final gate = BurstTurnGate();
    final pending = <Future<List<RuleDispatchResult>>>[];
    for (var i = 1; i <= 6; i++) {
      pending.add(
        gate.submit(event(i), (_) async {
          turns++;
          return [];
        }),
      );
      await tester.pump(const Duration(milliseconds: 500));
    }
    await Future.wait(pending);
    expect(turns, 1);
  });
  testWidgets(
    'live and replay share readiness, noise and original event dedupe',
    (tester) async {
      final registry = RuleRegistry(MemoryRuleStore());
      final ready = Completer<void>();
      final dedupe = MemoryEventDedupeStore();
      var turns = 0;
      var inbound = 0;
      final pipeline = RulePipeline(
        registry: registry,
        engine: const RuleEngine(),
        dedupe: dedupe,
        memory: MemoryConversationMemoryStore(),
        rateLimiter: Rate(),
        readiness: ready.future,
        dispatcher: RuleDispatcher(
          (_, {options}) async => throw StateError('unexpected send'),
          notifyLocal: (_, body) async {
            turns++;
            return true;
          },
        ),
      );
      final gate = BurstTurnGate(onInbound: (_) => inbound++);
      final first = pipeline.submitNotifications([
        event(1),
        event(2, text: 'M1'),
      ], gate);
      final replay = pipeline.submitNotifications([event(1)], gate);
      final noise = pipeline.submitNotifications([
        event(3, package: 'com.google.android.googlequicksearchbox'),
      ], gate);
      await tester.pump(const Duration(seconds: 1));
      expect(inbound, 0);
      registry.add(
        ScheduledRule(
          id: 'all',
          trigger: const NotificationTrigger(),
          action: RuleAction.notify,
          createdAt: DateTime(2026),
        ),
      );
      ready.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await Future.wait([first, replay, noise]);
      expect(inbound, 2); // Same text with distinct event timestamps survives.
      expect(turns, 1);
      final reborn = RulePipeline(
        registry: registry,
        engine: const RuleEngine(),
        dedupe: dedupe,
        memory: MemoryConversationMemoryStore(),
        rateLimiter: Rate(),
        dispatcher: RuleDispatcher(
          (_, {options}) async => throw StateError('duplicate send'),
        ),
      );
      expect(
        await reborn.submitNotifications([
          event(1),
          event(2, text: 'M1'),
        ], gate),
        isEmpty,
      );
      expect(inbound, 2);
    },
  );
  testWidgets('captured turn version survives async work before dispatch', (
    tester,
  ) async {
    final guard = TurnSupersedeGuard();
    final n = event(1);
    final id = resolveConversationIdentity(n).key.id;
    guard.bump(id);
    final version = guard.versionOf(id);
    guard.bump(id);
    var sends = 0;
    final dispatcher = RuleDispatcher((_, {options}) async {
      sends++;
      return const AutomationResult(
        executionId: 'x',
        status: AutomationResultStatus.completed,
        reason: 'ok',
      );
    }, supersedeGuard: guard);
    final result = await dispatcher.dispatch(
      ScheduledRule(
        id: 'reply',
        trigger: const NotificationTrigger(),
        action: RuleAction.reply,
        message: 'obsolete',
        createdAt: DateTime(2026),
      ),
      n,
      capturedConversationVersion: version,
    );
    expect(sends, 0);
    expect(result.isReplyAttempt, isFalse);
  });
}
