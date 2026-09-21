import 'package:flutter/foundation.dart';

/// QUÉ HACE:
/// Modela la solicitud de consulta hacia un chat de IA en la web.
///
/// CÓMO FUNCIONA:
/// Objeto de valor inmutable con el prompt a consultar, el identificador
/// del proveedor objetivo (o 'auto'), configuración de timeout y opciones de sesión.
///
/// POR QUÉ:
/// Desacopla la intención del usuario de los detalles específicos de navegación (Clean Architecture).
@immutable
class BrowserAiQuery {
  final String requestId;
  final String prompt;
  final String providerId;
  final Duration timeout;
  final bool startNewChat;
  final Map<String, dynamic> metadata;

  BrowserAiQuery({
    String? requestId,
    required this.prompt,
    this.providerId = 'auto',
    this.timeout = const Duration(seconds: 45),
    this.startNewChat = false,
    this.metadata = const {},
  }) : requestId = requestId ?? 'req_${DateTime.now().millisecondsSinceEpoch}';

  BrowserAiQuery copyWith({
    String? requestId,
    String? prompt,
    String? providerId,
    Duration? timeout,
    bool? startNewChat,
    Map<String, dynamic>? metadata,
  }) {
    return BrowserAiQuery(
      requestId: requestId ?? this.requestId,
      prompt: prompt ?? this.prompt,
      providerId: providerId ?? this.providerId,
      timeout: timeout ?? this.timeout,
      startNewChat: startNewChat ?? this.startNewChat,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() =>
      'BrowserAiQuery(id: $requestId, provider: $providerId, promptLen: ${prompt.length}, timeout: ${timeout.inSeconds}s)';
}
