// whatsapp_status_classifier.dart
//
// QUÉ HACE:
// Detecta y clasifica notificaciones de estados/historias de WhatsApp, difusiones
// y reacciones a historias para evitar que se conviertan en chats espurios.
//
// CÓMO FUNCIONA:
// - Examina identificadores técnicos de WhatsApp (status@broadcast, @newsletter).
// - Analiza patrones semánticos multilingües de reacciones ("❤️ a tu estado", "Reacted to your status").
// - Filtra notificaciones de mantenimiento del servicio (backup, web activo, sincronización).
//
// POR QUÉ:
// Erradica chats fantasmas en el Centro de Mensajería y previene respuestas no deseadas de la IA (<200 líneas).

library;

import '../notifications/notification_object.dart';

abstract final class WhatsAppStatusClassifier {
  static final _statusReactionRegex = RegExp(
    r'(reaccion[oó]\s+(con\s+.*?\s+)?a\s+tu\s+(estado|actualizaci[oó]n)|'
    r'respondi[oó]\s+a\s+tu\s+estado|'
    r'(le\s+gusta|dio\s+me\s+gusta).*?tu\s+estado|'
    r'reacted\s+.*?\s+to\s+your\s+status|'
    r'replied\s+to\s+your\s+status|'
    r'reagiu\s+ao?\s+seu\s+status)',
    caseSensitive: false,
    unicode: true,
  );

  static final _systemMaintenanceRegex = RegExp(
    r'(buscando\s+mensajes\s+nuevos|'
    r'checking\s+for\s+new\s+messages|'
    r'whatsapp\s+web|'
    r'copia\s+de\s+seguridad|'
    r'backup\s+in\s+progress)',
    caseSensitive: false,
  );

  /// Determina si una notificación representa una difusión de estado o canal no interactivo.
  static bool isStatusOrBroadcast({
    required String packageName,
    String conversationId = '',
    String shortcutId = '',
    String key = '',
    String title = '',
  }) {
    if (!_isWhatsApp(packageName)) return false;

    final lowerConv = conversationId.toLowerCase();
    final lowerShortcut = shortcutId.toLowerCase();
    final lowerKey = key.toLowerCase();
    final lowerTitle = title.toLowerCase();

    if (lowerConv.contains('status@broadcast') ||
        lowerShortcut.contains('status@broadcast') ||
        lowerKey.contains('status@broadcast')) {
      return true;
    }

    if (lowerConv.contains('@newsletter') ||
        lowerShortcut.contains('@newsletter') ||
        lowerKey.contains('@newsletter')) {
      return true;
    }

    if (lowerTitle == 'actualizaciones de estado' ||
        lowerTitle == 'status updates' ||
        lowerTitle == 'actualizaciones' ||
        lowerTitle == 'novedades') {
      return true;
    }

    return false;
  }

  /// Determina si la notificación es una reacción o me gusta a una historia/estado propio.
  static bool isStoryReaction({
    required String packageName,
    required String text,
    required String messageText,
    String conversationId = '',
  }) {
    if (!_isWhatsApp(packageName)) return false;

    final combined = '$messageText $text'.trim();
    if (combined.isEmpty) return false;

    if (_statusReactionRegex.hasMatch(combined)) {
      return true;
    }

    if (conversationId.toLowerCase().contains('status@broadcast')) {
      return true;
    }

    return false;
  }

  /// Determina si la notificación es de mantenimiento o sincronización interna de WhatsApp.
  static bool isSystemMaintenance({
    required String packageName,
    required String title,
    required String text,
  }) {
    if (!_isWhatsApp(packageName)) return false;
    final combined = '$title $text'.trim();
    return _systemMaintenanceRegex.hasMatch(combined);
  }

  /// Verificación unificada para decidir si una notificación debe descartarse del flujo de chats.
  static bool shouldIgnoreFromChatHub(NotificationObject notif) {
    if (!_isWhatsApp(notif.packageName)) return false;

    if (isStatusOrBroadcast(
      packageName: notif.packageName,
      conversationId: notif.conversationId,
      shortcutId: notif.shortcutId,
      key: notif.key,
      title: notif.title,
    )) {
      return true;
    }

    if (isStoryReaction(
      packageName: notif.packageName,
      text: notif.text,
      messageText: notif.messageText,
      conversationId: notif.conversationId,
    )) {
      return true;
    }

    if (!notif.hasMessagingStyle &&
        isSystemMaintenance(
          packageName: notif.packageName,
          title: notif.title,
          text: notif.text,
        )) {
      return true;
    }

    return false;
  }

  /// Limita la política a las dos aplicaciones oficiales soportadas.
  static bool _isWhatsApp(String packageName) =>
      packageName == 'com.whatsapp' || packageName == 'com.whatsapp.w4b';
}
