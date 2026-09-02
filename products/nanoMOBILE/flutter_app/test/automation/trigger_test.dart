import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/scheduling/trigger.dart';
import 'package:nanoai/features/automation/engine/scheduling/trigger_parser.dart';

void main() {
  group('evaluateTrigger', () {
    test('TimeTrigger dispara a la hora exacta', () {
      const t = TimeTrigger(hour: 8, minute: 0);
      expect(
        evaluateTrigger(t, TickEvent(DateTime(2026, 8, 27, 8, 0))),
        isTrue,
      );
      expect(
        evaluateTrigger(t, TickEvent(DateTime(2026, 8, 27, 8, 1))),
        isFalse,
      );
    });

    test('TimeTrigger con weekday filtra días', () {
      const t = TimeTrigger(hour: 8, minute: 0, weekdays: {1}); // lunes
      expect(
        evaluateTrigger(t, TickEvent(DateTime(2026, 8, 24, 8, 0))),
        isTrue,
      );
      expect(
        evaluateTrigger(t, TickEvent(DateTime(2026, 8, 25, 8, 0))),
        isFalse,
      );
    });

    test('NotificationTrigger matchea sender (case-insensitive)', () {
      const t = NotificationTrigger(senderMatch: 'juan');
      expect(
        evaluateTrigger(
          t,
          const NotificationEvent(sender: 'Juan', conversationTitle: 'Juan P'),
        ),
        isTrue,
      );
      expect(
        evaluateTrigger(t, const NotificationEvent(sender: 'María')),
        isFalse,
      );
    });

    test('NotificationTrigger con packageName', () {
      const t = NotificationTrigger(packageName: 'com.whatsapp');
      expect(
        evaluateTrigger(t, const NotificationEvent(packageName: 'com.whatsapp')),
        isTrue,
      );
      expect(
        evaluateTrigger(t, const NotificationEvent(packageName: 'com.telegram')),
        isFalse,
      );
    });

    test('ConnectivityTrigger wifiOnly', () {
      const t = ConnectivityTrigger(wifiOnly: true);
      expect(evaluateTrigger(t, const ConnectivityEvent(wifiConnected: true)), isTrue);
      expect(evaluateTrigger(t, const ConnectivityEvent(wifiConnected: false)), isFalse);
    });

    test('BatteryTrigger belowPercent', () {
      const t = BatteryTrigger(15);
      expect(evaluateTrigger(t, const BatteryEvent(percent: 10)), isTrue);
      expect(evaluateTrigger(t, const BatteryEvent(percent: 20)), isFalse);
    });

    test('evento no aplicable al trigger → false', () {
      expect(
        evaluateTrigger(
          const TimeTrigger(hour: 8, minute: 0),
          const NotificationEvent(),
        ),
        isFalse,
      );
    });
  });

  group('TriggerParser', () {
    const parser = TriggerParser();

    test('"todos los días a las 8 abre Chrome" → TimeTrigger + goal', () {
      final s = parser.parse('todos los días a las 8 abre Chrome');
      expect(s, isNotNull);
      expect(s!.trigger, isA<TimeTrigger>());
      expect((s.trigger as TimeTrigger).hour, 8);
      expect((s.trigger as TimeTrigger).minute, 0);
      expect(s.goal, 'abre Chrome');
    });

    test('"a las 8:30 abre YouTube" → TimeTrigger(8:30)', () {
      final s = parser.parse('a las 8:30 abre YouTube');
      expect(s, isNotNull);
      expect((s!.trigger as TimeTrigger).hour, 8);
      expect((s.trigger as TimeTrigger).minute, 30);
      expect(s.goal, 'abre YouTube');
    });

    test('"cuando Juan me escriba, avísame" → NotificationTrigger + goal', () {
      final s = parser.parse('cuando Juan me escriba, avísame');
      expect(s, isNotNull);
      expect(s!.trigger, isA<NotificationTrigger>());
      expect((s.trigger as NotificationTrigger).senderMatch, 'Juan');
      expect(s.goal, 'avísame');
    });

    test('"cuando llegue un mensaje de Pedro, guárdalo" → sender Pedro', () {
      final s = parser.parse('cuando llegue un mensaje de Pedro, guárdalo');
      expect(s, isNotNull);
      expect((s!.trigger as NotificationTrigger).senderMatch, 'Pedro');
      expect(s.goal, 'guárdalo');
    });

    test('sin disparo reconocible → null', () {
      expect(parser.parse('abre Chrome'), isNull);
      expect(parser.parse(''), isNull);
    });
  });
}
