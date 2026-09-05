/// NotificationEventAdapter (T3.2) — mapea una notificación REAL a un
/// [NotificationEvent] para matching de reglas.
///
/// Es el puente entre el NotificationListenerService (notificación nativa) y el
/// RuleRegistry. No copia lógica de matching: solo extrae los campos factuales
/// (package/sender/conversationTitle) que el trigger necesita.
library;

import '../notifications/notification_object.dart';
import 'trigger.dart';

class NotificationEventAdapter {
  const NotificationEventAdapter();

  NotificationEvent fromNotification(NotificationObject n) => NotificationEvent(
    packageName: n.packageName,
    sender: n.sender,
    conversationTitle: n.conversationTitle,
    text: n.interpretableText,
  );

  NotificationEvent fromMap(Map<dynamic, dynamic> m) =>
      fromNotification(NotificationObject.fromMap(m.cast<dynamic, dynamic>()));
}
