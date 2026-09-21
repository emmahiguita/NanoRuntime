import 'package:flutter/foundation.dart';

/// Estado de la respuesta devuelta por el proveedor web de IA.
enum BrowserAiResponseStatus {
  completed,
  userActionRequired,
  timeout,
  failed,
}

/// QUÉ HACE:
/// Representa el resultado inmutable de una consulta procesada en un chat web.
///
/// CÓMO FUNCIONA:
/// Encapsula el contenido textual de la respuesta del modelo, el estado de
/// terminación, posibles errores y el tiempo total de estabilización del DOM.
///
/// POR QUÉ:
/// Permite que Nano Agent decida si procede con el razonamiento, si solicita
/// intervención humana (por CAPTCHA o login) o si reintenta.
@immutable
class BrowserAiResponse {
  final BrowserAiResponseStatus status;
  final String providerId;
  final String content;
  final String? error;
  final Duration duration;
  final String? requestId;

  const BrowserAiResponse({
    required this.status,
    required this.providerId,
    required this.content,
    this.error,
    this.duration = Duration.zero,
    this.requestId,
  });

  bool get isCompleted => status == BrowserAiResponseStatus.completed;
  bool get needsUserAction => status == BrowserAiResponseStatus.userActionRequired;

  factory BrowserAiResponse.success({
    required String providerId,
    required String content,
    required Duration duration,
    String? requestId,
  }) {
    return BrowserAiResponse(
      status: BrowserAiResponseStatus.completed,
      providerId: providerId,
      content: content,
      duration: duration,
      requestId: requestId,
    );
  }

  factory BrowserAiResponse.userActionRequired({
    required String providerId,
    required String reason,
    required Duration duration,
    String? requestId,
  }) {
    return BrowserAiResponse(
      status: BrowserAiResponseStatus.userActionRequired,
      providerId: providerId,
      content: '',
      error: reason,
      duration: duration,
      requestId: requestId,
    );
  }

  factory BrowserAiResponse.failure({
    required String providerId,
    required String error,
    BrowserAiResponseStatus status = BrowserAiResponseStatus.failed,
    Duration duration = Duration.zero,
    String? requestId,
  }) {
    return BrowserAiResponse(
      status: status,
      providerId: providerId,
      content: '',
      error: error,
      duration: duration,
      requestId: requestId,
    );
  }

  @override
  String toString() =>
      'BrowserAiResponse(id: $requestId, provider: $providerId, status: ${status.name}, chars: ${content.length}, duration: ${duration.inMilliseconds}ms)';
}
