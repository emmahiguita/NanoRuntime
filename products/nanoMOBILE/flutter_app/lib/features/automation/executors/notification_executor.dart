import 'package:nanoai/core/services/nano_runtime_api.dart';

import '../engine/conversation/conversation_reply_composer.dart';
import '../engine/notifications/notification_object.dart';

class DeviceNotification {
  final String key;
  final String packageName;
  final String title;
  final String text;
  final DateTime postedAt;
  final bool canReply;
  final bool ongoing;
  final bool isGroup;

  /// Campos de identidad y estructura canónica de conversación.
  final String sender;
  final String senderKey;
  final String conversationTitle;
  final String conversationId;
  final String shortcutId;
  final String locusId;
  final String accountHint;

  /// Campos de fidelidad canónica 1-to-1 con NotificationObject.
  final String messageText;
  final int messageTimestamp;
  final String senderUri;
  final bool isSummary;
  final String remoteInputKey;
  final int actionIndex;
  final List<String> actions;

  const DeviceNotification({
    required this.key,
    required this.packageName,
    required this.title,
    required this.text,
    required this.postedAt,
    required this.canReply,
    required this.ongoing,
    this.isGroup = false,
    this.sender = '',
    this.senderKey = '',
    this.conversationTitle = '',
    this.conversationId = '',
    this.shortcutId = '',
    this.locusId = '',
    this.accountHint = '',
    this.messageText = '',
    this.messageTimestamp = 0,
    this.senderUri = '',
    this.isSummary = false,
    this.remoteInputKey = '',
    this.actionIndex = -1,
    this.actions = const [],
  });

  factory DeviceNotification.fromMap(Map<dynamic, dynamic> map) {
    final epoch = (map['postTime'] is num) ? (map['postTime'] as num).toInt() : 0;
    return DeviceNotification(
      key: map['key'] as String? ?? '',
      packageName: (map['package'] ?? map['packageName']) as String? ?? '',
      title: map['title'] as String? ?? '',
      text: map['text'] as String? ?? '',
      postedAt: DateTime.fromMillisecondsSinceEpoch(epoch),
      canReply: map['canReply'] as bool? ?? false,
      ongoing: map['ongoing'] as bool? ?? false,
      isGroup: map['isGroup'] as bool? ?? false,
      sender: map['sender'] as String? ?? '',
      senderKey: map['senderKey'] as String? ?? '',
      conversationTitle: map['conversationTitle'] as String? ?? '',
      conversationId: map['conversationId'] as String? ?? '',
      shortcutId: map['shortcutId'] as String? ?? '',
      locusId: map['locusId'] as String? ?? '',
      accountHint: map['accountHint'] as String? ?? '',
      messageText: map['messageText'] as String? ?? '',
      messageTimestamp: (map['messageTimestamp'] is num)
          ? (map['messageTimestamp'] as num).toInt()
          : 0,
      senderUri: map['senderUri'] as String? ?? '',
      isSummary: map['isSummary'] as bool? ?? false,
      remoteInputKey: map['remoteInputKey'] as String? ?? '',
      actionIndex: (map['actionIndex'] is num)
          ? (map['actionIndex'] as num).toInt()
          : -1,
      actions: ((map['actions'] as List?) ?? const [])
          .map((a) => '$a')
          .where((a) => a.isNotEmpty)
          .toList(),
    );
  }

  /// Adaptador unidireccional estricto (One-Way Adapter):
  /// DeviceNotification -> NotificationObject con preservación total de evidencia.
  NotificationObject toNotificationObject() {
    return NotificationObject(
      key: key,
      packageName: packageName,
      title: title,
      text: text,
      messageText: messageText.isNotEmpty ? messageText : text,
      messageTimestamp: messageTimestamp > 0
          ? messageTimestamp
          : postedAt.millisecondsSinceEpoch,
      sender: sender,
      senderKey: senderKey,
      senderUri: senderUri,
      conversationTitle: conversationTitle,
      conversationId: conversationId,
      shortcutId: shortcutId,
      locusId: locusId,
      accountHint: accountHint,
      isGroup: isGroup,
      isSummary: isSummary,
      isTruncated: false,
      postTime: postedAt.millisecondsSinceEpoch,
      canReply: canReply,
      remoteInputKey: remoteInputKey,
      actionIndex: actionIndex,
      actions: actions,
      ongoing: ongoing,
    );
  }
}

class NotificationAccessStatus {
  final bool accessGranted;
  final bool connected;

  const NotificationAccessStatus({
    required this.accessGranted,
    required this.connected,
  });
}

/// Executor de notificaciones adelgazado:
/// Lectura de estado, listado nativo y transporte de respuesta confirmada.
///
/// La redacción y comprensión conversacional se delegan exclusivamente
/// en [ConversationReplyComposer], eliminando duplicación de prompts,
/// bypass de memoria y respuestas genéricas de call-center.
class NotificationExecutor {
  final NanoRuntimeApi _runtime;
  final ConversationReplyComposer _composer;

  NotificationExecutor({
    required NanoRuntimeApi runtime,
    required ConversationReplyComposer composer,
  }) : _runtime = runtime,
       _composer = composer;

  Future<NotificationAccessStatus> status() async {
    final raw = await _runtime.notificationStatus();
    return NotificationAccessStatus(
      accessGranted: raw['accessGranted'] == true,
      connected: raw['connected'] == true,
    );
  }

  Future<bool> requestAccess() => _runtime.requestNotificationAccess();

  Future<List<DeviceNotification>> list({int limit = 30}) async {
    final raw = await _runtime.listActiveNotifications(limit: limit);
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map(DeviceNotification.fromMap)
        .where((item) => item.key.isNotEmpty)
        .toList(growable: false);
  }

  /// Genera un borrador local usando el MISMO cerebro conversacional canónico.
  /// Sin motor o sin contexto suficiente: falla honesto, jamás texto genérico.
  Future<String> generateLocalDraft(DeviceNotification notification) async {
    if (!notification.canReply) {
      throw StateError('La notificación no admite respuesta directa');
    }
    final notifObj = notification.toNotificationObject();
    final result = await _composer.compose(notifObj);
    if (result != null && result.hasReply) {
      return result.text;
    }
    throw StateError('No se pudo generar un borrador contextual con la información disponible.');
  }

  /// Genera sugerencias de respuesta a partir de la MISMA comprensión única.
  Future<List<String>> generateSuggestions(
    DeviceNotification notification,
  ) async {
    if (!notification.canReply) return const [];
    final notifObj = notification.toNotificationObject();
    return _composer.composeSuggestions(notifObj);
  }

  Future<bool> confirmAndReply(
    DeviceNotification notification,
    String text,
  ) async {
    final clean = text.trim();
    if (!notification.canReply || clean.isEmpty || clean.length > 2000) {
      return false;
    }
    final result = await _runtime.replyToNotification(
      key: notification.key,
      text: clean,
      confirmed: true,
    );
    return result['ok'] == true;
  }
}
