/// AutomationCoordinator — único dueño del CICLO DE EJECUCIÓN de
/// automatización (SRP/DIP).
///
/// Responde a: "tengo un objetivo y un plan (o un flujo verificado en cache):
/// ¿lo ejecuto bajo política, verifico y devuelvo un resultado honesto?".
///
/// Es SOLO orquestación de ejecución. NO genera el plan desde el LLM (eso es
/// de los planners, aguas arriba) ni renderiza mensajes (eso es del llamador,
/// p.ej. el chat). Encapsula la gobernanza y las piezas del motor para que el
/// llamador no conozca `AgentLoop`/`ExperienceCache`/`NanoFlowExecutor`/
/// `ActionPathRouter`/adapters — un solo cerebro de ejecución.
library;

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart'
    show
        AgentToolDispatcher,
        PlanOutcome,
        ToolCall,
        ToolExecutionStatus,
        ToolOutcome;
import 'package:nanoai/features/automation/engine/planning/automation_planner.dart'
    show AutomationPlanner;
import 'package:nanoai/features/automation/engine/memory/experience_cache.dart'
    show ExperienceCache;
import 'package:nanoai/features/automation/engine/memory/object_memory.dart'
    show NanoObjectMemory, UiObjectKey, UiSelectorEvidence;
import 'package:nanoai/features/automation/engine/perception/perception_mux.dart'
    show PerceptionMux;
import 'package:nanoai/features/automation/engine/planning/deterministic_catalog.dart'
    show DeterministicFlowCatalog;
import 'package:nanoai/features/automation/engine/trust/instruction_trust.dart'
    show InstructionTrust;
import 'package:nanoai/features/automation/engine/execution/goal_verifier.dart'
    show GoalExpectation, GoalStatus, GoalVerification;
import 'package:nanoai/features/automation/engine/execution/nano_flow.dart'
    show FlowExecutionResult, NanoFlow, NanoFlowExecutor;
import 'package:nanoai/features/automation/engine/system/app_launch_resolver.dart'
    show AppLaunchResolver;
import 'package:nanoai/features/automation/engine/browser/web_search_resolver.dart'
    show WebSearchResolver;
import 'package:nanoai/features/automation/engine/governance/action_governance_pipeline.dart'
    show
        GovernanceApproved,
        GovernanceClarification,
        GovernanceConfirmation,
        GovernanceDenied,
        GovernanceMoreEvidence,
        GovernanceOutcome;
import 'package:nanoai/features/automation/engine/governance/intent_spec.dart'
    show GovernanceReason;
import 'package:nanoai/features/automation/engine/planning/candidate_first_planner.dart'
    show
        CandidateFirstPlanner,
        CandidatePlanGoverned,
        CandidatePlanNoCandidate,
        CandidatePlanResolved;
import 'package:nanoai/features/automation/engine/orchestration/task_decomposer.dart';
import 'package:nanoai/features/automation/engine/orchestration/task_orchestrator.dart';
import 'package:nanoai/features/automation/engine/orchestration/task_plan.dart'
    show TaskPlan, TaskStepResult, TaskStepStatus;
import 'package:nanoai/features/automation/engine/orchestration/task_planner.dart';
import 'package:nanoai/features/automation/engine/orchestration/automation_run.dart';
import 'package:nanoai/features/automation/engine/voice/execution_cancellation.dart';
import 'package:nanoai/features/automation/engine/planning/whatsapp_intent_parser.dart'
    show WhatsAppIntentParser, WhatsAppAction;


import '../domain/automation_goal.dart' show AutomationGoal, AutomationOptions;
import '../domain/automation_policy.dart'
    show AgentAutomationMode, AutomationPolicy;
import '../domain/automation_result.dart'
    show AutomationResult, AutomationResultStatus;
import '../benchmark/c14_metrics.dart' show C14Execution;
import '../engine/capabilities/reply_intent_vocabulary.dart'
    show ReplyIntentVocabulary;
import '../engine/execution/tool_registry.dart' show PolicyVerdict;
import '../engine/governance/action_confirmation.dart' show ActionConfirmation;
import '../engine/governance/rule_execution_authority.dart'
    show RuleExecutionAuthority;
import '../ledger/action_ledger.dart' show ActionLedger;
import '../ledger/automation_trace.dart' show AutomationTrace;

part 'automation_coordinator_execution.dart';
part 'automation_coordinator_results.dart';

