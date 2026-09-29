import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/scheduling/scheduled_message_command_parser.dart';
import 'package:nanoai/features/automation/engine/scheduling/scheduled_rule.dart';
import 'package:nanoai/features/automation/engine/scheduling/trigger.dart';
import 'package:nanoai/features/automation/engine/scheduling/trigger_parser.dart';

void main() {
  group('scheduled WhatsApp command parsing', () {
    test('accepts Colombian natural time with y minutes', () {
      final parsed = const TriggerParser().parse(
        'mándale a Emm: Hola a las 6 y 45 pm hora colombiana',
      );

      expect(parsed, isNotNull);
      final trigger = parsed!.trigger as TimeTrigger;
      expect(trigger.hour, 18);
      expect(trigger.minute, 45);
      expect(trigger.timeZoneId, 'America/Bogota');
      expect(trigger.recurring, isFalse);
      expect(parsed.goal, 'mándale a Emm: Hola');
    });

    test('marks explicit daily schedule as recurring', () {
      final parsed = const TriggerParser().parse(
        'todos los días a las 08:15 envíale a Emm: Buenos días',
      );
      expect((parsed!.trigger as TimeTrigger).recurring, isTrue);
    });

    test('extracts one recipient and exact message', () {
      final command = ScheduledMessageCommandParser.parse(
        'mándale un mensaje a Emm: Hola, ¿cómo estás?',
      );
      expect(command?.recipients, ['Emm']);
      expect(command?.message, 'Hola, ¿cómo estás?');
    });

    test('extracts multiple recipients including compound names', () {
      final command = ScheduledMessageCommandParser.parse(
        'envíales a (María José), (Juan Pérez), (+573001112233) '
        'el mensaje: Llegaré a las ocho',
      );
      expect(command?.recipients, [
        'María José',
        'Juan Pérez',
        '+573001112233',
      ]);
      expect(command?.message, 'Llegaré a las ocho');
    });

    test('preserves contact separators and punctuation after time parsing', () {
      final parsed = const TriggerParser().parse(
        'a las 6:45 pm, envíales a Emm, Juan: Hola, ¿cómo están?',
      );
      final command = ScheduledMessageCommandParser.parse(parsed!.goal);

      expect(command?.recipients, ['Emm', 'Juan']);
      expect(command?.message, 'Hola, ¿cómo están?');
    });
  });

  test('scheduled recipients survive rule persistence', () {
    final rule = ScheduledRule(
      id: 'scheduled-1',
      trigger: const TimeTrigger(
        hour: 18,
        minute: 45,
        timeZoneId: 'America/Bogota',
        recurring: false,
      ),
      action: RuleAction.sendMessage,
      message: 'Hola',
      recipients: const [
        ScheduledMessageRecipient(name: 'Emm', number: '573001112233'),
        ScheduledMessageRecipient(name: 'Juan', number: '573009998877'),
      ],
      createdAt: DateTime.utc(2026, 9, 29),
    );

    final restored = ScheduledRule.fromJson(rule.toJson());
    expect(restored.action, RuleAction.sendMessage);
    expect(restored.recipients.length, 2);
    expect(restored.recipients.last.number, '573009998877');
    expect((restored.trigger as TimeTrigger).timeZoneId, 'America/Bogota');
    expect((restored.trigger as TimeTrigger).recurring, isFalse);
  });
}
