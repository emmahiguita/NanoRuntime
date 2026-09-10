import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/messaging/messaging_package.dart';
import 'package:nanoai/features/automation/engine/scheduling/trigger.dart';
import 'package:nanoai/features/automation/engine/scheduling/trigger_parser.dart';

void main() {
  group('TriggerParser PACKAGE-SCOPE-01', () {
    final parser = TriggerParser();

    test('Asigna com.whatsapp por defecto cuando no se menciona app', () {
      final parsed = parser.parse('cuando llegue un mensaje de Carlos, responder hola');
      expect(parsed, isNotNull);
      expect(parsed!.trigger, isA<NotificationTrigger>());
      final trigger = parsed.trigger as NotificationTrigger;
      expect(trigger.packageName, equals(MessagingPackage.whatsapp));
      expect(trigger.senderMatch, equals('Carlos'));
    });

    test('Asigna com.whatsapp explícitamente cuando se menciona WhatsApp', () {
      final parsed = parser.parse('cuando llegue un mensaje de WhatsApp de Maria avisar');
      expect(parsed, isNotNull);
      final trigger = parsed!.trigger as NotificationTrigger;
      expect(trigger.packageName, equals(MessagingPackage.whatsapp));
    });

    test('Asigna com.whatsapp.w4b cuando se menciona WhatsApp Business', () {
      final parsed = parser.parse('cuando llegue un mensaje de WhatsApp Business de Cliente responder enseguida');
      expect(parsed, isNotNull);
      final trigger = parsed!.trigger as NotificationTrigger;
      expect(trigger.packageName, equals(MessagingPackage.whatsappBusiness));
    });

    test('Asigna org.telegram.messenger cuando se menciona Telegram', () {
      final parsed = parser.parse('cuando llegue un mensaje de Telegram de Juan responder voy');
      expect(parsed, isNotNull);
      final trigger = parsed!.trigger as NotificationTrigger;
      expect(trigger.packageName, equals(MessagingPackage.telegram));
    });

    test('Asigna null únicamente cuando el usuario pide cualquier app conscientemente', () {
      final parsed = parser.parse('cuando llegue un mensaje de cualquier app que diga urgente avisar');
      expect(parsed, isNotNull);
      final trigger = parsed!.trigger as NotificationTrigger;
      expect(trigger.packageName, isNull);
    });
  });
}
