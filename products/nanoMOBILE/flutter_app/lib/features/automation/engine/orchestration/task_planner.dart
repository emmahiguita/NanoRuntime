/// A15.0 — TaskPlanner: descompone un objetivo en TaskPlan.
///
/// Templates deterministas PRIMERO (0 LLM para patrones conocidos). La
/// descomposición por LLM es el fallback (fase siguiente); el modelo solo puede
/// emitir semántica finita, nunca ToolCalls/selectores/packages/shell.
library;

import 'task_plan.dart';
import 'task_step_vocabulary.dart';

/// Paso semántico crudo emitido por el LLM (A15.2). Solo `action` del
/// vocabulario finito; nunca tool names, shell, packages, selectores ni
/// coordenadas.
class SemanticStepSpec {
  final String action;
  final String? produces;

  /// param -> TaskValueId fuente (producido por un paso previo).
  final Map<String, String> inputs;
  final List<String> dependencies;

  const SemanticStepSpec({
    required this.action,
    this.produces,
    this.inputs = const {},
    this.dependencies = const [],
  });
}

class TaskPlanner {
  const TaskPlanner();

  static const _saveVerbs = [
    'guarda el enlace',
    'guardar el enlace',
    'guarda el link',
    'guardar el link',
    'guarda la url',
    'guardar url',
    'save the link',
    'save link',
  ];

  static const _openVerbs = [
    'abre el enlace',
    'abrir el enlace',
    'abre el link',
    'abrir el link',
    'abre la url',
    'abrir url',
    'open the link',
    'open link',
  ];

  static const _messageVerbs = [
    'escríbele a',
    'escribele a',
    'escríbale a',
    'escribe a',
    'escríbele',
    'mensaje a',
    'manda un mensaje a',
    'envía un mensaje a',
    'message to',
  ];

  /// T2.9 — verbos de búsqueda genérica (dentro de una app).
  static const _searchVerbs = [
    'busca ',
    'buscar ',
    'search for ',
    'search ',
  ];

  /// Devuelve el TaskPlan determinista si el objetivo matchea un template.
  /// null = sin template (requeriría descomposición LLM, fuera de esta fase).
  TaskPlan? plan(String goal) {
    final g = goal.toLowerCase();
    if (_saveVerbs.any(g.contains)) return _saveUrlPlan(goal);
    if (_openVerbs.any(g.contains)) return _openUrlPlan(goal);
    if (_searchVerbs.any(g.contains)) return _searchPlan(goal);
    if (_messageVerbs.any(g.contains)) return _messagePlan(goal);
    return null;
  }

  /// "escríbele a X" → openApp → openConversation → writeMessage → sendMessage.
  /// El target/draft los resuelve la capa Candidate-First (ScreenGraphCandidateProvider
  /// usa el continuationTarget del request); el plan fija la semántica y el orden.
  TaskPlan _messagePlan(String goal) => TaskPlan(
    goal: goal,
    steps: const [
      TaskStep(id: 'open_app', semanticAction: 'openApp'),
      TaskStep(
        id: 'open_conversation',
        semanticAction: 'openConversation',
        dependencies: ['open_app'],
      ),
      TaskStep(
        id: 'write_message',
        semanticAction: 'writeMessage',
        dependencies: ['open_conversation'],
      ),
      TaskStep(
        id: 'send_message',
        semanticAction: 'sendMessage',
        dependencies: ['write_message'],
      ),
    ],
  );

  /// T2.9 — "abre YouTube y busca X" / "busca X en YouTube" → openApp →
  /// writeQuery → submitSearch. El query y la app los resuelve la capa
  /// Candidate-First/parse; el plan fija la semántica y el orden.
  TaskPlan _searchPlan(String goal) => TaskPlan(
    goal: goal,
    steps: const [
      TaskStep(id: 'open_app', semanticAction: 'openApp'),
      TaskStep(
        id: 'write_query',
        semanticAction: 'writeQuery',
        dependencies: ['open_app'],
      ),
      TaskStep(
        id: 'submit_search',
        semanticAction: 'submitSearch',
        dependencies: ['write_query'],
      ),
    ],
  );

  /// A15.2 — descomposición LLM VALIDADA. Recibe pasos semánticos del modelo y
  /// construye un TaskPlan solo si TODOS pasan la validación:
  /// - action dentro del vocabulario finito (no shell/tool arbitrario);
  /// - sin ciclos, dependencias conocidas, maxSteps.
  /// Devuelve null (rechazo) si hay semántica inválida o el plan no valida.
  TaskPlan? planFromSemantic(String goal, List<SemanticStepSpec> specs) {
    if (specs.isEmpty) return null;
    final semErr = validateSemantics(specs.map((s) => s.action).toList());
    if (semErr != null) return null;

    final steps = <TaskStep>[];
    for (var i = 0; i < specs.length; i++) {
      final spec = specs[i];
      steps.add(
        TaskStep(
          id: 'step_$i',
          semanticAction: spec.action,
          inputBindings: {
            for (final e in spec.inputs.entries)
              e.key: TaskInputBinding(e.key, TaskValueId(e.value)),
          },
          produces: spec.produces != null ? TaskValueId(spec.produces!) : null,
          dependencies: spec.dependencies,
        ),
      );
    }

    final plan = TaskPlan(goal: goal, steps: steps);
    return plan.validate() == null ? plan : null;
  }

  /// "guarda el enlace de X" → readNotification → extractUrl → writeFile.
  TaskPlan _saveUrlPlan(String goal) => TaskPlan(
    goal: goal,
    steps: const [
      TaskStep(
        id: 'read_notification',
        semanticAction: 'readNotification',
        produces: TaskValueId('notification.latest'),
      ),
      TaskStep(
        id: 'extract_url',
        semanticAction: 'extractUrl',
        inputBindings: {
          'text': TaskInputBinding('text', TaskValueId('notification.latest')),
        },
        produces: TaskValueId('notification.latest.url'),
        dependencies: ['read_notification'],
      ),
      TaskStep(
        id: 'write_file',
        semanticAction: 'writeFile',
        inputBindings: {
          'content': TaskInputBinding(
            'content',
            TaskValueId('notification.latest.url'),
          ),
        },
        produces: TaskValueId('output.file'),
        dependencies: ['extract_url'],
      ),
    ],
  );

  /// "abre el enlace de X" → readNotification → extractUrl → openUrl.
  TaskPlan _openUrlPlan(String goal) => TaskPlan(
    goal: goal,
    steps: const [
      TaskStep(
        id: 'read_notification',
        semanticAction: 'readNotification',
        produces: TaskValueId('notification.latest'),
      ),
      TaskStep(
        id: 'extract_url',
        semanticAction: 'extractUrl',
        inputBindings: {
          'text': TaskInputBinding('text', TaskValueId('notification.latest')),
        },
        produces: TaskValueId('notification.latest.url'),
        dependencies: ['read_notification'],
      ),
      TaskStep(
        id: 'open_url',
        semanticAction: 'openUrl',
        inputBindings: {
          'url': TaskInputBinding(
            'url',
            TaskValueId('notification.latest.url'),
          ),
        },
        dependencies: ['extract_url'],
      ),
    ],
  );
}
