// delivery_result.dart
//
// QUÉ HACE:
// Resultado explícito de entrega de un mensaje saliente a través de un canal (DeliveryResult).
//
// CÓMO FUNCIONA:
// - Registra si el envío fue exitoso, el ID generado por la plataforma, error y si es reintentable.
// - La máquina de estados comercial solo cambia a 'enviado' si `success` es true.
//
// POR QUÉ:
// Evita asumir que un mensaje llegó solo porque se llamó a la función de transporte.

library;

import '../../../domain/messaging_platform.dart';

final class DeliveryResult {
  final bool success;
  final String? messageId;
  final MessagingPlatform platform;
  final String? error;
  final bool retryable;
  final DateTime timestamp;

  const DeliveryResult({
    required this.success,
    this.messageId,
    required this.platform,
    this.error,
    this.retryable = false,
    required this.timestamp,
  });

  factory DeliveryResult.ok({
    String? messageId,
    required MessagingPlatform platform,
  }) => DeliveryResult(
    success: true,
    messageId: messageId,
    platform: platform,
    timestamp: DateTime.now(),
  );

  factory DeliveryResult.failed({
    required MessagingPlatform platform,
    required String error,
    bool retryable = true,
  }) => DeliveryResult(
    success: false,
    platform: platform,
    error: error,
    retryable: retryable,
    timestamp: DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'success': success,
    if (messageId != null) 'messageId': messageId,
    'platform': platform.id,
    if (error != null) 'error': error,
    'retryable': retryable,
    'timestamp': timestamp.toIso8601String(),
  };
}
