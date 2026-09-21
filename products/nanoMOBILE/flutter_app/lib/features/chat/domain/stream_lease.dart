import 'package:http/http.dart' as http;
import '../../../core/models/chat_models.dart';

/// Propiedad explícita de un único stream HTTP de inferencia con el motor local.
///
/// **QUÉ HACE:**
/// Modela la sesión de red activa con llama.cpp / nano-runtime para un turno específico.
///
/// **CÓMO FUNCIONA:**
/// Asocia un identificador único de generación [generationId], el cliente HTTP subyacente
/// [client] y el [requestId] asignado por el servidor local. Mantiene la bandera [released]
/// para garantizar que el cierre sea idempotente.
///
/// **POR QUÉ:**
/// Si el usuario pulsa "Detener" e inmediatamente envía otro mensaje, la ronda vieja puede
/// emitir eventos en su bloque `finally`. El lease con identidad única evita que el `finally`
/// de la ronda cancelada cierre el cliente de la ronda nueva o decremente indebidamente
/// el contador de conexiones activas.
class StreamLease {
  /// Identificador numérico secuencial del turno de generación.
  final int generationId;

  /// Cliente HTTP dedicado a este stream. Se cierra al cancelar o terminar.
  final http.Client client;

  /// Identificador devuelto por nanortime para cancelaciones cooperativas en /cancel.
  final String requestId;

  /// Bandera atómica que asegura que el cliente solo se cierre y contabilice una vez.
  bool released = false;

  StreamLease({
    required this.generationId,
    required this.client,
    required this.requestId,
  });
}

/// Contenedor de datos inmutable para el resultado de un turno de streaming completado.
///
/// **QUÉ HACE:**
/// Transporta el texto completo acumulado, las métricas de tokens por segundo y la latencia.
///
/// **CÓMO FUNCIONA:**
/// Es emitido al finalizar el stream SSE una vez que se recibe el evento `token.stop == true`.
///
/// **POR QUÉ:**
/// Desacopla la recepción del flujo de red de la lógica de procesamiento de respuestas
/// o detección de herramientas (Principio de Responsabilidad Única - SRP).
class StreamTurnResult {
  /// Texto final acumulado tras consumir todos los tokens del stream.
  final String fullText;

  /// Velocidad instantánea de generación en tokens por segundo (tps).
  final double? tps;

  /// Métricas detalladas de hardware y latencia (TTFT, tiempo de prefill, tokens generados).
  final TurnMetrics? turnMetrics;

  const StreamTurnResult({
    required this.fullText,
    this.tps,
    this.turnMetrics,
  });
}
