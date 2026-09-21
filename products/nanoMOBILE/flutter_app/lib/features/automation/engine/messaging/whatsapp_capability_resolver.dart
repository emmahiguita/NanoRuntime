/// WHATSAPP-CAPABILITY-RESOLVER-01
///
/// **QUÉ HACE:**
/// Determina dinámicamente qué tipos de mensajes (texto, enlaces, fotos, PDFs, audio, video)
/// se pueden enviar a través de WhatsApp en segundo plano sin salir de Nano y sin abrir la Activity.
///
/// **CÓMO FUNCIONA:**
/// Inspecciona las acciones de la notificación activa de Android y su [RemoteInput]:
/// - Texto y Enlaces: Si la notificación expone `allowFreeFormInput`, el envío es 100% en segundo plano.
/// - Multimedia (imágenes, PDFs, etc.): Inspecciona `allowedDataTypes` del RemoteInput. Si WhatsApp
///   no publica el tipo MIME correspondiente, marca honestamente `userInteractionRequired`.
///
/// **POR QUÉ:**
/// Regla estricta de Nano: NO abandonar Nano, NO abrir WhatsApp visualmente y NO simular éxito.
/// Ofrece transparencia total al usuario antes de pulsar el botón de envío.
library;

import '../../executors/notification_executor.dart';

/// Tres estados universales de capacidad de transporte en Nano.
enum WhatsAppSendCapability {
  /// Envío 100% en segundo plano sin salir de Nano ni abrir WhatsApp.
  backgroundSupported,

  /// Requiere confirmación o interacción visual porque WhatsApp no expone entrada de datos para este medio.
  userInteractionRequired,

  /// No soportado por falta de canal de respuesta activo en la notificación.
  unsupported,
}

/// Representación estructurada de las capacidades por tipo de mensaje para un chat concreto.
final class WhatsAppMessageCapability {
  final WhatsAppSendCapability text;
  final WhatsAppSendCapability link;
  final WhatsAppSendCapability photo;
  final WhatsAppSendCapability documentPdf;
  final WhatsAppSendCapability audio;
  final WhatsAppSendCapability video;
  final bool canReplyInBackground;
  final String remoteInputKey;
  final List<String> allowedDataTypes;

  const WhatsAppMessageCapability({
    required this.text,
    required this.link,
    required this.photo,
    required this.documentPdf,
    required this.audio,
    required this.video,
    required this.canReplyInBackground,
    required this.remoteInputKey,
    required this.allowedDataTypes,
  });

  /// Capacidad nula para conversaciones sin notificación activa.
  factory WhatsAppMessageCapability.unavailable() {
    return const WhatsAppMessageCapability(
      text: WhatsAppSendCapability.unsupported,
      link: WhatsAppSendCapability.unsupported,
      photo: WhatsAppSendCapability.unsupported,
      documentPdf: WhatsAppSendCapability.unsupported,
      audio: WhatsAppSendCapability.unsupported,
      video: WhatsAppSendCapability.unsupported,
      canReplyInBackground: false,
      remoteInputKey: '',
      allowedDataTypes: [],
    );
  }
}

/// Resolver de capacidades en tiempo real para WhatsApp en Nano.
class WhatsAppCapabilityResolver {
  const WhatsAppCapabilityResolver._();

  /// Resuelve las capacidades reales leyendo la evidencia de la notificación de Android.
  static WhatsAppMessageCapability resolve(DeviceNotification? notification) {
    if (notification == null || !notification.canReply) {
      return WhatsAppMessageCapability.unavailable();
    }

    final hasTextChannel = notification.remoteInputKey.isNotEmpty;
    final allowedTypes = notification.allowedDataTypes;

    // 1. Texto y Links: Siempre soportados en segundo plano si hay RemoteInput libre
    final textCap = hasTextChannel
        ? WhatsAppSendCapability.backgroundSupported
        : WhatsAppSendCapability.unsupported;
    final linkCap = hasTextChannel
        ? WhatsAppSendCapability.backgroundSupported
        : WhatsAppSendCapability.unsupported;

    // 2. Fotos e Imágenes (MIME: image/*)
    final photoCap = _evalMediaCapability(
      hasTextChannel: hasTextChannel,
      allowedTypes: allowedTypes,
      mimePrefix: 'image/',
    );

    // 3. Documentos y PDFs (MIME: application/pdf o */*)
    final docCap = _evalMediaCapability(
      hasTextChannel: hasTextChannel,
      allowedTypes: allowedTypes,
      mimePrefix: 'application/pdf',
    );

    // 4. Audio (MIME: audio/*)
    final audioCap = _evalMediaCapability(
      hasTextChannel: hasTextChannel,
      allowedTypes: allowedTypes,
      mimePrefix: 'audio/',
    );

    // 5. Video (MIME: video/*)
    final videoCap = _evalMediaCapability(
      hasTextChannel: hasTextChannel,
      allowedTypes: allowedTypes,
      mimePrefix: 'video/',
    );

    return WhatsAppMessageCapability(
      text: textCap,
      link: linkCap,
      photo: photoCap,
      documentPdf: docCap,
      audio: audioCap,
      video: videoCap,
      canReplyInBackground: hasTextChannel,
      remoteInputKey: notification.remoteInputKey,
      allowedDataTypes: allowedTypes,
    );
  }

  static WhatsAppSendCapability _evalMediaCapability({
    required bool hasTextChannel,
    required List<String> allowedTypes,
    required String mimePrefix,
  }) {
    if (!hasTextChannel) return WhatsAppSendCapability.unsupported;
    final hasDirectMime = allowedTypes.any(
      (type) => type == '*/*' || type.startsWith(mimePrefix),
    );
    // Si la notificación expone entrada de datos para ese MIME, es en segundo plano.
    // Si no, requiere interacción del usuario (no se simula éxito).
    return hasDirectMime
        ? WhatsAppSendCapability.backgroundSupported
        : WhatsAppSendCapability.userInteractionRequired;
  }
}
