import '../notifications/notification_object.dart';

/// Una sola defensa Dart para panel, replay e inbox; no analiza palabras de un DM.
abstract final class NotificationMessageAdmission {
  static const _social = {
    'com.instagram.android',
    'com.facebook.katana',
    'com.facebook.lite',
    'com.facebook.orca',
    'com.facebook.mlite',
  };

  /// Conserva la evidencia nativa y rechaza mapas legacy ambiguos de actividad social.
  static bool allows(NotificationObject value) {
    if (!value.isConversationEvent || value.isSummary || value.ongoing) {
      return false;
    }
    if (!_social.contains(value.packageName)) return true;
    final direct =
        value.packageName == 'com.instagram.android' &&
        value.key.contains('|direct|') &&
        value.key.contains('thread_id:');
    final facebookFeed =
        value.packageName == 'com.facebook.katana' ||
        value.packageName == 'com.facebook.lite';
    if (facebookFeed) {
      return value.notificationCategory == 'msg' && value.canReply;
    }
    return direct ||
        (value.notificationCategory == 'msg' &&
            (value.hasMessagingStyle || value.canReply));
  }
}
