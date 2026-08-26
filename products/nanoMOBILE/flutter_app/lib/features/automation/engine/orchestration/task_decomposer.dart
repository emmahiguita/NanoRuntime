/// A15.2 — LlmTaskDecomposer: descompone un objetivo en TaskPlan usando
/// templates deterministas PRIMERO (0 LLM) y descomposición LLM VALIDADA después.
///
/// El modelo produce SOLO semántica finita (vocabulario A15.2), nunca tool
/// names/shell/packages/selectores/coordenadas. La salida se parsea y valida;
/// cualquier paso fuera del vocabulario rechaza todo el plan (null).
library;

import 'dart:convert';

import 'package:nanoai/core/services/llm_engine_client.dart';

import 'task_planner.dart';
import 'task_plan.dart';
import 'task_step_vocabulary.dart';

class LlmTaskDecomposer {
  LlmTaskDecomposer({required LLMEngineClient client, TaskPlanner? planner})
    : _client = client,
      _planner = planner ?? const TaskPlanner();

  final LLMEngineClient _client;
  final TaskPlanner _planner;

  /// Descompone el objetivo en un TaskPlan. Template determinista primero;
  /// si no hay, invoca el LLM y valida su descomposición. null = sin plan
  /// (motor caído o descomposición inválida).
  Future<TaskPlan?> decompose(String goal) async {
    final deterministic = _planner.plan(goal);
    if (deterministic != null) return deterministic;

    final LLMResult result;
    try {
      result = await _client.generate(
        prompt: _buildPrompt(goal),
        temperature: 0.2,
        maxTokens: 220,
      );
    } catch (_) {
      return null; // motor no responde → sin plan honesto.
    }

    final specs = _parseSemantic(result.text);
    if (specs.isEmpty) return null;
    return _planner.planFromSemantic(goal, specs);
  }

  /// Prompt de descomposición: solo semántica finita, salida JSON estricta.
  String _buildPrompt(String goal) {
    final vocab = kAllowedTaskSemantics.join(', ');
    return 'Descompone el objetivo en pasos SEMÁNTICOS. Responde SOLO con JSON, '
        'sin texto. Vocabulario permitido de "action": $vocab. '
        'Cada paso: {"action": "...", "produces": "<id>", '
        '"inputs": {"<param>": "<id_producido_previo>"}, '
        '"dependencies": ["<id_paso_previo>"]}. '
        'NO emitas tool names, shell, packages, selectores ni coordenadas. '
        'Objetivo: $goal';
  }

  /// Parseo tolerante del JSON (soporta ```json``` y texto circundante).
  List<SemanticStepSpec> _parseSemantic(String text) {
    final m = RegExp(r'(\{[\s\S]*\})').firstMatch(text);
    if (m == null) return const [];
    try {
      final decoded = jsonDecode(m.group(1)!);
      final steps = (decoded is Map ? decoded['steps'] : null) as List?;
      if (steps == null) return const [];
      return steps.whereType<Map>().map((s) {
        final inputs = <String, String>{};
        final rawInputs = s['inputs'];
        if (rawInputs is Map) {
          rawInputs.forEach((k, v) => inputs['$k'] = '$v');
        }
        final deps = <String>[];
        final rawDeps = s['dependencies'];
        if (rawDeps is List) {
          for (final d in rawDeps) {
            deps.add('$d');
          }
        }
        return SemanticStepSpec(
          action: '${s['action'] ?? ''}',
          produces: s['produces'] is String ? '${s['produces']}' : null,
          inputs: inputs,
          dependencies: deps,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }
}
