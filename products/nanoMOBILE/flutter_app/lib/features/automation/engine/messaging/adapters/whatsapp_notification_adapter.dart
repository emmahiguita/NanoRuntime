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

import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../domain/messaging_platform.dart';
import '../conversation_key.dart';
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
  }) : _transport = transport,
       _availabilityChecker = availabilityChecker;

  @override
  MessagingPlatform get platform => MessagingPlatform.whatsapp;

  @override
  MessagingCapabilities get capabilities =>
      MessagingCapabilities.androidNotification;

  @override
  Future<bool> isAvailable() async {
    final checker = _availabilityChecker;
    if (checker != null) return checker();
    // Sin consulta real al receptor Android, disponibilidad es desconocida.
    return false;
  }

  /// Traduce una notificación Android de WhatsApp a un mensaje universal entrante.
  NanoIncomingMessage fromNotification(NotificationObject notification) {
    final identity = resolveConversationIdentity(notification).key;
    final at = notification.messageTimestamp > 0
        ? notification.messageTimestamp
        : notification.postTime;
    // Una notificación se actualiza con muchos mensajes: su key no es el ID
    // del mensaje. El hash conserva cuenta, origen y evidencia individual.
    final eventId = sha256
        .convert(
          utf8.encode(
            jsonEncode([
              identity.id,
              notification.key,
              at,
              notification.senderKey,
              notification.interpretableText,
            ]),
          ),
        )
        .toString();
    return NanoIncomingMessage(
      id: eventId,
      platform: notification.packageName.contains('w4b')
          ? MessagingPlatform.whatsappBusiness
          : MessagingPlatform.whatsapp,
      accountId:
          '${identity.appPackage}/${identity.accountFingerprint.isEmpty ? '-' : identity.accountFingerprint}',
      conversationId: identity.id.isNotEmpty ? identity.id : notification.key,
      senderId: notification.senderKey.isNotEmpty
          ? notification.senderKey
          : notification.sender,
      senderDisplayName: notification.sender,
      text: notification.interpretableText,
      timestamp: DateTime.fromMillisecondsSinceEpoch(at),
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
    final targetPlatform = capability?.packageName == 'com.whatsapp.w4b'
        ? MessagingPlatform.whatsappBusiness
        : platform;
    // 1. Verificación de Capacidades: RemoteInput solo soporta texto
    final effectiveText = message.text.trim();
    // RemoteInput no adjunta archivos. No afirmamos que imágenes no enviadas
    // están disponibles en WhatsApp ni degradamos el mensaje silenciosamente.
    if (message.attachments.isNotEmpty || effectiveText.isEmpty) {
      return DeliveryResult.failed(
        platform: targetPlatform,
        error: 'RemoteInput admite únicamente texto no vacío',
      );
    }

    if (capability == null ||
        !capability.isUsable ||
        capability.conversationId.isEmpty ||
        capability.conversationId != message.conversationId ||
        (capability.packageName != 'com.whatsapp' &&
            capability.packageName != 'com.whatsapp.w4b')) {
      return DeliveryResult.failed(
        platform: targetPlatform,
        error:
            'Capacidad RemoteInput no disponible o expirada para este mensaje',
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
      SendEvidenceStatus.dispatchedUnverified => DeliveryResult.observed(
        state: DeliveryState.dispatchedUnverified,
        error: evidence.reason,
        platform: targetPlatform,
      ),
      SendEvidenceStatus.localSendVerified => DeliveryResult.observed(
        state: DeliveryState.localSendVerified,
        error: evidence.reason,
        platform: targetPlatform,
      ),
      SendEvidenceStatus.notExecuted => DeliveryResult.failed(
        platform: targetPlatform,
        error: evidence.reason,
        retryable: false,
      ),
      SendEvidenceStatus.outcomeUnknown ||
      SendEvidenceStatus.contextChanged ||
      SendEvidenceStatus.incompleteEvidence => DeliveryResult.observed(
        state: switch (evidence.status) {
          SendEvidenceStatus.contextChanged => DeliveryState.contextChanged,
          SendEvidenceStatus.incompleteEvidence =>
            DeliveryState.incompleteEvidence,
          _ => DeliveryState.outcomeUnknown,
        },
        platform: targetPlatform,
        error: evidence.reason,
      ),
    };
  }
}
