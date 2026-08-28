import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/scheduling/notification_event_adapter.dart';
import 'package:nanoai/features/automation/engine/scheduling/rule_engine.dart';
import 'package:nanoai/features/automation/engine/scheduling/rule_registry.dart';
import 'package:nanoai/features/automation/engine/scheduling/scheduled_rule.dart';
import 'package:nanoai/features/automation/engine/scheduling/trigger.dart';

void main() {
  ScheduledRule waRule({String id = 'r1', String sender = 'juan'}) =>
      ScheduledRule(
        id: id,
        trigger: NotificationTrigger(
          packageName: 'com.whatsapp',
          senderMatch: sender,
        ),
        action: RuleAction.reply,
        message: 'ahora te escribo',
        createdAt: DateTime(2026, 8, 27, 10),
      );

  group('ScheduledRule serialization', () {
    test('round-trip preserva trigger/action/message/timestamps', () {
      final r = waRule();
      final back = ScheduledRule.fromJson(r.toJson());
      expect(back.id, r.id);
      expect(back.action, RuleAction.reply);
      expect(back.message, 'ahora te escribo');
      expect(back.trigger, isA<NotificationTrigger>());
      expect((back.trigger as NotificationTrigger).senderMatch, 'juan');
      expect(back.createdAt, r.createdAt);
      expect(back.createdByUser, isTrue);
    });
  });

  group('RuleRegistry', () {
    test('load + add + persist round-trip vía MemoryRuleStore', () async {
      final store = MemoryRuleStore();
      final reg = RuleRegistry(store);
      await reg.load();
      reg.add(waRule());

      final reg2 = RuleRegistry(store);
      await reg2.load();
      expect(reg2.rules, hasLength(1));
      expect(reg2.rules.first.action, RuleAction.reply);
    });

    test('setEnabled false persiste', () async {
      final store = MemoryRuleStore();
      final reg = RuleRegistry(store);
      await reg.load();
      reg.add(waRule());
      reg.setEnabled('r1', false);

      final reg2 = RuleRegistry(store);
      await reg2.load();
      expect(reg2.rules.first.enabled, isFalse);
    });

    test('markFired registra lastFiredAt', () async {
      final store = MemoryRuleStore();
      final reg = RuleRegistry(store);
      await reg.load();
      reg.add(waRule());
      reg.markFired('r1', DateTime(2026, 8, 27, 12));
      expect(reg.rules.first.lastFiredAt, DateTime(2026, 8, 27, 12));
    });

    test('remove elimina la regla', () async {
      final store = MemoryRuleStore();
      final reg = RuleRegistry(store);
      await reg.load();
      reg.add(waRule());
      reg.remove('r1');
      expect(reg.rules, isEmpty);
    });
  });

  group('RuleEngine.match', () {
    const engine = RuleEngine();
    final rules = [
      ScheduledRule(
        id: 'r1',
        trigger: NotificationTrigger(
          packageName: 'com.whatsapp',
          senderMatch: 'juan',
        ),
        action: RuleAction.reply,
        createdAt: DateTime(2026),
      ),
      ScheduledRule(
        id: 'r2',
        trigger: NotificationTrigger(
          packageName: 'com.whatsapp',
          senderMatch: 'maria',
        ),
        action: RuleAction.notify,
        createdAt: DateTime(2026),
      ),
      ScheduledRule(
        id: 'r3',
        trigger: TimeTrigger(hour: 8, minute: 0),
        action: RuleAction.reply,
        createdAt: DateTime(2026),
      ),
    ];

    test('notificación de Juan matchea solo r1', () {
      final m = engine.match(
        rules,
        const NotificationEvent(
          packageName: 'com.whatsapp',
          sender: 'Juan',
          conversationTitle: 'Juan P',
        ),
      );
      expect(m.map((r) => r.id).toList(), ['r1']);
    });

    test('notificación de otro paquete no matchea', () {
      final m = engine.match(
        rules,
        const NotificationEvent(packageName: 'com.telegram', sender: 'Juan'),
      );
      expect(m, isEmpty);
    });

    test('tick de reloj matchea solo el TimeTrigger', () {
      final m = engine.match(rules, TickEvent(DateTime(2026, 8, 27, 8, 0)));
      expect(m.map((r) => r.id).toList(), ['r3']);
    });

    test('regla deshabilitada no matchea', () {
      final m = engine.match(
        [rules[0].copyWith(enabled: false)],
        const NotificationEvent(packageName: 'com.whatsapp', sender: 'Juan'),
      );
      expect(m, isEmpty);
    });
  });

  group('NotificationEventAdapter', () {
    const adapter = NotificationEventAdapter();
    test('fromMap extrae package/sender/conversationTitle', () {
      final ev = adapter.fromMap({
        'package': 'com.whatsapp',
        'sender': 'Juan',
        'conversationTitle': 'Juan P',
        'title': 'WhatsApp',
      });
      expect(ev.packageName, 'com.whatsapp');
      expect(ev.sender, 'Juan');
      expect(ev.conversationTitle, 'Juan P');
    });
  });
}
