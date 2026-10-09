// whatsapp_notification_adapter.dart
//
// QUÉ HACE:
// Adaptador de transporte concreto para WhatsApp personal vía notificaciones de Android (RemoteInput).
//
// CÓMO FUNCIONA:
// - Traduce `NotificationObject` entrante a `NanoIncomingMessage` de forma agnóstica.
// - Evalúa `MessagingCapabilities` antes de intentar enviar texto o archivos adjuntos.
// - Despacha mensajes salientes `NanoOutgoingMessage` usando `ReplyTransport` (RemoteInput nativo).
// - Retorna `DeliveryResult` con evidencia real de despacho del sistema operativo.
//
// POR QUÉ:
// Conecta WhatsApp personal existente a Nano Messaging Core sin duplicar receptores
// y manteniendo el motor de Nano Negocio 100% desacoplado de Android y WhatsApp.

library;

import '../../../domain/messaging_platform.dart';
import '../../notifications/notification_object.dart';
import '../../orchestration/commit_guard.dart';
import '../core/channel_adapter.dart';
import '../core/delivery_result.dart';
import '../core/messaging_capabilities.dart';
import '../core/nano_incoming_message.dart';
import '../core/nano_outgoing_message.dart';
import '../reply_capability.dart';
import '../reply_transport.dart';

class WhatsAppNotificationAdapter implements ChannelAdapter {
  final ReplyTransport _transport;
  final bool Function()? _availabilityChecker;

  const WhatsAppNotificationAdapter({
    required ReplyTransport transport,
    bool Function()? availabilityChecker,
  })  : _transport = transport,
        _availabilityChecker = availabilityChecker;

  @override
  MessagingPlatform get platform => MessagingPlatform.whatsapp;

  @override
  MessagingCapabilities get capabilities => MessagingCapabilities.androidNotification;

  @override
  Future<bool> isAvailable() async {
    final checker = _availabilityChecker;
    if (checker != null) return checker();
    return true;
  }

  /// Traduce una notificación Android de WhatsApp a un mensaje universal entrante.
  NanoIncomingMessage fromNotification(NotificationObject notification) {
    return NanoIncomingMessage(
      id: notification.key,
      platform: notification.packageName.contains('w4b')
          ? MessagingPlatform.whatsappBusiness
          : MessagingPlatform.whatsapp,
      accountId: 'personal',
      conversationId: notification.conversationId.isNotEmpty
          ? notification.conversationId
          : notification.key,
      senderId: notification.senderKey.isNotEmpty
          ? notification.senderKey
          : notification.sender,
      senderDisplayName: notification.sender,
      text: notification.text,
      timestamp: DateTime.fromMillisecondsSinceEpoch(notification.postTime),
      metadata: {
        'packageName': notification.packageName,
        'isGroup': notification.isGroup,
        'notificationKey': notification.key,
      },
    );
  }

  @override
  Future<DeliveryResult> deliver(
    NanoOutgoingMessage message, {
    ReplyCapabilityRef? capability,
  }) async {
    // 1. Verificación de Capacidades: RemoteInput solo soporta texto
    var effectiveText = message.text;
    if (message.attachments.isNotEmpty && !capabilities.canSendImages) {
      effectiveText = '$effectiveText\n\n[Nota: Para ver imágenes adjuntas, abre la conversación en WhatsApp]';
    }

    if (capability == null || !capability.isUsable) {
      return DeliveryResult.failed(
        platform: platform,
        error: 'Capacidad RemoteInput no disponible o expirada para este mensaje',
        retryable: false,
      );
    }

    // 2. Despacho a través de ReplyTransport nativo
    final evidence = await _transport.dispatch(
      ReplyDispatchRequest(
        capability: capability,
        text: effectiveText,
        confirmed: true,
      ),
    );

    // 3. Mapeo honesto de evidencia a DeliveryResult
    return switch (evidence.status) {
      SendEvidenceStatus.dispatchedUnverified ||
      SendEvidenceStatus.localSendVerified =>
        DeliveryResult.ok(
          messageId: capability.notificationKey,
          platform: platform,
        ),
      SendEvidenceStatus.notExecuted => DeliveryResult.failed(
          platform: platform,
          error: evidence.reason,
          retryable: false,
        ),
      SendEvidenceStatus.outcomeUnknown ||
      SendEvidenceStatus.contextChanged ||
      SendEvidenceStatus.incompleteEvidence =>
        DeliveryResult.failed(
          platform: platform,
          error: evidence.reason,
          retryable: true,
        ),
    };
  }
}
