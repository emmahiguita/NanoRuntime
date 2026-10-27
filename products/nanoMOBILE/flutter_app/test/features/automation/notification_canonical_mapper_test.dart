import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/messaging/canonical_message.dart';
import 'package:nanoai/features/automation/engine/messaging/notification_canonical_mapper.dart';
import 'package:nanoai/features/automation/executors/device_notification.dart';

void main() {
  DeviceNotification notification(List<Map<String, dynamic>> messages) =>
      DeviceNotification(
        key: 'android-reused-key',
        packageName: 'com.whatsapp',
        title: 'Contacto',
        text: 'resumen',
        postedAt: DateTime(2026),
        canReply: true,
        ongoing: false,
        rawMessages: messages,
      );

  test(
    'una clave Android reutilizada conserva mensajes nuevos y su dirección',
    () {
      final observed = notification([
        {'text': 'Sí', 'messageTimestamp': 1000, 'sender': 'Contacto'},
        {'text': 'Sí', 'messageTimestamp': 2000, 'sender': 'Contacto'},
        {'text': 'Listo', 'messageTimestamp': 3000, 'isSelf': true},
      ]);
      final rows = NotificationCanonicalMapper.map(observed, 'personal:chat');
      expect(rows.length, 3);
      expect(rows.map((e) => e.id).toSet().length, 3);
      expect(rows.map((e) => e.fingerprint).toSet().length, 3);
      expect(rows.last.direction, CanonicalMessageDirection.outbound);
      expect(rows.map((e) => e.body), ['Sí', 'Sí', 'Listo']);
      expect(
        NotificationCanonicalMapper.map(
          observed,
          'personal:chat',
        ).map((e) => e.id),
        rows.map((e) => e.id),
      );
    },
  );

  test(
    'un replay no duplica filas y Personal/Negocio tienen IDs distintos',
    () {
      final message = {'text': 'Hola', 'messageTimestamp': 1000};
      final observed = notification([message, message]);
      final personal = NotificationCanonicalMapper.map(
        observed,
        'personal:chat',
      );
      final business = NotificationCanonicalMapper.map(
        observed,
        'business:chat',
      );
      expect(personal.length, 1);
      expect(business.single.id, isNot(personal.single.id));
    },
  );
}
