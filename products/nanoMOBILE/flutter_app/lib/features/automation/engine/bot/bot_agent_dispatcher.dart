import '../../domain/bot/bot_definition.dart';
import '../../domain/bot/bot_event.dart';
import '../execution/agent_tool_dispatcher.dart';
import '../execution/tool_registry.dart' show PolicyVerdict;
import 'bot_capability_router.dart';
import 'bot_execution_context.dart';
import 'bot_execution_result.dart';

/// QUÉ HACE:
/// Orquesta el ciclo agéntico completo: Evento -> Contexto -> Herramientas ->
/// Verificación -> Formulación con Tono.
///
/// CÓMO FUNCIONA:
/// 1. Inicializa el contexto de ejecución y bitácora.
/// 2. Valida la elegibilidad del bot para procesar el canal del evento.
/// 3. Filtra las herramientas permitidas por la matriz RBAC del bot.
/// 4. Si el evento solicita una acción, la ejecuta vía [BotCapabilityRouter].
/// 5. Verifica el resultado y redacta la respuesta final acorde al tono.
///
/// POR QUÉ:
/// Desacopla la lógica de toma de decisiones del canal de mensajería (SOLID).
class BotAgentDispatcher {
  final AgentToolDispatcher? toolDispatcher;

  const BotAgentDispatcher({this.toolDispatcher});

  /// Ejecuta el ciclo agéntico para un evento determinado.
  Future<BotExecutionResult> dispatch({
    required BotDefinition bot,
    required BotEvent event,
    Map<String, dynamic> memoryFacts = const {},
  }) async {
    final context = BotExecutionContext(
      bot: bot,
      event: event,
      memoryFacts: memoryFacts,
    );

    context.log("Inicio de procesamiento para evento ${event.type.name}");

    // 1. Validar canal habilitado
    if (event.channel.isNotEmpty && !bot.channels.contains(event.channel)) {
      context.log("Canal ${event.channel} no habilitado para este bot.");
      return BotExecutionResult.error(
        botId: bot.id,
        event: event,
        errorMessage: "El bot ${bot.name} no tiene habilitado el canal ${event.channel}.",
        durationMs: context.elapsedMs,
      );
    }

    // 2. Extraer intención o solicitud de herramienta
    final toolCall = _extractToolCall(event);

    if (toolCall != null) {
      context.log("Solicitud de herramienta detectada: ${toolCall.tool}");
      return await _executeToolFlow(bot, event, context, toolCall);
    }

    // 3. Flujo conversacional determinista o con tono
    return _executeConversationalFlow(bot, event, context);
  }

  /// Ejecuta una llamada a herramienta con verificación de seguridad RBAC.
  Future<BotExecutionResult> _executeToolFlow(
    BotDefinition bot,
    BotEvent event,
    BotExecutionContext context,
    ToolCall call,
  ) async {
    final router = BotCapabilityRouter(
      bot: bot,
      dispatcher: toolDispatcher,
    );

    final outcome = await router.executeTool(call);
    context.log("Herramienta ejecutada. Veredicto: ${outcome.verdict.name}");

    final isSuccess = outcome.verdict == PolicyVerdict.allow && !outcome.executionFailed;
    final message = isSuccess
        ? "Acción completada: ${outcome.feedback}"
        : "No fue posible completar la acción: ${outcome.feedback}";

    return BotExecutionResult(
      botId: bot.id,
      eventId: event.id,
      responseMessage: message,
      executedTools: [call.tool],
      toolOutcomes: [outcome],
      isSuccess: isSuccess,
      executionDurationMs: context.elapsedMs,
      reasoningSummary: "Ejecución de herramienta ${call.tool} finalizada.",
    );
  }

  /// Procesa una respuesta conversacional respetando el tono del bot.
  BotExecutionResult _executeConversationalFlow(
    BotDefinition bot,
    BotEvent event,
    BotExecutionContext context,
  ) {
    final rawText = event.textContent;
    context.log("Procesando respuesta conversacional con tono ${bot.tone.warmth.name}");

    final reply = rawText.isNotEmpty
        ? "Atendido por ${bot.name} (${bot.role.label}): $rawText"
        : "Hola, soy ${bot.name}. ¿En qué te puedo ayudar hoy?";

    return BotExecutionResult.directReply(
      botId: bot.id,
      event: event,
      reply: reply,
      durationMs: context.elapsedMs,
    );
  }

  /// Identifica si el evento requiere invocar una herramienta específica.
  ToolCall? _extractToolCall(BotEvent event) {
    final payload = event.payload;
    if (payload.containsKey('tool')) {
      final toolName = payload['tool']?.toString() ?? '';
      final args = payload['args'] is Map<String, Object?>
          ? payload['args'] as Map<String, Object?>
          : null;
      return ToolCall(tool: toolName, args: args);
    }
    return null;
  }
}
