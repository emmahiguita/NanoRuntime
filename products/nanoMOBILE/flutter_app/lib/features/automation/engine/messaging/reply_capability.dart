/// WA-ID-02 / WA-RI-05 — ReplyCapabilityRef: referencia TIPADA y exacta a la
/// capacidad RemoteInput de una notificación observada. No es "responde a la
/// notificación que coincida": es UNA notificación exacta, con su acción y su
/// resultKey observados.
///
/// La revalidación antes de enviar (WA-RI-05) exige que el nativo confirme
/// que TODOS estos campos siguen siendo ciertos para la notificación activa;
/// cualquier desviación se convierte en CONTEXT_CHANGED y NO se envía.
library;

import '../notifications/notification_object.dart';
import 'conversation_key.dart';

final class ReplyCapabilityRef {
  /// Key de la StatusBarNotification exacta observada.
  final String notificationKey;

  /// Paquete real de la app origen (evidencia, nunca inventado).
  final String packageName;

  /// postTime observado de la generación de la notificación.
  final int observedAt;

  /// Índice de la acción con RemoteInput dentro de `actions`. -1 = inválida.
  final int actionIndex;

  /// resultKey del RemoteInput de texto libre observado.
  final String remoteInputResultKey;

  /// Fingerprint factual del contexto de conversación en el momento de la
  /// observación (conversationFingerprint + sender + isGroup).
  final String contextFingerprint;

  /// Identidad canónica capturada; un adaptador no usa la referencia en otro hilo.
  final String conversationId;

  const ReplyCapabilityRef({
    required this.notificationKey,
    required this.packageName,
    required this.observedAt,
    required this.actionIndex,
    required this.remoteInputResultKey,
    required this.contextFingerprint,
    this.conversationId = '',
  });

  /// true si la referencia apunta a una capacidad de respuesta realmente
  /// observada (key no vacía + RemoteInput de texto libre presente).
  bool get isUsable =>
      notificationKey.isNotEmpty &&
      remoteInputResultKey.isNotEmpty &&
      actionIndex >= 0;

  /// Construye la referencia desde una notificación observada. Devuelve null
  /// si la notificación no expone capacidad de respuesta real.
  static ReplyCapabilityRef? fromNotification(NotificationObject n) {
    if (!n.canReply || n.key.isEmpty || n.remoteInputKey.isEmpty) return null;
    return ReplyCapabilityRef(
      notificationKey: n.key,
      packageName: n.packageName,
      observedAt: n.postTime,
      actionIndex: n.actionIndex,
      remoteInputResultKey: n.remoteInputKey,
      contextFingerprint: _contextFingerprint(n),
      conversationId: resolveConversationIdentity(n).key.id,
    );
  }

  static String _contextFingerprint(NotificationObject n) => [
    n.conversationId,
    n.shortcutId,
    n.locusId,
    n.senderKey,
    n.conversationTitle,
    n.sender,
    n.isGroup ? 'group' : 'direct',
  ].join('\u0000');

  @override
  bool operator ==(Object other) =>
      other is ReplyCapabilityRef &&
      other.notificationKey == notificationKey &&
      other.packageName == packageName &&
      other.observedAt == observedAt &&
      other.actionIndex == actionIndex &&
      other.remoteInputResultKey == remoteInputResultKey &&
      other.contextFingerprint == contextFingerprint;

  @override
  int get hashCode => Object.hash(
    notificationKey,
    packageName,
    observedAt,
    actionIndex,
    remoteInputResultKey,
    contextFingerprint,
  );

  @override
  String toString() =>
      'ReplyCapabilityRef($packageName, $notificationKey, '
      'action=$actionIndex, ri=$remoteInputResultKey, at=$observedAt)';
}