/// Coordinador del ciclo de ejecución. Inyecta sus dependencias (DIP).
class AutomationCoordinator {
  final ExperienceCache? _cache;
  final NanoFlowExecutor? _flowExecutor;
  final AgentToolDispatcher _dispatcher;

  /// Fuente del nivel de autonomía actual (puede cambiar en runtime vía
  /// settings). Se inyecta como función para no acoplar el coordinator a
  /// settings/Riverpod.
  final AgentAutomationMode Function() _mode;

  /// Ledger de ejecuciones reales (auditoría / C14). null = no trazar.
  final ActionLedger? _ledger;

  /// Planner REAL (LLM) para generar un plan cuando no hay flujo en cache ni
  /// plan provisto. null = no planear (devuelve noPlan).
  final AutomationPlanner? _planner;

  /// Sink de métricas del benchmark físico (C14). null = no emitir. Inyectable
  /// solo por el harness C14; el resto del módulo no lo usa.
  final void Function(C14Execution)? _c14Sink;

  /// Verificador de objetivo (GOAL level) para el aprendizaje SOUND. null =
  /// no se puede verificar → no se aprende (no memorizar planes no verificados).
  final Future<GoalVerification> Function(
    String goal, {
    required bool planCompleted,
    GoalExpectation? expectation,
  })?
  _verifyGoal;

  /// Catálogo determinista: flujos conocidos para objetivos comunes (funcionan
  /// SIN el modelo LLM). null = no usar (solo cache + planner).
  final DeterministicFlowCatalog? _catalog;

  /// C10 — memoria de identidad de objetos UI. Resuelve selectores semánticos a
  /// selectores VERIFICADOS (resourceId) + aprende de la verificación. Mutable
  /// (copy-on-write): registrar un acierto/fallo devuelve una memoria nueva.
  NanoObjectMemory? _objectMemory;

  /// C12 — perceptores de pantalla fusionados. Fallback en vivo cuando [C10] no
  /// tiene un selector verificado para el concepto. null = sin percepción.
  final PerceptionMux? _perceptionMux;

  /// A2 — resolvedor determinista de "abre <app>" grounded en el catálogo de
  /// apps instaladas. null = sin inventario (no se resuelven apps por nombre).
  final AppLaunchResolver? _appLaunch;

  /// Búsquedas web directas en Chrome/Google/Internet (Fast-Path <50ms).
  final WebSearchResolver? _webSearchResolver;

  /// A13.5 — planificador Candidate-First de producción (0 LLM para goals
  /// conocidos). null = sin pipeline (legacy fallback directo).
  final CandidateFirstPlanner? _candidateFirst;

  /// A15.0 — orquestador cross-app multi-paso con data flow tipado.
  final TaskPlanner? _taskPlanner;
  final TaskOrchestrator? _taskOrchestrator;

  /// A15.2 — descomposición (template determinista + LLM validado).
  final LlmTaskDecomposer? _taskDecomposer;

  /// Registro de ejecución, no owner de su estado. Cada valor [AutomationRun]
  /// posee su propia cancelación, evidencia, confirmación y lifecycle.
  final Map<String, AutomationRun> _activeRuns = {};

  /// Cancela la tarea activa (cooperativo). Las acciones irreversibles ya
  /// completadas no se revierten; se detiene el trabajo pendiente.
  void cancelCurrent() {
    if (_activeRuns.isEmpty) return;
    _activeRuns.values.last.cancellation.cancel();
  }

  /// Cancela únicamente la ejecución solicitada. Nunca afecta otro run activo.
  bool cancelExecution(String executionId) {
    final run = _activeRuns[executionId];
    if (run == null) return false;
    run.cancellation.cancel();
    return true;
  }

  /// A13.6 — callback para compartir la instancia de memoria actualizada con la
  /// DI (el notifier). null en tests/aislado.
  final void Function(NanoObjectMemory)? _onMemoryUpdate;

  /// Snapshot de solo lectura para diagnóstico/tests. La memoria interna sigue
  /// siendo copy-on-write y solo el coordinator puede reemplazarla.
  NanoObjectMemory? get objectMemorySnapshot => _objectMemory;

