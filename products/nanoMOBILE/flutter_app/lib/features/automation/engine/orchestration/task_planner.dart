/// A15.0 — TaskPlanner: descompone un objetivo en TaskPlan.
///
/// Templates deterministas PRIMERO (0 LLM para patrones conocidos). La
/// descomposición por LLM es el fallback (fase siguiente); el modelo solo puede
/// emitir semántica finita, nunca ToolCalls/selectores/packages/shell.
library;

import '../planning/message_intent_parser.dart';
import '../planning/generic_ui_intent_parser.dart';
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
    // W9: "envíale a X" y "envíale" (bare, con "busca a Y" antes).
    'envíale a',
    'enviale a',
    'envíale',
    'enviale',
    'message to',
  ];

  /// T2.9-select — una mención aislada a "resultado" no basta: también debe
  /// existir una acción de selección o una referencia inequívoca al elemento.
  static final _selectResultAction = RegExp(
    r'\b(abre|abrir|selecciona|seleccionar|pulsa|pulsar|toca|tocar|elige|elegir|open|select|click|tap)\b',
  );
  static final _selectResultOrdinal = RegExp(
    r'\b(primer[oa]?|segund[oa]?|tercer[oa]?|cuart[oa]?|quint[oa]?|resultado\s+\d+|result\s+\d+)\b',
  );

  /// Devuelve el TaskPlan determinista si el objetivo matchea un template.
  /// null = sin template (requeriría descomposición LLM, fuera de esta fase).
  TaskPlan? plan(String goal) {
    final g = goal.toLowerCase();
    if (_saveVerbs.any(g.contains)) return _saveUrlPlan(goal);
    if (_openVerbs.any(g.contains)) return _openUrlPlan(goal);
    final conversation = const MessageIntentParser().parse(goal);
    // Mensajería ANTES que búsqueda: "abre WhatsApp, busca a Juan y envíale: X"
    // contiene "busca " pero es intención de mensaje (verbo "envíale").
    // La intención parseada también cubre el verbo de payload aislado de una
    // navegación explícita: "entra al chat de Edgar y escribe, hola". Basarse
    // en el resultado estructurado evita duplicar aquí toda la gramática del
    // parser y, sobre todo, impide degradar el comando a solo abrir el chat.
    final hasGroundedMessage =
        conversation.app.isNotEmpty &&
        conversation.recipient.isNotEmpty &&
        conversation.message.isNotEmpty;
    if (_messageVerbs.any(g.contains) || hasGroundedMessage) {
      return _messagePlan(goal);
    }
    final genericCompose = const GenericUiIntentParser().parseCompose(goal);
    if (genericCompose.isComplete) return _composeElementPlan(goal);
    final genericFill = const GenericUiIntentParser().parseFill(goal);
    if (genericFill.isComplete) return _fillElementPlan(goal);
    final genericUi = const GenericUiIntentParser().parse(goal);
    if (genericUi.isComplete) return _activateElementPlan(goal);
    if (conversation.app.isNotEmpty && conversation.recipient.isNotEmpty) {
      return _openConversationPlan(goal);
    }
    if (_isSelectResultIntent(g)) return _selectResultPlan(goal);
    final search = const GenericUiIntentParser().parseSearch(goal);
    if (search.hasQuery) {
      if (_isReproductionIntent(g)) {
        return _reproductionPlan(goal, openApp: search.app.isNotEmpty);
      }
      return _searchPlan(goal, openApp: search.app.isNotEmpty);
    }
    return null;
  }

  /// "reproduce X en youtube" / "ponme X" — buscar Y abrir el primer
  /// resultado (la app de reproducción lo inicia al abrirlo).
  static final _reproductionVerb = RegExp(
    r'reproduce|reproducir|ponme|pon(?:le)?|play',
    caseSensitive: false,
  );

  bool _isReproductionIntent(String goal) =>
      _reproductionVerb.hasMatch(goal.trim());

  /// Búsqueda + selección del primer resultado en un solo plan. Cada paso es
  /// semántico y verificado; la apertura del video inicia la reproducción.
  TaskPlan _reproductionPlan(String goal, {required bool openApp}) {
    final write = TaskStep(
      id: 'write_query',
      semanticAction: 'writeQuery',
      dependencies: openApp ? const ['open_app'] : const [],
    );
    return TaskPlan(
      goal: goal,
      steps: [
        if (openApp)
          const TaskStep(id: 'open_app', semanticAction: 'openApp'),
        write,
        const TaskStep(
          id: 'submit_search',
          semanticAction: 'submitSearch',
          dependencies: ['write_query'],
        ),
        const TaskStep(
          id: 'select_result',
          semanticAction: 'selectResult',
          dependencies: ['submit_search'],
        ),
      ],
    );
  }

  /// "abre WhatsApp y entra en el grupo X" → abrir app y navegar hasta X.
  /// Reutiliza el navegador orientado a objetivos; no produce taps genéricos.
  TaskPlan _openConversationPlan(String goal) => TaskPlan(
    goal: goal,
    steps: const [
      TaskStep(id: 'open_app', semanticAction: 'openApp'),
      TaskStep(
        id: 'open_conversation',
        semanticAction: 'openConversation',
        dependencies: ['open_app'],
      ),
    ],
  );

  /// "abre Ajustes y toca Bluetooth" → abre la app mediante catálogo y activa
  /// un único elemento observado. El selector físico se resuelve después,
  /// contra una captura fresca; el texto del usuario nunca se vuelve coordenada.
  TaskPlan _activateElementPlan(String goal) => TaskPlan(
    goal: goal,
    steps: const [
      TaskStep(id: 'open_app', semanticAction: 'openApp'),
      TaskStep(
        id: 'activate_element',
        semanticAction: 'activateElement',
        dependencies: ['open_app'],
      ),
    ],
  );

  /// Escritura universal acotada: app instalada → campo editable nombrado →
  /// reemplazo verificado. No pulsa botones ni publica el contenido.
  TaskPlan _fillElementPlan(String goal) => TaskPlan(
    goal: goal,
    steps: const [
      TaskStep(id: 'open_app', semanticAction: 'openApp'),
      TaskStep(
        id: 'fill_element',
        semanticAction: 'fillElement',
        dependencies: ['open_app'],
      ),
    ],
  );

  /// Composición universal segura: cada mutación es un paso gobernado y el
  /// orquestador vuelve a observar antes de escribir. No existe submit final.
  TaskPlan _composeElementPlan(String goal) => TaskPlan(
    goal: goal,
    steps: const [
      TaskStep(id: 'open_app', semanticAction: 'openApp'),
      TaskStep(
        id: 'activate_element',
        semanticAction: 'activateElement',
        dependencies: ['open_app'],
      ),
      TaskStep(
        id: 'fill_element',
        semanticAction: 'fillElement',
        dependencies: ['activate_element'],
        dependencyEvidence: {'activate_element': RequiredEvidence.verified},
      ),
    ],
  );

  bool _isSelectResultIntent(String goal) {
    final mentionsResult =
        goal.contains('resultado') || goal.contains('result');
    if (!mentionsResult) return false;
    return _selectResultAction.hasMatch(goal) ||
        _selectResultOrdinal.hasMatch(goal) ||
        goal.contains('que dice') ||
        goal.contains('that says');
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
        dependencyEvidence: {'open_conversation': RequiredEvidence.verified},
      ),
      TaskStep(
        id: 'send_message',
        semanticAction: 'sendMessage',
        dependencies: ['write_message'],
        dependencyEvidence: {'write_message': RequiredEvidence.verified},
      ),
    ],
  );

  /// T2.9 — "abre YouTube y busca X" / "busca X en YouTube" → openApp →
  /// writeQuery → submitSearch. El query y la app los resuelve la capa
  /// Candidate-First/parse; el plan fija la semántica y el orden.
  TaskPlan _searchPlan(String goal, {required bool openApp}) {
    final write = TaskStep(
      id: 'write_query',
      semanticAction: 'writeQuery',
      dependencies: openApp ? const ['open_app'] : const [],
    );
    return TaskPlan(
      goal: goal,
      steps: [
        if (openApp) const TaskStep(id: 'open_app', semanticAction: 'openApp'),
        write,
        const TaskStep(
          id: 'submit_search',
          semanticAction: 'submitSearch',
          dependencies: ['write_query'],
        ),
      ],
    );
  }

  /// T2.9-select — "abre el segundo resultado" / "abre el resultado que dice X"
  /// → selectResult (un solo paso). El ordinal/texto lo parsea el orquestador;
  /// la resolución física (nodo real) queda en Candidate-First/ScreenGraph.
  TaskPlan _selectResultPlan(String goal) => TaskPlan(
    goal: goal,
    steps: const [
      TaskStep(id: 'select_result', semanticAction: 'selectResult'),
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
