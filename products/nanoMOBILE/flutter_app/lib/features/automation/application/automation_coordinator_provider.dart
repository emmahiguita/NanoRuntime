import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/core/services/runtime_engine.dart';
import 'package:nanoai/features/automation/engine/agent_dependencies.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart'
    show ToolCall, ToolExecutionStatus, ToolOutcome;
import 'package:nanoai/features/automation/engine/memory/object_memory.dart';
import 'package:nanoai/features/automation/engine/orchestration/task_decomposer.dart';
import 'package:nanoai/features/automation/engine/orchestration/commit_guard.dart';
import 'package:nanoai/features/automation/engine/orchestration/execution_journal.dart'
    show ExecutionJournalEntry;
import 'package:nanoai/features/automation/engine/orchestration/task_orchestrator.dart';
import 'package:nanoai/features/automation/engine/orchestration/task_plan.dart'
    show TaskActionResult, TaskActionStatus;
import 'package:nanoai/features/automation/engine/orchestration/task_planner.dart';
import 'package:nanoai/features/automation/engine/planning/deterministic_catalog.dart'
    show defaultDeterministicCatalog;
import 'package:nanoai/features/automation/engine/perception/mux/perception_contracts.dart';
import 'package:nanoai/features/automation/engine/perception/semantic/screen_graph.dart';
import 'package:nanoai/features/automation/engine/perception/surface_resolvers.dart';
import 'package:nanoai/features/automation/engine/perception/search_result_resolver.dart';
import 'package:nanoai/features/automation/engine/scheduling/notification_event_router.dart';
import 'package:nanoai/features/automation/engine/scheduling/rule_dispatcher.dart';
import 'package:nanoai/features/automation/engine/scheduling/rule_engine.dart';
import 'package:nanoai/features/automation/engine/scheduling/rule_pipeline.dart';
import 'package:nanoai/features/automation/engine/scheduling/rule_registry.dart';
import 'package:nanoai/features/automation/engine/system/installed_app_catalog.dart';

import '../ledger/action_ledger_provider.dart';
import 'automation_coordinator.dart';
import 'automation_planner_provider.dart';