  AutomationCoordinator({
    required AgentToolDispatcher dispatcher,
    required AgentAutomationMode Function() mode,
    ExperienceCache? cache,
    NanoFlowExecutor? flowExecutor,
    ActionLedger? ledger,
    AutomationPlanner? planner,
    Future<GoalVerification> Function(
      String goal, {
      required bool planCompleted,
      GoalExpectation? expectation,
    })?
    verifyGoal,
    DeterministicFlowCatalog? catalog,
    NanoObjectMemory? objectMemory,
    PerceptionMux? perceptionMux,
    AppLaunchResolver? appLaunch,
    WebSearchResolver? webSearchResolver,
    CandidateFirstPlanner? candidateFirst,
    TaskPlanner? taskPlanner,
    TaskOrchestrator? taskOrchestrator,
    LlmTaskDecomposer? taskDecomposer,
    void Function(NanoObjectMemory)? onMemoryUpdate,
    void Function(C14Execution)? c14Sink,
  }) : _dispatcher = dispatcher,
       _mode = mode,
       _cache = cache,
       _flowExecutor = flowExecutor,
       _ledger = ledger,
       _planner = planner,
       _verifyGoal = verifyGoal,
       _catalog = catalog,
       _objectMemory = objectMemory,
       _perceptionMux = perceptionMux,
       _appLaunch = appLaunch,
       _webSearchResolver = webSearchResolver ?? const WebSearchResolver(),
       _candidateFirst = candidateFirst,
       _taskPlanner = taskPlanner,
       _taskOrchestrator = taskOrchestrator,
       _taskDecomposer = taskDecomposer,
       _onMemoryUpdate = onMemoryUpdate,
       _c14Sink = c14Sink;

  AutomationPolicy get _policy => AutomationPolicy(_mode());

  /// Copia este coordinator con un sink de métricas C14 asociado (para el
  /// benchmark). Conserva las mismas dependencias; solo cambia el sink.
  AutomationCoordinator withSink(void Function(C14Execution) sink) =>
      AutomationCoordinator(
        dispatcher: _dispatcher,
        mode: _mode,
        cache: _cache,
        flowExecutor: _flowExecutor,
        ledger: _ledger,
        planner: _planner,
        verifyGoal: _verifyGoal,
        catalog: _catalog,
        objectMemory: _objectMemory,
        perceptionMux: _perceptionMux,
        appLaunch: _appLaunch,
        webSearchResolver: _webSearchResolver,
        candidateFirst: _candidateFirst,
        taskPlanner: _taskPlanner,
        taskOrchestrator: _taskOrchestrator,
        taskDecomposer: _taskDecomposer,
        onMemoryUpdate: _onMemoryUpdate,
        c14Sink: sink,
      );

  /// Mapea un resultado de gobernanza (A11) a un [AutomationResult] honesto.
  AutomationResult _resultFromGoverned(
    String executionId,
    GovernanceOutcome outcome,
  ) {
    return switch (outcome) {
      GovernanceDenied(:final reason) => AutomationResult(
        executionId: executionId,
        status: AutomationResultStatus.denied,
        reason: 'Gobernanza denegó la acción: ${reason.name}.',
      ),
      GovernanceConfirmation(:final reason) => AutomationResult(
        executionId: executionId,
        status: AutomationResultStatus.paused,
        reason: 'Requiere confirmación: ${reason.name}.',
      ),
      GovernanceMoreEvidence(:final reason) => AutomationResult(
        executionId: executionId,
        status: AutomationResultStatus.noPlan,
        reason: 'Evidencia insuficiente: ${reason.name}.',
      ),
      GovernanceClarification(:final reason) => AutomationResult(
        executionId: executionId,
        status: AutomationResultStatus.paused,
        reason: 'Requiere clarificación: ${reason.name}.',
      ),
      GovernanceApproved() => AutomationResult(
        executionId: executionId,
        status: AutomationResultStatus.failed,
        reason: 'Estado de gobernanza inesperado.',
      ),
    };
  }

  // ── Política de gobernanza ────────────────────────────────────────────────

  /// ¿Este tool requiere confirmación humana antes de actuar? (modo actual).
  bool requiresConfirmation(String tool) =>
      _dispatcher.requiresConfirmation(tool);

  /// Descripción legible para mostrar al usuario por qué pide confirmación.
  String confirmationDescription(String tool) =>
      _policy.confirmationDescription(tool);

  static int _seq = 0;
  String _newId() => 'auto-${DateTime.now().microsecondsSinceEpoch}-${++_seq}';

  // ── Camino determinista (C7→C8) ───────────────────────────────────────────

  /// Intenta resolver [goal] con un flujo VERIFICADO en cache (sin LLM).
  Future<({FlowExecutionResult result, List<ToolCall> steps})?>
  tryDeterministic(
    String goal, {
    GoalExpectation? expectation,
    AutomationRun? run,
    ActionConfirmation? confirmation,
  }) => tryDeterministicInternal(
    goal,
    expectation: expectation,
    run: run,
    confirmation: confirmation,
  );

