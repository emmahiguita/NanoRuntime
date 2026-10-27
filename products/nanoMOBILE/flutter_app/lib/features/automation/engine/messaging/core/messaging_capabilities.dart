// messaging_capabilities.dart
//
// QUÉ HACE:
// Matriz de capacidades por canal de mensajería (MessagingCapabilities).
//
// CÓMO FUNCIONA:
// - Declara explícitamente qué acciones soporta un canal concreto (texto, fotos,
//   videos, audios, documentos, RemoteInput, lectura, etc.).
// - Provee presets para WhatsApp personal, WA Web, WA Cloud API, Telegram, Instagram, etc.
//
// POR QUÉ:
// Evita asumir capacidades uniformes y permite degradación funcional elegante en vez de fallos silenciosos.

library;

final class MessagingCapabilities {
  final bool canReceiveText;
  final bool canSendText;
  final bool canReceiveImages;
  final bool canSendImages;
  final bool canReceiveVideo;
  final bool canSendVideo;
  final bool canReceiveAudio;
  final bool canSendAudio;
  final bool canReceiveDocuments;
  final bool canSendDocuments;
  final bool canReply;
  final bool canReact;
  final bool canMarkRead;
  final bool canSendAutomatically;

  const MessagingCapabilities({
    this.canReceiveText = true,
    this.canSendText = true,
    this.canReceiveImages = true,
    this.canSendImages = true,
    this.canReceiveVideo = true,
    this.canSendVideo = true,
    this.canReceiveAudio = true,
    this.canSendAudio = true,
    this.canReceiveDocuments = true,
    this.canSendDocuments = true,
    this.canReply = true,
    this.canReact = false,
    this.canMarkRead = false,
    this.canSendAutomatically = true,
  });

  /// Preset para Android NotificationListener + RemoteInput (WhatsApp personal / Telegram).
  static const MessagingCapabilities androidNotification = MessagingCapabilities(
    canReceiveText: true,
    canSendText: true,
    canReceiveImages: true,
    canSendImages: false, // Notification RemoteInput solo soporta texto
    canReceiveVideo: false,
    canSendVideo: false,
    canReceiveAudio: true,
    canSendAudio: false,
    canReceiveDocuments: false,
    canSendDocuments: false,
    canReply: true,
    canReact: false,
    canMarkRead: true,
    canSendAutomatically: true,
  );

  /// Preset para WhatsApp Web Bridge (Headless / WebView).
  static const MessagingCapabilities whatsappWeb = MessagingCapabilities(
    canReceiveText: true,
    canSendText: true,
    canReceiveImages: true,
    canSendImages: true,
    canReceiveVideo: true,
    canSendVideo: true,
    canReceiveAudio: true,
    canSendAudio: true,
    canReceiveDocuments: true,
    canSendDocuments: true,
    canReply: true,
    canReact: true,
    canMarkRead: true,
    canSendAutomatically: true,
  );

  /// Preset para Meta Cloud API (WhatsApp Business oficial).
  static const MessagingCapabilities metaCloudApi = MessagingCapabilities(
    canReceiveText: true,
    canSendText: true,
    canReceiveImages: true,
    canSendImages: true,
    canReceiveVideo: true,
    canSendVideo: true,
    canReceiveAudio: true,
    canSendAudio: true,
    canReceiveDocuments: true,
    canSendDocuments: true,
    canReply: true,
    canReact: true,
    canMarkRead: true,
    canSendAutomatically: true,
  );
}
