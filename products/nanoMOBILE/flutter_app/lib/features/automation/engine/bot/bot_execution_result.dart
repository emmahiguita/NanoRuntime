import 'package:flutter/foundation.dart';
import '../../domain/bot/bot_event.dart';
import '../execution/agent_tool_dispatcher.dart';

/// QUÉ HACE:
/// Encapsula el resultado inmutable del ciclo agéntico ejecutado por un bot.
///
/// CÓMO FUNCIONA:
/// Contiene la respuesta textual final, las herramientas ejecutadas con sus
/// veredictos, la duración en milisegundos y un resumen del razonamiento.
///
/// POR QUÉ:
/// Desacopla la capa de presentación y los canales de mensajería del motor
/// interno de inferencia y llamadas a herramientas (Clean Architecture).
@immutable
class BotExecutionResult {
  final String botId;
  final String eventId;
  final String responseMessage;
  final List<String> executedTools;
  final List<ToolOutcome> toolOutcomes;
  final bool isSuccess;
  final int executionDurationMs;
  final String reasoningSummary;

  const BotExecutionResult({
    required this.botId,
    required this.eventId,
    required this.responseMessage,
    this.executedTools = const [],
    this.toolOutcomes = const [],
    this.isSuccess = true,
    this.executionDurationMs = 0,
    this.reasoningSummary = '',
  });

  /// Crea un resultado rápido de error sin herramientas ejecutadas.
  factory BotExecutionResult.error({
    required String botId,
    required BotEvent event,
    required String errorMessage,
    int durationMs = 0,
  }) {
    return BotExecutionResult(
      botId: botId,
      eventId: event.id,
      responseMessage: errorMessage,
      isSuccess: false,
      executionDurationMs: durationMs,
      reasoningSummary: 'Fallo durante la ejecución agéntica.',
    );
  }

  /// Crea un resultado de respuesta directa (conversacional pura sin herramientas).
  factory BotExecutionResult.directReply({
    required String botId,
    required BotEvent event,
    required String reply,
    int durationMs = 0,
  }) {
    return BotExecutionResult(
      botId: botId,
      eventId: event.id,
      responseMessage: reply,
      isSuccess: true,
      executionDurationMs: durationMs,
      reasoningSummary: 'Respuesta directa sin herramientas.',
    );
  }

  @override
  String toString() =>
      'BotExecutionResult(bot: $botId, success: $isSuccess, tools: ${executedTools.length}, ms: $executionDurationMs)';
}