  /// Ejecuta exclusivamente un flujo conocido del catálogo, sin planner.
  Future<({AutomationResult result, List<ToolCall> steps})?> tryKnownFlow(
    String goal,
  ) => tryKnownFlowInternal(goal);

  // ── Ejecución de plan / tarea cross-app / herramienta ─────────────────────

  Future<List<TaskStepResult>?> runCrossAppTask(
    String goal, {
    AutomationRun? run,
    ActionConfirmation? confirmation,
    String? executionId,
    bool deterministicOnly = false,
  }) => runCrossAppTaskInternal(
    goal,
    run: run,
    confirmation: confirmation,
    executionId: executionId,
    deterministicOnly: deterministicOnly,
  );

  Future<({AutomationResult result, List<TaskStepResult> steps})?> tryCrossApp(
    String goal, {
    AutomationRun? run,
    ActionConfirmation? confirmation,
    String? executionId,
    bool deterministicOnly = true,
  }) => tryCrossAppInternal(
    goal,
    run: run,
    confirmation: confirmation,
    executionId: executionId,
    deterministicOnly: deterministicOnly,
  );

  Future<PlanOutcome> runPlan(
    List<ToolCall> plan, {
    AutomationRun? run,
    ActionConfirmation? confirmation,
    String? executionId,
    bool confirmed = false,
    String? recordGoal,
    GoalExpectation? expectation,
    RuleExecutionAuthority? authority,
  }) => runPlanInternal(
    plan,
    run: run,
    confirmation: confirmation,
    executionId: executionId,
    confirmed: confirmed,
    recordGoal: recordGoal,
    expectation: expectation,
    authority: authority,
  );

  Future<ToolOutcome> runTool(
    ToolCall call, {
    bool confirmed = false,
    String? executionId,
  }) => runToolInternal(call, confirmed: confirmed, executionId: executionId);

  Future<String> runCommand(String command) => runCommandInternal(command);

  /// Resetea el estado del turno del dispatcher (ciclo de vida de una ronda).
  void reset() => _dispatcher.resetTurn();

  // ── Entrada única del módulo ──────────────────────────────────────────────

