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
      await reg.flush();

      final reg2 = RuleRegistry(store);
      await reg2.load();
      final r1 = reg2.rules.firstWhere((r) => r.id == 'r1');
      expect(r1.action, RuleAction.reply);
    });

    test('setEnabled false persiste', () async {
      final store = MemoryRuleStore();
      final reg = RuleRegistry(store);
      await reg.load();
      reg.add(waRule());
      reg.setEnabled('r1', false);
      await reg.flush();

      final reg2 = RuleRegistry(store);
      await reg2.load();
      final r1 = reg2.rules.firstWhere((r) => r.id == 'r1');
      expect(r1.enabled, isFalse);
    });

    test('markFired registra lastFiredAt', () async {
      final store = MemoryRuleStore();
      final reg = RuleRegistry(store);
      await reg.load();
      reg.add(waRule());
      reg.markFired('r1', DateTime(2026, 8, 27, 12));
      final r1 = reg.rules.firstWhere((r) => r.id == 'r1');
      expect(r1.lastFiredAt, DateTime(2026, 8, 27, 12));
    });

    test('remove elimina la regla', () async {
      final store = MemoryRuleStore();
      final reg = RuleRegistry(store);
      await reg.load();
      reg.seedWhatsAppRule('com.whatsapp');
      reg.add(waRule());
      reg.remove('r1');
      expect(reg.rules.any((r) => r.id == 'r1'), isFalse);
      expect(reg.rules.any((r) => r.id == RuleRegistry.universalWhatsAppRuleId), isTrue);
    });

    test('seedWhatsAppRule y removeWhatsAppRule alternan el estado limpiamente', () async {
      final store = MemoryRuleStore();
      final reg = RuleRegistry(store);
      await reg.load();

      expect(reg.isWhatsAppRuleActive('com.whatsapp'), isFalse);

      reg.seedWhatsAppRule('com.whatsapp');
      expect(reg.isWhatsAppRuleActive('com.whatsapp'), isTrue);

      reg.removeWhatsAppRule('com.whatsapp');
      expect(reg.isWhatsAppRuleActive('com.whatsapp'), isFalse);

      reg.seedWhatsAppRule('com.whatsapp');
      expect(reg.isWhatsAppRuleActive('com.whatsapp'), isTrue);
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

    test('regla específica de remitente tiene precedencia sobre regla universal genérica', () {
      final universalRule = ScheduledRule(
        id: 'wa_universal',
        trigger: const NotificationTrigger(packageName: 'com.whatsapp'),
        action: RuleAction.reply,
        dynamicReply: true,
        createdAt: DateTime(2026),
      );
      final specificRule = ScheduledRule(
        id: 'specific_juan',
        trigger: const NotificationTrigger(
          packageName: 'com.whatsapp',
          senderMatch: 'juan',
        ),
        action: RuleAction.reply,
        message: 'Hola Juan',
        createdAt: DateTime(2026),
      );

      // Aunque la universal esté primera en la lista de reglas:
      final matched = engine.match(
        [universalRule, specificRule],
        const NotificationEvent(
          packageName: 'com.whatsapp',
          sender: 'Juan',
          conversationTitle: 'Juan',
        ),
      );

      // La específica DEBE ser la primera en el resultado para no ser ignorada
      expect(matched.length, 2);
      expect(matched.first.id, 'specific_juan');
      expect(matched.last.id, 'wa_universal');
    });

    test('regla deshabilitada no matchea', () {
      final m = engine.match(
        [rules[0].copyWith(enabled: false)],
        const NotificationEvent(packageName: 'com.whatsapp', sender: 'Juan'),
      );
      expect(m, isEmpty);
    });
  });

  group('RuleRegistry deduplication', () {
    test('load deduplica reglas con IDs repetidos en el store', () async {
      final store = MemoryRuleStore();
      final rule1 = ScheduledRule(
        id: 'rule-dup',
        trigger: const NotificationTrigger(packageName: 'com.whatsapp'),
        action: RuleAction.reply,
        message: 'Original',
        createdAt: DateTime(2026),
      );
      final rule2 = ScheduledRule(
        id: 'rule-dup',
        trigger: const NotificationTrigger(packageName: 'com.whatsapp'),
        action: RuleAction.reply,
        message: 'Duplicado',
        createdAt: DateTime(2026),
      );
      await store.save([rule1, rule2]);

      final registry = RuleRegistry(store);
      await registry.load();

      expect(registry.rules.length, 1);
      expect(registry.rules.first.id, 'rule-dup');
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
