/// Expresa evidencia de transporte sin confundir aceptación con entrega.
/// success se conserva como consulta de entrega remota, nunca como clic local.
library;

import '../../../domain/messaging_platform.dart';

enum DeliveryState {
  accepted,
  dispatchedUnverified,
  localSendVerified,
  delivered,
  read,
  failed,
  outcomeUnknown,
  contextChanged,
  incompleteEvidence,
}

final class DeliveryResult {
  final DeliveryState state;
  final String? messageId;
  final MessagingPlatform platform;
  final String? error;
  final bool retryable;
  final DateTime timestamp;

  /// Compatibilidad: el bool histórico true representa aceptación, no entrega.
  const DeliveryResult({
    required bool success,
    DeliveryState? state,
    this.messageId,
    required this.platform,
    this.error,
    this.retryable = false,
    required this.timestamp,
  }) : state =
           state ?? (success ? DeliveryState.accepted : DeliveryState.failed);

  /// Únicamente estados confirmados remotamente acreditan entrega.
  bool get success =>
      state == DeliveryState.delivered || state == DeliveryState.read;

  /// La operación pudo haber salido: no debe crear un segundo envío.
  bool get mayHaveDispatched => switch (state) {
    DeliveryState.failed => false,
    _ => true,
  };

  /// Fachada histórica: aceptación no equivale a delivered.
  factory DeliveryResult.ok({
    String? messageId,
    required MessagingPlatform platform,
  }) => DeliveryResult.observed(
    state: DeliveryState.accepted,
    messageId: messageId,
    platform: platform,
  );

  /// Propaga la evidencia disponible; no fabrica un ID de mensaje remoto.
  factory DeliveryResult.observed({
    required DeliveryState state,
    required MessagingPlatform platform,
    String? messageId,
    String? error,
  }) => DeliveryResult(
    success: false,
    state: state,
    platform: platform,
    messageId: messageId,
    error: error,
    timestamp: DateTime.now(),
  );

  /// Solo fallos explícitos antes del despacho pueden autorizar un reintento.
  factory DeliveryResult.failed({
    required MessagingPlatform platform,
    required String error,
    bool retryable = false,
  }) => DeliveryResult(
    success: false,
    platform: platform,
    error: error,
    retryable: retryable,
    timestamp: DateTime.now(),
  );

  /// Conserva success para consumidores anteriores y añade el estado preciso.
  Map<String, dynamic> toJson() => {
    'success': success,
    'state': state.name,
    if (messageId != null) 'messageId': messageId,
    'platform': platform.id,
    if (error != null) 'error': error,
    'retryable': retryable,
    'timestamp': timestamp.toIso8601String(),
  };
}
