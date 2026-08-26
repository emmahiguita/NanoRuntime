/// A15.0 — TaskPlanner: descompone un objetivo en TaskPlan.
///
/// Templates deterministas PRIMERO (0 LLM para patrones conocidos). La
/// descomposición por LLM es el fallback (fase siguiente); el modelo solo puede
/// emitir semántica finita, nunca ToolCalls/selectores/packages/shell.
library;

import 'task_plan.dart';

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

  /// Devuelve el TaskPlan determinista si el objetivo matchea un template.
  /// null = sin template (requeriría descomposición LLM, fuera de esta fase).
  TaskPlan? plan(String goal) {
    final g = goal.toLowerCase();
    if (_saveVerbs.any(g.contains)) return _saveUrlPlan(goal);
    if (_openVerbs.any(g.contains)) return _openUrlPlan(goal);
    return null;
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
