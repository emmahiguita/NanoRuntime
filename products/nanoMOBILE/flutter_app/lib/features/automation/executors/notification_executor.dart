import 'package:nanoai/core/services/nano_runtime_api.dart';

import '../engine/conversation/conversation_reply_composer.dart';
import '../engine/messaging/reply_capability.dart';
import 'device_notification.dart';

export 'device_notification.dart';

class NotificationAccessStatus {
  final bool accessGranted;
  final bool connected;

  const NotificationAccessStatus({
    required this.accessGranted,
    required this.connected,
  });
}

/// Resultado tipado del despacho de notificación (Clean Architecture / Tipado honesto).
sealed class NotificationReplyResult {
  final bool accepted;
  final String code;
  final String? reason;

  const NotificationReplyResult({
    required this.accepted,
    required this.code,
    this.reason,
  });

  bool get isAccepted => accepted;
  bool get isContextChanged => code == 'CONTEXT_CHANGED';
  bool get isNotificationGone => code == 'NOTIFICATION_GONE';
  bool get isActionExpired => code == 'ACTION_EXPIRED';
  bool get isActionDenied => code == 'ACTION_DENIED';
  bool get isInvalidText => code == 'INVALID_TEXT';
  bool get isReplyUnavailable => code == 'REPLY_UNAVAILABLE';

  factory NotificationReplyResult.fromMap(Map<dynamic, dynamic> map) {
    final ok = map['ok'] == true;
    final code =
        (map['code'] as String?) ?? (ok ? 'REMOTE_INPUT_ACCEPTED' : 'UNKNOWN');
    final reason = map['reason'] as String?;
    return _NotificationReplyResultImpl(
      accepted: ok,
      code: code,
      reason: reason,
    );
  }
}

class _NotificationReplyResultImpl extends NotificationReplyResult {
  const _NotificationReplyResultImpl({
    required super.accepted,
    required super.code,
    super.reason,
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
    throw StateError(
      'No se pudo generar un borrador contextual con la información disponible.',
    );
  }

  /// Genera sugerencias de respuesta a partir de la MISMA comprensión única.
  Future<List<String>> generateSuggestions(
    DeviceNotification notification,
  ) async {
    if (!notification.canReply) return const [];
    final notifObj = notification.toNotificationObject();
    return _composer.composeSuggestions(notifObj);
  }

  /// Despacha respuesta manual revalidando la capacidad exacta (WA-RI-05 / TOCTOU).
  Future<NotificationReplyResult> confirmAndReply(
    DeviceNotification notification,
    String text,
  ) async {
    final clean = text.trim();
    if (!notification.canReply || clean.isEmpty || clean.length > 2000) {
      return NotificationReplyResult.fromMap(const {
        'ok': false,
        'code': 'INVALID_REQUEST',
        'reason': 'Notificación no admite respuesta o texto inválido',
      });
    }

    final notifObj = notification.toNotificationObject();
    final capability = ReplyCapabilityRef.fromNotification(notifObj);

    final result = await _runtime.replyToNotification(
      key: notification.key,
      text: clean,
      confirmed: true,
      actionIndex: capability?.actionIndex ?? notification.actionIndex,
      remoteInputKey:
          capability?.remoteInputResultKey ?? notification.remoteInputKey,
      contextFingerprint: capability?.contextFingerprint,
      postTime:
          capability?.observedAt ??
          notification.postedAt.millisecondsSinceEpoch,
    );
    return NotificationReplyResult.fromMap(result);
  }
}
