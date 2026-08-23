/// Planner real de automatización (DIP sobre el LLM local).
///
/// Produce un plan de [ToolCall] a partir de un objetivo. Es el "planner"
/// del [AutomationCoordinator]: cuando no hay flujo verificado en cache ni
/// plan provisto, el coordinator pregunta al planner para que el objetivo se
/// convierta en acciones verificables — el motor autónomo reutilizable del
/// plan maestro (no "automatización del chat").
///
/// Seguridad todo-lógica (no depende del prompt): la salida del modelo es
/// dato NO fiable. Se parsea con [AgentToolProtocol] (vocabulario del motor,
/// DSL del selector) y se VALIDA contra [ToolRegistry.builtin]: cualquier
/// tool desconocida o llamada sin selector/texto se descarta. Si no queda
/// ninguna, el coordinator devuelve noPlan honesto.
library;

import 'package:nanoai/core/services/llm_engine_client.dart'
    show LLMEngineClient, LLMResult;

import 'agent_tool_dispatcher.dart' show AgentToolProtocol, ToolCall;
import 'tool_registry.dart' show ToolRegistry;

/// Contrato del planner. DIP: LLM real, heurística determinista, o fake en
/// tests. Producen [ToolCall] ejecutables por el dispatcher.
abstract interface class AutomationPlanner {
  Future<List<ToolCall>> plan(String goal);
}

/// Planner real que usa el LLM local (via [LLMEngineClient]).
class LlmAutomationPlanner implements AutomationPlanner {
  final LLMEngineClient _client;
  final Set<String> _knownTools;

  LlmAutomationPlanner({required LLMEngineClient client, Set<String>? knownTools})
      : _client = client,
        _knownTools = knownTools ??
            ToolRegistry.builtin.all.map((t) => t.name).toSet();

  @override
  Future<List<ToolCall>> plan(String goal) async {
    const maxRetries = 2;
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      final LLMResult result;
      try {
        result = await _client.generate(
          prompt: _buildPrompt(goal),
          temperature: 0.2,
          maxTokens: 220,
        );
      } catch (_) {
        // Motor no responde: plan vacío → noPlan honesto del coordinator.
        return const [];
      }
      final calls = _validate(AgentToolProtocol.extractToolCalls(result.text));
      if (calls.isNotEmpty) return calls;
      // Si salió vacío (parseo fallido), reintento una vez con la misma
      // instrucción de formato reforzada.
    }
    return const [];
  }

  /// Filtra la salida del modelo contra el vocabulario conocido y exige que
  /// cada llamada tenga selector o texto (acción ejecutable).
  List<ToolCall> _validate(List<ToolCall> calls) {
    final valid = <ToolCall>[];
    for (final call in calls) {
      if (!_knownTools.contains(call.tool)) continue;
      if (call.selector == null && call.text == null) continue;
      valid.add(call);
    }
    return valid;
  }

  String _buildPrompt(String goal) {
    return 'Eres el planificador de automatización de Nano. Convierte el '
        'objetivo del usuario en una SECUENCIA ordenada de llamadas a '
        'herramientas para lograrlo. Nunca inventes tools ni estados.\n\n'
        'Herramientas (solo estas): '
        '${_knownTools.join(', ')}.\n\n'
        'Selector DSL (para tap/resolve): '
        '"text=Texto exacto", "text~=contiene", "id=resourceId", '
        '"role=boton", "pkg=paquete".\n'
        'write usa "text". linux.* usa "text" con path/comando.\n\n'
        'Devuelve SOLO un array JSON, sin explicación ni texto extra, del '
        'formato:\n'
        '[{"tool":"tap","selector":"text=Bluetooth"},{"tool":"write","text":"hola"}]\n\n'
        'Objetivo: $goal';
  }
}
