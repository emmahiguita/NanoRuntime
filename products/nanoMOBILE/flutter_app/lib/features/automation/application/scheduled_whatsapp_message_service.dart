import 'package:flutter/services.dart';

import '../engine/execution/handlers/whatsapp_contact_resolver.dart';
import '../engine/scheduling/scheduled_rule.dart';
import '../engine/scheduling/trigger.dart';
import 'whatsapp_contacts_provider.dart';

final class ScheduledMessageScheduleResult {
  final bool scheduled;
  final bool exact;
  final DateTime? nextRun;
  final String reason;

  const ScheduledMessageScheduleResult({
    required this.scheduled,
    this.exact = false,
    this.nextRun,
    this.reason = '',
  });
}

/// Resuelve contactos al crear la regla y sincroniza la alarma durable nativa.
/// La alarma persiste fuera de Flutter y se restaura después de reiniciar Android.
final class ScheduledWhatsAppMessageService {
  ScheduledWhatsAppMessageService({WhatsAppContactsService? contacts})
    : _contacts = contacts ?? WhatsAppContactsService();

  static const _channel = MethodChannel('com.nanoai/share');
  final WhatsAppContactsService _contacts;

  Future<List<ScheduledMessageRecipient>?> resolveRecipients(
    List<String> queries,
  ) async {
    final resolver = WhatsAppContactResolver(_contacts);
    final resolved = <ScheduledMessageRecipient>[];
    final seen = <String>{};
    for (final query in queries) {
      final contact = await resolver.resolve(query);
      if (contact == null) return null;
      final number = contact.number.replaceAll(RegExp(r'\D'), '');
      if (number.length < 7 || !seen.add(number)) continue;
      resolved.add(
        ScheduledMessageRecipient(name: contact.name, number: number),
      );
    }
    return resolved.isEmpty ? null : List.unmodifiable(resolved);
  }

  Future<ScheduledMessageScheduleResult> schedule(ScheduledRule rule) async {
    final trigger = rule.trigger;
    if (rule.action != RuleAction.sendMessage ||
        trigger is! TimeTrigger ||
        rule.message.trim().isEmpty ||
        rule.recipients.isEmpty) {
      return const ScheduledMessageScheduleResult(
        scheduled: false,
        reason: 'Regla de mensaje programado incompleta.',
      );
    }
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'scheduleWhatsAppMessage',
        {
          'ruleId': rule.id,
          'hour': trigger.hour,
          'minute': trigger.minute,
          'weekdays': trigger.weekdays.toList(),
          'timeZoneId': trigger.timeZoneId,
          'recurring': trigger.recurring,
          'message': rule.message,
          'packageName': 'com.whatsapp',
          'recipients': [
            for (final recipient in rule.recipients) recipient.toJson(),
          ],
        },
      );
      if (raw?['ok'] != true) {
        return ScheduledMessageScheduleResult(
          scheduled: false,
          reason: raw?['reason']?.toString() ?? 'Android rechazó la alarma.',
        );
      }
      final atMs = (raw?['scheduledAtMs'] as num?)?.toInt();
      return ScheduledMessageScheduleResult(
        scheduled: true,
        exact: raw?['exact'] == true,
        nextRun: atMs == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(atMs),
      );
    } on PlatformException catch (error) {
      return ScheduledMessageScheduleResult(
        scheduled: false,
        reason: error.message ?? error.code,
      );
    } on MissingPluginException {
      return const ScheduledMessageScheduleResult(
        scheduled: false,
        reason: 'El scheduler nativo no está disponible en este dispositivo.',
      );
    }
  }

  Future<void> cancel(String ruleId) async {
    try {
      await _channel.invokeMethod<void>('cancelScheduledWhatsAppMessage', {
        'ruleId': ruleId,
      });
    } on PlatformException {
      // La regla local se puede desactivar aunque Android ya no tenga la alarma.
    } on MissingPluginException {
      return;
    }
  }

  Future<void> openExactAlarmSettings() async {
    try {
      await _channel.invokeMethod<void>('openExactAlarmSettings');
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }
}