/// Coordinator del módulo con el planner LLM REAL inyectado — el motor
/// AUTÓNOMO reutilizable. Las fuentes de objetivo (chat, notificaciones, voz,
/// eventos, scheduler, C10+) consumen este provider para invocar el MISMO
/// motor con `execute(goal)`. Es la fuente de verdad de la DI del módulo.
final Provider<AutomationCoordinator>
automationCoordinatorProvider = Provider<AutomationCoordinator>((ref) {
  // Observación de la pantalla actual (Accessibility → ScreenGraph). Fuente
  // ÚNICA del snapshot para los resolvers de superficie y la verificación de
  // envío, evitando duplicar el boilerplate snapshot→ScreenGraph.
  Future<ScreenGraph?> currentGraph() async {
    final snap = await ref.read(agentExecutorProvider).snapshot();
    if (snap == null || snap.isEmpty) return null;
    return ScreenGraph.fromSnapshot(snap);
  }

  TaskActionResult taskActionFrom(ToolCall call, ToolOutcome outcome) {
    if (outcome.needsConfirmation) {
      return TaskActionResult(
        status: TaskActionStatus.needsConfirmation,
        reason: outcome.feedback,
        actionSignature: call.confirmationSignature,
      );
    }
    final status = switch (outcome.executionStatus) {
      ToolExecutionStatus.completed => TaskActionStatus.completed,
      ToolExecutionStatus.completedUnverified =>
        TaskActionStatus.completedUnverified,
      ToolExecutionStatus.outcomeUnknown => TaskActionStatus.outcomeUnknown,
      ToolExecutionStatus.failed => TaskActionStatus.failed,
      ToolExecutionStatus.notExecuted => TaskActionStatus.denied,
    };
    return TaskActionResult(status: status, reason: outcome.feedback);
  }

  Future<TaskActionResult> runTaskTool(
    ToolCall call, {
    String? confirmedActionSignature,
    String? semanticAction,
    String? executionId,
    ExecutionJournalEntry? executionIntent,
  }) async {
    final dispatcher = ref.read(agentDispatcherProvider);
    final confirmed = confirmedActionSignature == call.confirmationSignature;
    final ownerExecutionId = executionId ?? executionIntent?.runId;
    final outcome = semanticAction == null
        ? await dispatcher.runToolGuarded(
            call,
            confirmed: confirmed,
            executionId: ownerExecutionId,
          )
        : await dispatcher.runSemanticToolGuarded(
            call,
            semanticAction: semanticAction,
            confirmed: confirmed,
            executionId: ownerExecutionId,
            executionIntent: executionIntent,
          );
    return taskActionFrom(call, outcome);
  }

  return AutomationCoordinator(
    dispatcher: ref.watch(agentDispatcherProvider),
    mode: () => ref.read(settingsProvider).agentAutomationMode,
    cache: ref.watch(experienceCacheProvider),
    flowExecutor: ref.watch(nanoFlowExecutorProvider),
    ledger: ref.watch(actionLedgerProvider),
    planner: ref.watch(llmAutomationPlannerProvider),
    verifyGoal: ref.watch(goalVerifierProvider).verify,
    catalog: defaultDeterministicCatalog,
    objectMemory: const NanoObjectMemory(),
    // A13.6: compartir la instancia de memoria actualizada con el PerceptionMux
    // (vía el notifier), eliminando el split-brain.
    onMemoryUpdate: (m) => ref.read(objectMemoryProvider.notifier).replace(m),
    // A8: percepción orquestada real (accesibilidad vía ScreenGraph).
    perceptionMux: ref.watch(perceptionMuxProvider),
    // A2: resuelve "abre <app>" con package REAL del PackageManager.
    appLaunch: ref.watch(appLaunchResolverProvider),
    // A13.5: planificador Candidate-First de producción (0 LLM goals conocidos).
    candidateFirst: ref.watch(candidateFirstPlannerProvider),
    // A15.0: orquestador cross-app multi-paso con data flow tipado (0 LLM).
    taskPlanner: const TaskPlanner(),
    taskOrchestrator: TaskOrchestrator(
      listNotifications: () =>
          NanoRuntimeApi.instance.listActiveNotifications(),
      openUrl: (url, {confirmedActionSignature, semanticAction}) => runTaskTool(
        ToolCall(tool: 'open_url', text: url),
        confirmedActionSignature: confirmedActionSignature,
        semanticAction: semanticAction,
      ),
      writeFile: (path, content, {confirmedActionSignature, semanticAction}) =>
          runTaskTool(
            ToolCall(
              tool: 'linux.writeFile',
              text: path,
              args: {'content': content},
            ),
            confirmedActionSignature: confirmedActionSignature,
            semanticAction: semanticAction,
          ),
      // A15.4: fuentes UI (delegan al dispatcher, que ya tiene governance).
      launchApp: (appName, {confirmedActionSignature, semanticAction}) async {
        // Destino de sistema primero (Ajustes/Bluetooth/WiFi → open_system
        // allowlisted). "Ve a Ajustes y busca X" NO es launch_app: es un intent
        // oficial de sistema, no una app instalada.
        final known = defaultDeterministicCatalog.forGoal('abre $appName');
        if (known != null &&
            known.steps.length == 1 &&
            known.steps.single.tool == 'open_system') {
          final dest = known.steps.single.destinationArg;
          if (dest == null) {
            return const TaskActionResult(
              status: TaskActionStatus.failed,
              reason: 'destino de sistema sin identificador',
            );
          }
          return runTaskTool(
            ToolCall(tool: 'open_system', args: {'destination': dest}),
            confirmedActionSignature: confirmedActionSignature,
            semanticAction: semanticAction,
          );
        }
        // Resolver nombre de app → packageName real (el dispatcher launch_app
        // espera package, no nombre). Evita "whatsapp" inválido.
        final catalog = ref.read(installedAppCatalogProvider);
        final match = await catalog.findApp(appName);
        // Seguridad: ante AppMatchAmbiguous NO se elige `candidates.first` a
        // ciegas (WhatsApp vs WhatsApp Business). Solo se lanza si la resolución
        // es ÚNICA; la ambigüedad la resuelve Candidate-First (Koog) aguas
        // arriba con evidencia contextual, o se reporta sin lanzar.
        if (match is AppMatchAmbiguous) {
          final labels = match.candidates
              .map((candidate) => candidate.label)
              .toSet()
              .join(', ');
          return TaskActionResult(
            status: TaskActionStatus.failed,
            reason: 'app ambigua: $labels',
          );
        }
        if (match is! AppMatchResolved) {
          return TaskActionResult(
            status: TaskActionStatus.failed,
            reason: 'app "$appName" no encontrada en el catálogo lanzable',
          );
        }
        final pkg = match.app.packageName;
        return runTaskTool(
          ToolCall(tool: 'launch_app', args: {'packageName': pkg}),
          confirmedActionSignature: confirmedActionSignature,
          semanticAction: semanticAction,
        );
      },
      tap:
          (
            selector, {
            confirmedActionSignature,
            semanticAction,
            executionId,
            executionIntent,
          }) => runTaskTool(
            ToolCall(tool: 'tap', selector: selector),
            confirmedActionSignature: confirmedActionSignature,
            semanticAction: semanticAction,
            executionId: executionId,
            executionIntent: executionIntent,
          ),
      writeText: (selector, text, {confirmedActionSignature, semanticAction}) =>
          runTaskTool(
            ToolCall(tool: 'write', selector: selector, text: text),
            confirmedActionSignature: confirmedActionSignature,
            semanticAction: semanticAction,
          ),
      submitInput: ({expectedPackageName = ''}) async {
        final result = await NanoRuntimeApi.instance.agentSubmitFocusedInput(
          expectedPackageName: expectedPackageName,
        );
        if (result == null) {
          return const TaskActionResult(
            status: TaskActionStatus.failed,
            reason: 'canal IME no disponible',
          );
        }
        if (result['ok'] != true) {
          return TaskActionResult(
            status: TaskActionStatus.failed,
            reason: 'submit IME rechazado: ${result['code'] ?? 'UNKNOWN'}',
          );
        }
        return const TaskActionResult(
          status: TaskActionStatus.completedUnverified,
          reason: 'acción Buscar/Ir aceptada por el campo enfocado',
        );
      },
      back: ({confirmedActionSignature, semanticAction}) => runTaskTool(
        const ToolCall(tool: 'back'),
        confirmedActionSignature: confirmedActionSignature,
        semanticAction: semanticAction,
      ),
      // NAV-MAP-04: action-space universal — desplazamiento por dirección.
      swipe: (direction) => runTaskTool(
        ToolCall(tool: 'scroll', args: {'direction': direction}),
        semanticAction: 'openConversation',
      ),
      resolveAppPackage: (appReference) async {
        final match = await ref
            .read(installedAppCatalogProvider)
            .findApp(appReference);
        return match is AppMatchResolved ? match.app.packageName : null;
      },
      currentSituationSource: ref.watch(currentSituationSourceProvider),
      // La navegación orientada a objetivos puede escalar percepción cuando
      // el árbol estructural no basta. La evidencia OCR/Vision nunca se toca
      // directamente: TaskOrchestrator debe re-ligarla a un único control
      // accesible actual antes de producir una acción.
      targetPerception: (concept, packageName) => ref
          .read(perceptionMuxProvider)
          .perceive(
            PerceptionRequest(
              targetConcept: concept,
              packageName: packageName,
              minimumConfidence: 0.72,
            ),
            budget: const PerceptionBudget(
              maxAccessibilityReads: 1,
              maxOcrCalls: 1,
              maxVisionCalls: 1,
              maxFullScreenVisionCalls: 1,
            ),
            policy: const ObservationPolicy(
              allowMemory: true,
              allowAccessibility: true,
              allowOcr: true,
              allowVision: true,
              allowFullScreenVision: true,
              minimumConfidence: 0.72,
            ),
          ),
      memorySource: () => ref.read(objectMemoryProvider),
      // AUT-MEM-01: memoria de transiciones verificadas (instancia única).
      memory: ref.watch(verifiedTransitionMemoryProvider),
      // T2.0 — resolución grounded de superficies UI desde el snapshot real
      // (Accessibility → ScreenGraph). Sin superficie → null (el paso reporta
      // needsMoreEvidence, no inventa selector).
      resolveInputSurface: () async {
        final g = await currentGraph();
        if (g == null) return null;
        return const InputSurfaceResolver().resolve(g)?.selector;
      },
      resolveInputSurfaceFor: (kind) async {
        final g = await currentGraph();
        if (g == null) return null;
        final inputKind = switch (kind) {
          'message' => InputSurfaceKind.message,
          'search' => InputSurfaceKind.search,
          _ => InputSurfaceKind.any,
        };
        return const InputSurfaceResolver()
            .resolve(g, kind: inputKind)
            ?.selector;
      },
      resolveActionSurface: (kind) async {
        final g = await currentGraph();
        if (g == null) return null;
        final surface = const ActionSurfaceResolver().resolve(g, kind: kind);
        if (surface == null && kDebugMode) {
          final candidates = g.objects
              .where((object) {
                final evidence =
                    '${object.label} ${object.text} ${object.description} '
                            '${object.resourceId}'
                        .toLowerCase();
                return evidence.contains('search') ||
                    evidence.contains('buscar') ||
                    evidence.contains('busca');
              })
              .map(
                (object) =>
                    '${object.role.name}|click=${object.clickable}|'
                    'enabled=${object.enabled}|id=${object.resourceId}|'
                    'text=${object.text}|desc=${object.description}',
              );
          debugPrint(
            '[automation-surface] unresolved kind=$kind '
            'package=${g.package} truncated=${g.truncated} '
            'objects=${g.objects.length} candidates=${candidates.join(' || ')}',
          );
        }
        return surface?.selector;
      },
      // T2.9-select — resolución grounded de un resultado observado
      // (ordinal/texto) desde el ScreenGraph real, nunca coordenadas.
      resolveResult: (target) async {
        final g = await currentGraph();
        if (g == null) return null;
        return const SearchResultResolver().resolve(g, target);
      },
      // T2.9-verify — fingerprint de texto visible (PRE/POST) y conteo de
      // resultados, para verificar submit/selección observando el estado real.
      readVisibleText: () async {
        final g = await currentGraph();
        if (g == null) return null;
        return g.objects
            .where((o) => o.visible && o.text.isNotEmpty)
            .map((o) => o.text)
            .join(' | ');
      },
      detectSearchResults: () async {
        final g = await currentGraph();
        if (g == null) return null;
        return const SearchResultResolver().resolveResults(g).length;
      },
      commitGuard: CommitGuard(observe: currentGraph),
      journal: ref.watch(executionJournalProvider),
    ),
    // A15.2: descomposición template determinista + LLM validado.
    taskDecomposer: LlmTaskDecomposer(
      client: ref.read(runtimeEngineProvider.notifier).client,
      resolver: ref.watch(automationModelResolverProvider),
      ensureReady: (path) =>
          ref.read(runtimeEngineProvider.notifier).ensureReady(modelPath: path),
    ),
  );
});

/// Registro de reglas persistentes (T3.1): shared_prefs JSON. La carga es
/// asíncrona (arranque); el pipeline consulta `rules` en memoria.
final ruleRegistryProvider = Provider<RuleRegistry>((ref) {
  final registry = RuleRegistry(SharedPrefsRuleStore());
  registry.load();
  return registry;
});

/// Pipeline WhatsApp-first (T3.3): notificación → match → AutomationCoordinator.
/// El dispatcher ejecuta el goal por el MISMO coordinator (nunca un motor aparte).
final rulePipelineProvider = Provider<RulePipeline>((ref) {
  return RulePipeline(
    registry: ref.watch(ruleRegistryProvider),
    engine: const RuleEngine(),
    dispatcher: RuleDispatcher(
      (goal) => ref.read(automationCoordinatorProvider).execute(goal),
    ),
  );
});

/// Router de eventos en vivo de notificación (T3.2): EventChannel nativo →
/// RulePipeline. Arranca al leerse por primera vez (escucha de por vida).
final notificationEventRouterProvider = Provider<NotificationEventRouter>((
  ref,
) {
  final router = NotificationEventRouter(
    pipeline: ref.watch(rulePipelineProvider),
  )..start();
  ref.onDispose(router.stop);
  return router;
});