  /// Ejecuta un [AutomationGoal] hasta un [AutomationResult] honesto.
  ///
  /// Punto de entrada ÚNICO del módulo (para chat, notificaciones, voz,
  /// eventos). Decide el camino:
  ///   1. Sin [plan] → flujo verificado en cache (C7→C8) si hay hit.
  ///   2. Sin [plan] y sin hit → el [AutomationPlanner] REAL genera un plan
  ///      con el LLM local y se ejecuta bajo gobernanza (motor autónomo).
  ///   3. Con [plan] (del LLM) → lo ejecuta bajo gobernanza (multi-paso o
  ///      tool única) y memoriza en cache (C7).
  ///
  /// NO renderiza (eso es del llamador). Registra la ejecución en el ledger.
  /// Nunca lanza por fallos de negocio: todo término es un [AutomationResult].
  Future<AutomationResult> execute(
    AutomationGoal goal, {
    List<ToolCall>? plan,
    AutomationOptions? options,
  }) async {
    final sw = Stopwatch()..start();
    final startedAt = DateTime.now();
    final confirmed = options?.confirmed ?? false;
    final confirmation = options?.confirmation;
    // Una reanudación debe conservar la identidad firmada por el token. La UI
    // solo necesita devolver la confirmación recibida; generar aquí un id
    // nuevo hacía que el journal rechazara siempre su propio token.
    final executionId =
        options?.executionId ?? confirmation?.executionId ?? _newId();
    if (_activeRuns.containsKey(executionId)) {
      return AutomationResult(
        executionId: executionId,
        status: AutomationResultStatus.denied,
        reason: 'Ya existe una ejecución activa con este executionId.',
      );
    }
    final run = AutomationRun(
      executionId: executionId,
      goal: goal.text,
      confirmation: confirmation,
      cancellation: ExecutionCancellationToken(isCurrent: options?.isCurrent),
    );
    _activeRuns[executionId] = run;

    // Métricas C14 acumuladas a lo largo del camino (diagnóstico del planner).
    var cacheHit = false;
    var llmLatency = Duration.zero;
    var toolLatency = Duration.zero;
    var generatedCount = 0;
    var rejectedCount = 0;
    var steps = 0;
    // A13.6: métricas Candidate-First / legacy (observabilidad C14).
    var candidateCount = 0;
    var selectionMode = 'none';
    var koogInvoked = false;
    var legacyFallback = false;
    var candidateLatency = Duration.zero;
    // A15.3: métricas de tareas cross-app multi-paso.
    var taskStepsCount = 0;
    var zeroLlmTask = false;
    var deterministicCrossAppAttempted = false;
    var semanticFallbackAttempted = false;
    // Expectativa efectiva para el run (usada en aprendizaje SOUND). Por defecto
    // la del goal; un flujo determinista del catálogo puede aportar la suya.
    var runExpectation = goal.expectation;
    var outputProvesGoal = false;

    void emit(AutomationResult r) {
      final sink = _c14Sink;
      if (sink == null) return;
      sink(
        C14Execution(
          goal: goal.text,
          planValid: r.status != AutomationResultStatus.noPlan,
          toolsGenerated: generatedCount,
          toolsRejected: rejectedCount,
          steps: steps,
          path: cacheHit ? 'cache' : (generatedCount > 0 ? 'llm' : 'none'),
          llmLatency: llmLatency,
          toolLatency: toolLatency,
          verification: r.status,
          retries: 0,
          replans: 0,
          cacheHit: cacheHit,
          goalSuccess: r.isVerifiedSuccess,
          totalLatency: sw.elapsed,
          candidateCount: candidateCount,
          selectionMode: selectionMode,
          koogInvoked: koogInvoked,
          legacyFallback: legacyFallback,
          candidateLatency: candidateLatency,
          taskSteps: taskStepsCount,
          zeroLlmTask: zeroLlmTask,
        ),
      );
    }

    AutomationResult finish(AutomationResult result) {
      emit(result);
      run.finish(status: result.status.name, reason: result.reason);
      recordTrace(
        executionId: executionId,
        goal: goal.text,
        status: result.status,
        summary: result.reason,
        pauseIndex: result.pauseIndex,
        pauseTool: result.pauseTool,
        startedAt: startedAt,
      );
      return result;
    }

    try {
      run.beginPlanning();
      run.cancellation.throwIfCancelled();
      // C11: solo una INSTRUCCIÓN real del usuario autoriza ejecutar. Un goal
      // vacío/espacio no es instrucción → noPlan (no se actúa sin orden).
      if (!InstructionTrust(userInstruction: goal.text).authorizesExecution()) {
        final r = AutomationResult(
          executionId: executionId,
          status: AutomationResultStatus.noPlan,
          reason: 'Sin instrucción autorizada del usuario.',
        );
        return finish(r);
      }

      final replyCapability = options?.replyCapability;
      if (replyCapability != null) {
        if (!replyCapability.isUsable ||
            (options?.replyText?.trim().isEmpty ?? true)) {
          return finish(
            AutomationResult(
              executionId: executionId,
              status: AutomationResultStatus.failed,
              reason: 'capacidad de respuesta observada inválida',
            ),
          );
        }
        plan = [
          ToolCall(
            tool: 'reply_notification',
            args: {
              'key': replyCapability.notificationKey,
              'text': options!.replyText!,
              'actionIndex': replyCapability.actionIndex,
              'remoteInputKey': replyCapability.remoteInputResultKey,
              'contextFingerprint': replyCapability.contextFingerprint,
              'postTime': replyCapability.observedAt,
              'incomingEventId': options.incomingEventId,
            },
          ),
        ];
      }

      if (plan == null) {
        // Un objetivo exacto del catálogo ya tiene semántica y evidencia
        // revisadas: ejecutarlo antes de la descomposición o selección evita convertir
        // una orden determinista conocida en pasos de UI arbitrarios.
        final known = _catalog?.forGoal(goal.text);
        if (known != null && known.steps.isNotEmpty) {
          // W10/WA-FULL: enriquecer steps del catálogo con datos del goal.
          // El catálogo emite ToolCalls const sin args dinámicos (contacto, mensaje).
          // El coordinator los inyecta aquí usando WhatsAppIntentParser.
          final enrichedSteps = known.steps.map((step) {
            final isWaTool = step.tool == 'whatsapp.contacts' ||
                step.tool == 'whatsapp.send_message' ||
                step.tool == 'whatsapp.open_chat' ||
                step.tool == 'whatsapp.share_file';
            if (!isWaTool) return step;

            // Parsear el goal con el parser dedicado.
            final intent = WhatsAppIntentParser.parse(goal.text);
            if (intent == null) return step;

            // Determina la herramienta real según la acción tipada del intent
            final targetTool = switch (intent.action) {
              WhatsAppAction.shareFile => 'whatsapp.share_file',
              WhatsAppAction.sendMessage => 'whatsapp.send_message',
              WhatsAppAction.openChat => 'whatsapp.open_chat',
              WhatsAppAction.findContact => step.tool,
            };

            // Map<String, Object?> — step.args puede tener valores nullable.
            final Map<String, Object?> extra = Map.of(step.args ?? {});
            if (intent.contact.isNotEmpty) {
              final key = targetTool == 'whatsapp.contacts' ? 'query' : 'contact';
              extra[key] = intent.contact;
            }
            if (targetTool == 'whatsapp.share_file') {
              if (intent.filePath != null && intent.filePath!.isNotEmpty) {
                extra['path'] = intent.filePath!;
              }
              if (intent.message != null && intent.message!.isNotEmpty) {
                extra['caption'] = intent.message!;
              }
            } else if (intent.message != null && intent.message!.isNotEmpty &&
                (targetTool == 'whatsapp.send_message' || targetTool == 'whatsapp.open_chat')) {
              extra['text'] = intent.message!;
              if (targetTool == 'whatsapp.send_message') extra['autoSend'] = true;
            }
            return ToolCall(
              tool: targetTool,
              args: extra,
              selector: step.selector,
              text: step.text,
            );
          }).toList();

          plan = enrichedSteps;
          runExpectation = goal.expectation ?? known.expectation;
          outputProvesGoal = known.outputProvesGoal;
        }
      }

      // WA-UI-07 — transporte primero: para intenciones de respuesta, el
      // candidato grounded (RemoteInput: 0 taps, 0 navegación) se intenta
      // ANTES del template UI cross-app. Un resolved de launch_app (abrir la
      // app sin enviar) NO satisface una respuesta: se ignora y el fallback
      // determinista de mensajería UI (openApp→openConversation→writeMessage→
      // sendMessage con revalidación de identidad) corre dentro de plan==null.
      if (plan == null &&
          _candidateFirst != null &&
          ReplyIntentVocabulary.matches(goal.text)) {
        final replyFirst = await _candidateFirst.plan(
          goal.text,
          authority: options?.authority,
        );
        if (replyFirst is CandidatePlanResolved &&
            replyFirst.call.tool == 'reply_notification') {
          plan = [replyFirst.call];
          runExpectation = replyFirst.expectation;
          selectionMode = replyFirst.selectionMode.name;
          koogInvoked = replyFirst.koogInvoked;
          candidateCount = replyFirst.candidateCount;
        } else if (replyFirst is CandidatePlanGoverned) {
          // WA-GUI-12 + causa observable: sin RemoteInput, el único candidato
          // grounded es launch_app (abrir la app por GUI), que el firewall
          // deniega como outsideIntent. Ese nombre interno no le dice nada al
          // usuario; se traduce a la causa real. Verificado en Oppo/ColorOS:
          // con WhatsApp abierto en primer plano la notificación se publica
          // degradada (sin reply rápido) y NO se restaura hasta un mensaje
          // nuevo con WhatsApp cerrado.
          final outcome = replyFirst.outcome;
          if (outcome is GovernanceDenied &&
              outcome.reason == GovernanceReason.outsideIntent) {
            final r = AutomationResult(
              executionId: executionId,
              status: AutomationResultStatus.denied,
              reason: options?.authority != null
                  ? 'Regla automática: la notificación ya no es contestable '
                        '(sin RemoteInput activo). Con WhatsApp abierto, '
                        'ColorOS degrada la notificación y el reply rápido '
                        'solo se restaura con un mensaje nuevo y WhatsApp '
                        'cerrado.'
                  : 'La notificación de la conversación ya no es contestable '
                        '(sin RemoteInput activo). No se abre la app por GUI '
                        'sin instrucción directa del usuario.',
            );
            return finish(r);
          }
          final r = _resultFromGoverned(executionId, replyFirst.outcome);
          return finish(r);
        }
        // WA-GUI-12 (verificado en físico): una regla automática JAMÁS abre la
        // app objetivo por GUI como fallback. Solo existe la autoridad del
        // usuario para la acción exacta de la regla (WA-AUTH-04): si el
        // RemoteInput grounded no resuelve (notificación consumida, app
        // cerrada), el resultado honesto es failed — sin lanzar WhatsApp ni
        // buscar el contacto. Sin este gate, el fallback cross-app (openApp→
        // openConversation→writeMessage→sendMessage) se ejecutaba tras un
        // envío ya confirmado por el usuario y abría la app innecesariamente.
        if (plan == null && options?.authority != null) {
          final r = AutomationResult(
            executionId: executionId,
            status: AutomationResultStatus.failed,
            reason:
                'Regla automática: sin RemoteInput grounded para responder '
                '(la notificación ya no está disponible). No se abre la app '
                'objetivo por GUI sin instrucción directa del usuario.',
          );
          return finish(r);
        }
      }

      if (plan == null) {
        // Búsqueda Web determinista conectada a navegadores con respuesta in-app en Nano
        final webSearch = _webSearchResolver?.resolve(goal.text);
        if (webSearch != null) {
          plan = [webSearch.call];
          runExpectation = webSearch.expectation;
          outputProvesGoal = webSearch.inApp;
        }
      }


        if (plan == null) {
          // A15.0: seam cross-app multi-paso (0 LLM). Si el TaskPlanner matchea un
          // template determinista (guarda/abre el enlace), el TaskOrchestrator lo
          // ejecuta con data flow tipado ANTES del flujo simple (que es single-step).
          final crossApp = await tryCrossApp(goal.text, run: run);
          if (crossApp != null) {
            // A15.3: telemetría cross-app (pasos de la tarea ejecutados).
            taskStepsCount = crossApp.steps.length;
            zeroLlmTask = true;
            final r = crossApp.result;
            return finish(r);
          }

          final deterministic = await tryDeterministic(
            goal.text,
            expectation: goal.expectation,
            run: run,
          );
          if (deterministic != null) {
            cacheHit = true;
            steps = deterministic.steps.length;
            final r = resultFromFlow(executionId, deterministic.result);
            return finish(r);
          }
        }

        // A13.5: Candidate-First queda reservado para objetivos que el catálogo
        // no resolvió. Resuelto → ejecutar; Governed → resultado honesto;
        // NoCandidate/ambiguo → cae al fallback siguiente.
        final candidateFirst = _candidateFirst;
        if (plan == null && candidateFirst != null) {
          final swCandidate = Stopwatch()..start();
          final candidatePlan = await candidateFirst.plan(goal.text);
          swCandidate.stop();
          candidateLatency = swCandidate.elapsed;
          if (candidatePlan is CandidatePlanResolved) {
            plan = [candidatePlan.call];
            runExpectation = candidatePlan.expectation;
            selectionMode = candidatePlan.selectionMode.name;
            koogInvoked = candidatePlan.koogInvoked;
            candidateCount = candidatePlan.candidateCount;
          } else if (candidatePlan is CandidatePlanGoverned) {
            final r = _resultFromGoverned(executionId, candidatePlan.outcome);
            return finish(r);
          } else if (candidatePlan is CandidatePlanNoCandidate) {
            candidateCount = candidatePlan.candidateCount;
            legacyFallback = true;
            selectionMode = 'legacyFallback';
          }
        }

        if (plan == null) {
          // A2: resolvedor grounded de "abre <app>" — package REAL del
          // PackageManager, nunca un package inventado por el modelo. Precede al
          // catálogo estático para que "abre Chrome" use el catálogo real.
          final appLaunch = _appLaunch;
          final launchPlan = appLaunch == null
              ? null
              : await appLaunch.resolve(goal.text);
          if (launchPlan != null) {
            plan = [launchPlan.call];
            runExpectation = launchPlan.expectation;
          } else {
            // AUT-15: solo después de agotar memoria, catálogo, candidatos e
            // inventario, permitir descomposición LLM a semántica finita.
            // El decomposer aplica AutomationModelResolver y nunca emite
            // tools, paquetes, selectores ni coordenadas arbitrarias.
            semanticFallbackAttempted = true;
            final semanticFallback = await tryCrossApp(
              goal.text,
              run: run,
              deterministicOnly: false,
            );
            if (semanticFallback != null) {
              taskStepsCount = semanticFallback.steps.length;
              zeroLlmTask = false;
              return finish(semanticFallback.result);
            }

            // Sin flujo en cache ni catálogo: planear con el LLM local.
            final planner = _planner;
            if (planner == null) {
              final r = AutomationResult(
                executionId: executionId,
                status: AutomationResultStatus.noPlan,
                reason: 'Sin flujo verificado en cache ni plan provisto.',
              );
              return finish(r);
            }
            run.cancellation.throwIfCancelled();
            final planned = await planner.plan(goal.text);
            run.cancellation.throwIfCancelled();
            llmLatency = planned.llmLatency;
            generatedCount = planned.generated;
            rejectedCount = planned.rejected;
            if (planned.calls.isEmpty) {
              final r = AutomationResult(
                executionId: executionId,
                status: AutomationResultStatus.noPlan,
                reason:
                    planned.unavailableReason ??
                    'El planner LLM no produjo acciones verificables para el objetivo.',
              );
              return finish(r);
            }
            plan = planned.calls;
          }
        }

      // Un array de gestos UI generado por un modelo no se ejecuta en cadena.
      // Se reconstruye como TaskPlan y TaskOrchestrator reobserva el mundo tras
      // cada acción. Si la intención no cabe en el vocabulario semántico real,
      // se detiene honestamente en lugar de actuar a ciegas.
      if (_dispatcher.requiresGoalDirectedExecution(plan)) {
        if (!deterministicCrossAppAttempted) {
          final deterministicGoalDirected = await tryCrossApp(
            goal.text,
            run: run,
          );
          if (deterministicGoalDirected != null) {
            taskStepsCount = deterministicGoalDirected.steps.length;
            zeroLlmTask = true;
            return finish(deterministicGoalDirected.result);
          }
        }
        if (!semanticFallbackAttempted) {
          final goalDirected = await tryCrossApp(
            goal.text,
            run: run,
            deterministicOnly: false,
          );
          if (goalDirected != null) {
            taskStepsCount = goalDirected.steps.length;
            zeroLlmTask = false;
            return finish(goalDirected.result);
          }
        }
        final r = AutomationResult(
          executionId: executionId,
          status: AutomationResultStatus.noPlan,
          reason:
              'El plan visual requiere navegación orientada a objetivos, pero '
              'no produjo un TaskPlan semántico verificable. No se ejecutó.',
        );
        return finish(r);
      }

      // C10/C12: anclar selectores semánticos a selectores reales (memoria/percepción).
      run.cancellation.throwIfCancelled();
      plan = await resolveSelectors(plan, goal.text);
      run.cancellation.throwIfCancelled();

      // Una única acción usa la misma ruta gobernada que un plan de varios
      // pasos. Así no existe una puerta de confirmación paralela capaz de
      // aceptar un bool genérico ni de perder executionId/plan/paso/acción.
      steps = plan.length;
      final t = Stopwatch()..start();
      final outcome = await runPlan(
        plan,
        run: run,
        confirmed: confirmed,
        recordGoal: goal.text,
        expectation: runExpectation,
        authority: options?.authority,
      );
      t.stop();
      toolLatency = t.elapsed;
      final base = resultFromPlan(executionId, outcome);
      final r = await finalizeExecution(
        executionId: executionId,
        goal: goal.text,
        base: base,
        expectation: runExpectation,
        outputProvesGoal: outputProvesGoal,
      );
      // REVIEW-01: el cache SOUND consume el veredicto de _finalizeExecution
      // (única verificación), no una segunda observación propia.
      await learn(goal.text, plan, r, runExpectation);
      recordMemory(goal.text, plan, r.status);
      return finish(r);
    } on ExecutionCancelled {
      return finish(
        AutomationResult(
          executionId: executionId,
          status: run.hasDispatchedPhysicalEffect
              ? AutomationResultStatus.outcomeUnknown
              : AutomationResultStatus.cancelled,
          reason: run.hasDispatchedPhysicalEffect
              ? 'Ejecución cancelada tras iniciar efectos físicos; resultado incierto.'
              : 'Ejecución cancelada por el usuario.',
        ),
      );
    } on Object catch (e, st) {
      debugPrint('[coordinator.execute] excepción no manejada: $e\n$st');
      // Invariante del contrato: si la excepción ocurre antes de iniciar efectos
      // físicos reales, el status es failed (seguro para retry/sin huérfano).
      // Si ya se despachó un efecto físico, el resultado es outcomeUnknown
      // para evitar doble replay automático.
      final hasStartedEffects = run.hasDispatchedPhysicalEffect;
      return finish(
        AutomationResult(
          executionId: executionId,
          status: hasStartedEffects
              ? AutomationResultStatus.outcomeUnknown
              : AutomationResultStatus.failed,
          reason: '[coordinatorException] $e',
        ),
      );
    } finally {
      if (identical(_activeRuns[executionId], run)) {
        _activeRuns.remove(executionId);
      }
    }
  }
}
