import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/services/llm_engine_client.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_draft_writer.dart';
import 'package:nanoai/features/automation/engine/notifications/conversation_understanding.dart';
import 'package:nanoai/features/automation/engine/scheduling/event_dedupe_store.dart';
import 'package:nanoai/features/automation/engine/scheduling/rule_dispatcher.dart';
import 'package:nanoai/features/automation/engine/scheduling/scheduled_rule.dart';
import 'package:nanoai/features/automation/engine/scheduling/trigger.dart';
import 'package:nanoai/features/automation/engine/scheduling/turn_supersede_guard.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_key.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'messaging_burst_regression_test.dart' show event;

class Engine extends Fake implements LLMEngineClient {
  final starts = <String>[];
  final first = Completer<void>();
  int active = 0;
  int peak = 0;
  @override Future<LLMResult> generate({required String prompt,
      double temperature = 0.7, int maxTokens = 256, String? sessionId}) async {
    active++;
    if (active > peak) peak = active;
    starts.add(sessionId!);
    if (starts.length == 1) await first.future;
    active--;
    return const LLMResult(text: '{"reply":"Lo revisamos"}');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('four contacts use one FIFO model lane with one generation each', () async {
    final client = Engine();
    final writer = RuntimeNotificationDraftWriter(client: client,
      llmAllowed: () => true, ensureReady: (_) async => true,
      modelPath: () => null, styleEnabled: () => false, styleText: () => '');
    final results = [for (final name in ['A', 'B', 'C', 'D'])
      writer.call(event(1, contact: name, text: 'revisa el telefono'))];
    await Future<void>.delayed(Duration.zero);
    expect(client.starts, hasLength(1));
    client.first.complete();
    expect((await Future.wait(results)).every((r) => r?.hasReply ?? false), isTrue);
    expect(client.peak, 1);
    expect(client.starts, hasLength(4));
    for (var i = 0; i < 4; i++) {
      final id = resolveConversationIdentity(event(1, contact: ['A', 'B', 'C', 'D'][i])).key.id;
      expect(client.starts[i], startsWith('$id|'));
    }
  });
  test('original reservations survive a new persistent store instance', () async {
    SharedPreferences.setMockInitialValues({});
    final first = SharedPrefsEventDedupeStore();
    await first.load();
    final now = DateTime.now().millisecondsSinceEpoch;
    expect(first.reserve('event-1', conversationId: 'Juan', text: 'hola',
      atMs: now, eventOnly: true), DedupeVerdict.proceed);
    await first.flush();
    final second = SharedPrefsEventDedupeStore();
    await second.load();
    expect(second.reserve('event-1', conversationId: 'Juan', text: 'hola',
      atMs: now + 1, eventOnly: true), DedupeVerdict.duplicate);
    expect(second.reserve('event-2', conversationId: 'Juan', text: 'hola',
      atMs: now + 2, eventOnly: true), DedupeVerdict.proceed);
    await second.flush();
  });
  test('draft finishes physically but cannot send after new input', () async {
    final guard = TurnSupersedeGuard();
    final n = event(1);
    final id = resolveConversationIdentity(n).key.id;
    final pending = Completer<NotificationDraftResult?>();
    var sends = 0;
    final dispatcher = RuleDispatcher((_, {options}) async {
      sends++;
      throw StateError('stale send');
    }, supersedeGuard: guard, draftSource: (_) => pending.future);
    guard.bump(id);
    final result = dispatcher.dispatch(ScheduledRule(id: 'dynamic',
      trigger: const NotificationTrigger(), action: RuleAction.reply,
      dynamicReply: true, createdAt: DateTime(2026)), n);
    await Future<void>.delayed(Duration.zero);
    guard.bump(id);
    pending.complete(const NotificationDraftResult(
      understanding: ConversationUnderstanding(reply: 'viejo'), reply: 'viejo'));
    expect((await result).isReplyAttempt, false);
    expect(sends, 0);
  });
}
