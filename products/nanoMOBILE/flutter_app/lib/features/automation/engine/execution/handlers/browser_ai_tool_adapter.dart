import 'dart:convert';
import '../../../../browser_ai/application/browser_ai_gateway.dart';
import '../../../../browser_ai/domain/browser_ai_query.dart';
import '../tool_call.dart';
import '../tool_outcome.dart';
import '../tool_registry.dart';

/// QUÉ HACE:
/// Conecta las 4 herramientas del subsistema Browser AI con [AgentToolDispatcher].
///
/// CÓMO FUNCIONA:
/// Enruta las llamadas a herramientas según su nombre:
/// - `browser.ai.providers`: lista proveedores disponibles y sesiones.
/// - `browser.ai.open`: abre la pestaña del chat web en el navegador.
/// - `browser.ai.ask`: envía el prompt y espera estabilización.
/// - `browser.ai.get_response`: consulta la respuesta más reciente de la sesión.
///
/// POR QUÉ:
/// Ofrece un contrato estándar para que Nano Agent use chats web como cerebros externos.
class BrowserAiToolAdapter {
  final BrowserAiGateway _gateway;

  const BrowserAiToolAdapter(this._gateway);

  /// Ejecuta la herramienta de Browser AI solicitada.
  Future<ToolOutcome> execute(ToolCall call) async {
    final tool = call.tool.toLowerCase();

    if (tool.endsWith('.providers') || tool == 'browser.ai.list') {
      return await _handleListProviders();
    }

    if (tool.endsWith('.open')) {
      return await _handleOpen(call);
    }

    if (tool.endsWith('.get_response')) {
      return await _handleGetResponse(call);
    }

    // Default: browser.ai.ask
    return await _handleAsk(call);
  }

  Future<ToolOutcome> _handleListProviders() async {
    final list = await _gateway.listProviders();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(list);
    return ToolOutcome(
      verdict: PolicyVerdict.allow,
      feedback: 'Proveedores de IA disponibles en el navegador:\n$jsonStr',
      executionStatus: ToolExecutionStatus.completed,
    );
  }

  Future<ToolOutcome> _handleOpen(ToolCall call) async {
    final provider = call.args?['provider']?.toString() ?? 'gemini';
    final opened = await _gateway.openProviderTab(provider);

    return ToolOutcome(
      verdict: PolicyVerdict.allow,
      feedback: opened
          ? 'Pestaña de $provider abierta en el navegador para inicio de sesión o inspección.'
          : 'No se pudo abrir la pestaña para el proveedor "$provider".',
      executionStatus: opened ? ToolExecutionStatus.completed : ToolExecutionStatus.failed,
    );
  }

  Future<ToolOutcome> _handleAsk(ToolCall call) async {
    final prompt = call.args?['prompt']?.toString() ??
        call.textArg ??
        call.args?['query']?.toString() ??
        '';

    if (prompt.trim().isEmpty) {
      return const ToolOutcome(
        verdict: PolicyVerdict.denied,
        feedback: '[browser.ai.ask] El argumento "prompt" no puede estar vacío.',
        executionStatus: ToolExecutionStatus.failed,
      );
    }

    final provider = call.args?['provider']?.toString() ?? 'auto';

    try {
      final res = await _gateway.query(
        BrowserAiQuery(prompt: prompt, providerId: provider),
      );

      if (res.isCompleted) {
        return ToolOutcome(
          verdict: PolicyVerdict.allow,
          feedback: res.content,
          executionStatus: ToolExecutionStatus.completed,
        );
      }

      if (res.needsUserAction) {
        return ToolOutcome(
          verdict: PolicyVerdict.needsConfirmation,
          feedback: 'Acción requerida en ${res.providerId}: ${res.error}',
          executionStatus: ToolExecutionStatus.completedUnverified,
        );
      }

      return ToolOutcome(
        verdict: PolicyVerdict.denied,
        feedback: 'Error en ${res.providerId}: ${res.error}',
        executionStatus: ToolExecutionStatus.failed,
      );
    } catch (e) {
      return ToolOutcome(
        verdict: PolicyVerdict.denied,
        feedback: 'Excepción en browser.ai.ask: $e',
        executionStatus: ToolExecutionStatus.failed,
      );
    }
  }

  Future<ToolOutcome> _handleGetResponse(ToolCall call) async {
    final provider = call.args?['provider']?.toString() ?? 'gemini';
    final list = await _gateway.listProviders();
    final item = list.where((p) => p['id'] == provider).firstOrNull;

    if (item == null) {
      return ToolOutcome(
        verdict: PolicyVerdict.denied,
        feedback: 'Proveedor "$provider" no encontrado.',
        executionStatus: ToolExecutionStatus.failed,
      );
    }

    return ToolOutcome(
      verdict: PolicyVerdict.allow,
      feedback: 'Estado de sesión para $provider: ${item['hasTab'] == true ? "Activa" : "Inactiva"} (Login: ${item['isLoggedIn']}).',
      executionStatus: ToolExecutionStatus.completed,
    );
  }
}
