/// A15.0 — TaskOrchestrator: ejecuta un TaskPlan paso a paso, transportando
/// TaskValues TIPADOS entre dominios.
///
/// NO es un segundo AutomationCoordinator ni un workflow engine libre. Cada paso
/// es semántico; la ejecución efectiva se delega a fuentes inyectadas (que a su
/// vez pasan por el pipeline Candidate-First + governance + verificación).
library;

import '../memory/verified_transition_memory.dart';
import '../notifications/notification_object.dart';
import '../notifications/observed_data_extractor.dart';
import '../navigation/goal_directed_navigator.dart';
import '../navigation/navigation_decision.dart';
import '../navigation/navigation_goal.dart';
import '../navigation/navigation_history.dart';
import '../navigation/navigation_transition_verifier.dart';
import '../perception/current_situation.dart';
import '../perception/mux/perception_result.dart';
import '../perception/search_result_resolver.dart';
import '../perception/semantic/nano_ui_object.dart';
import '../perception/semantic/screen_graph.dart';
import '../perception/surface_resolvers.dart';
import '../planning/generic_ui_intent_parser.dart';
import '../planning/message_intent_parser.dart';
import '../governance/action_confirmation.dart';
import '../voice/execution_cancellation.dart';
import 'automation_context.dart';
import 'automation_run.dart';
import 'commit_guard.dart';
import 'execution_journal.dart';
import 'task_plan.dart';
import 'task_step_vocabulary.dart';

part 'task_orchestrator_steps.dart';
part 'task_orchestrator_actions.dart';
part 'task_orchestrator_navigation.dart';

typedef TaskOpenUrl =
    Future<TaskActionResult> Function(
      String url, {
      String? confirmedActionSignature,
      String? semanticAction,
    });
typedef TaskWriteFile =
    Future<TaskActionResult> Function(
      String path,
      String content, {
      String? confirmedActionSignature,
      String? semanticAction,
    });
typedef TaskLaunchApp =
    Future<TaskActionResult> Function(
      String appName, {
      String? confirmedActionSignature,
      String? semanticAction,
    });
typedef TaskTap =
    Future<TaskActionResult> Function(
      String selector, {
      String? confirmedActionSignature,
      String? semanticAction,
      String? executionId,
      ExecutionJournalEntry? executionIntent,
    });
typedef TaskWriteText =
    Future<TaskActionResult> Function(
      String selector,
      String text, {
      String? confirmedActionSignature,
      String? semanticAction,
    });
typedef TaskBack =
    Future<TaskActionResult> Function({
      String? confirmedActionSignature,
      String? semanticAction,
    });
typedef TaskSwipe = Future<TaskActionResult> Function(String direction);
typedef TaskSubmitInput =
    Future<TaskActionResult> Function({String expectedPackageName});
typedef TaskResolveAppPackage = Future<String?> Function(String appReference);
typedef TaskTargetPerception =
    Future<PerceptionResult> Function(String concept, String packageName);

/// GAP-06 — steps linux.* en planes multi-paso del TaskOrchestrator.
/// [command] es el ejecutable o script; [arguments] son los args tipados
/// (ruta estructurada) o vacíos (ruta bash -c para scripts con operadores).
typedef TaskLinuxRun =
    Future<TaskActionResult> Function(
      String command,
      List<String> arguments, {
      String? cwd,
      String? confirmedActionSignature,
      String? semanticAction,
    });

bool _isCommitInFlight(ExecutionJournalStatus status) =>
    status == ExecutionJournalStatus.executing ||
    status == ExecutionJournalStatus.executed ||
    status == ExecutionJournalStatus.verifying;

class TaskOrchestrator {
  TaskOrchestrator({
    required Future<List<dynamic>> Function() listNotifications,
    required TaskOpenUrl openUrl,
    required TaskWriteFile writeFile,
    TaskLaunchApp? launchApp,
    TaskTap? tap,
    TaskWriteText? writeText,
    TaskSubmitInput? submitInput,
    TaskBack? back,
    TaskSwipe? swipe,
    // GAP-06: steps linux.* en planes multi-paso.
    TaskLinuxRun? linuxRun,
    TaskResolveAppPackage? resolveAppPackage,
    CurrentSituationSource? currentSituationSource,
    TaskTargetPerception? targetPerception,
    AutomationMemorySource? memorySource,
    VerifiedTransitionMemory? memory,
    GoalDirectedNavigator navigator = const GoalDirectedNavigator(),
    NavigationTransitionVerifier transitionVerifier =
        const NavigationTransitionVerifier(),
    Future<String?> Function()? resolveInputSurface,
    Future<String?> Function(String kind)? resolveInputSurfaceFor,
    Future<String?> Function(String kind)? resolveActionSurface,
    Future<ResultResolution?> Function(ResultTarget target)? resolveResult,
    Future<String?> Function()? readVisibleText,
    Future<int?> Function()? detectSearchResults,
    CommitGuard? commitGuard,
    ExecutionJournal? journal,
    void Function(ExecutionJournalEntry verifiedEntry)? onVerifiedStep,
    this.maxAttemptsPerStep = 2,
    this.maxReplansPerTask = 2,
  }) : _onVerifiedStep = onVerifiedStep,
       _listNotifications = listNotifications,
       _openUrl = openUrl,
       _writeFile = writeFile,
       _launchApp = launchApp,
       _tap = tap,
       _writeText = writeText,
       _submitInput = submitInput,
       _back = back,
       _swipe = swipe,
       _linuxRun = linuxRun,
       _resolveAppPackage = resolveAppPackage,
       _currentSituationSource = currentSituationSource,
       _targetPerception = targetPerception,
       _memorySource = memorySource,
       _memory = memory,
       _navigator = navigator,
       _transitionVerifier = transitionVerifier,
       _resolveInputSurfaceFor =
           resolveInputSurfaceFor ??
           (resolveInputSurface == null ? null : (_) => resolveInputSurface()),
       _resolveActionSurface = resolveActionSurface,
       _resolveResult = resolveResult,
       _readVisibleText = readVisibleText,
       _detectSearchResults = detectSearchResults,
       _commitGuard = commitGuard,
       _journal = journal;

  final Future<List<dynamic>> Function() _listNotifications;
  final TaskOpenUrl _openUrl;
  final TaskWriteFile _writeFile;

  /// A15.4 — fuentes UI (delegan al dispatcher/ScreenGraph).
  final TaskLaunchApp? _launchApp;
  final TaskTap? _tap;
  final TaskWriteText? _writeText;
  final TaskSubmitInput? _submitInput;
  final TaskBack? _back;
  final TaskSwipe? _swipe;

  /// GAP-06 — steps linux.* en planes multi-paso (ejecutable + args tipados).
  final TaskLinuxRun? _linuxRun;

  final TaskResolveAppPackage? _resolveAppPackage;
  final CurrentSituationSource? _currentSituationSource;
  final TaskTargetPerception? _targetPerception;
  final AutomationMemorySource? _memorySource;
  final VerifiedTransitionMemory? _memory;
  final GoalDirectedNavigator _navigator;
  final NavigationTransitionVerifier _transitionVerifier;

  /// Variante con intención explícita (`message`/`search`). La usan los flujos
  /// que mutan un campo para no confundir compositor y buscador.
  final Future<String?> Function(String kind)? _resolveInputSurfaceFor;
  final Future<String?> Function(String kind)? _resolveActionSurface;

  /// T2.9-select — resolución grounded de un resultado observado (ordinal/texto).
  /// null = sin fuente de resolución; el paso devuelve needsMoreEvidence.
  final Future<ResultResolution?> Function(ResultTarget target)? _resolveResult;

  /// T2.9-verify — texto visible de la pantalla (fingerprint de snapshot, para
  /// detectar cambio PRE/POST). null = sin observación → completedUnverified.
  final Future<String?> Function()? _readVisibleText;

  /// T2.9-verify — nº de resultados de búsqueda detectados en pantalla.
  /// null = sin observación.
  final Future<int?> Function()? _detectSearchResults;
  final CommitGuard? _commitGuard;
  final ExecutionJournal? _journal;

  /// Notificación post-verificación (best-effort): la usa el extractor de
  /// skills para convertir trazas VERIFICADAS en drafts. Jamás bloquea ni
  /// falla la ejecución (se invoca en try silencioso).
  final void Function(ExecutionJournalEntry verifiedEntry)? _onVerifiedStep;

  /// A15.1 — presupuesto de recuperación acotado.
  final int maxAttemptsPerStep;
  final int maxReplansPerTask;

  /// Ejecuta el plan en orden topológico con recuperación ACOTADA (A15.1).
  /// Un paso no-completado detiene los dependientes. Los pasos fallidos
  /// recuperables se reintentan hasta el presupuesto; un reintento con el MISMO
  /// motivo (sin progreso) se detiene para evitar loops.
  Future<List<TaskStepResult>> run(
    TaskPlan plan, {
    AutomationRun? run,
    ExecutionCancellationToken? cancel,
    ActionConfirmation? confirmation,
    String? executionId,
  }) async {
    final invalid = plan.validate();
    if (invalid != null) {
      return [TaskStepResult(status: TaskStepStatus.failed, reason: invalid)];
    }

    if (run != null &&
        (cancel != null || confirmation != null || executionId != null)) {
      return const [
        TaskStepResult(
          status: TaskStepStatus.failed,
          reason:
              'ownership ambiguo: AutomationRun no puede combinarse con estado legacy',
          failureKind: TaskFailureKind.terminal,
        ),
      ];
    }
    final activeRun =
        run ??
        AutomationRun(
          executionId: executionId ?? confirmation?.executionId ?? _newRunId(),
          goal: plan.goal,
          confirmation: confirmation,
          cancellation: cancel,
        );
    if (activeRun.goal != plan.goal) {
      return const [
        TaskStepResult(
          status: TaskStepStatus.failed,
          reason: 'AutomationRun y TaskPlan pertenecen a objetivos distintos',
          failureKind: TaskFailureKind.terminal,
        ),
      ];
    }
    activeRun.beginPlanning();
    final presentedConfirmation = activeRun.confirmation;

    final values = <TaskValueId, TaskValue>{};
    final results = <TaskStepResult>[];
    var replans = 0;
    final conversation = _parseGoal(plan.goal);

    final ordered = plan.ordered;
    final planSignature = _planSignature(plan, ordered);
    final runId = activeRun.executionId;
    final goalFingerprint = canonicalFingerprint(plan.goal);
    final journal = _journal;
    if (journal != null) {
      await journal.recoverInterrupted();
      // Una ejecución físicamente en curso sí bloquea otra con el mismo
      // objetivo. Un resultado histórico incierto no bloquea la planificación:
      // podrá repetirse únicamente si el nuevo run llega al commit con una
      // confirmación fresca, validada y consumida por el journal.
      final inFlight = (await journal.all()).where(
        (entry) =>
            entry.goalFingerprint == goalFingerprint &&
            entry.irreversible &&
            _isCommitInFlight(entry.status),
      );
      if (inFlight.isNotEmpty) {
        return const [
          TaskStepResult(
            status: TaskStepStatus.outcomeUnknown,
            reason:
                'existe un commit irreversible todavía en curso para este objetivo; '
                'no se inicia otra ejecución concurrente',
            failureKind: TaskFailureKind.terminal,
          ),
        ];
      }
    }
    var validConfirmation = false;
    ExecutionJournalEntry? resumedEntry;
    if (presentedConfirmation != null &&
        presentedConfirmation.executionId == runId &&
        presentedConfirmation.planSignature == planSignature &&
        presentedConfirmation.stepIndex >= 0 &&
        presentedConfirmation.stepIndex < ordered.length &&
        presentedConfirmation.stepId ==
            ordered[presentedConfirmation.stepIndex].id) {
      if (journal != null) {
        resumedEntry = await journal.consumeConfirmation(presentedConfirmation);
        validConfirmation = resumedEntry != null;
      } else {
        validConfirmation = presentedConfirmation.consumeIfAuthorizes(
          executionId: runId,
          planSignature: planSignature,
          stepIndex: presentedConfirmation.stepIndex,
          stepId: ordered[presentedConfirmation.stepIndex].id,
          actionSignature: presentedConfirmation.actionSignature,
        );
      }
    }
    if (presentedConfirmation != null && !validConfirmation) {
      return const [
        TaskStepResult(
          status: TaskStepStatus.denied,
          reason:
              'confirmación inválida, expirada, consumida o no pendiente en el journal',
          failureKind: TaskFailureKind.terminal,
        ),
      ];
    }
    if (resumedEntry != null) {
      activeRun.restoreEvidence(resumedEntry.evidenceByStep);
    }
    final startIndex = validConfirmation ? presentedConfirmation!.stepIndex : 0;
    // Al reanudar no se repiten acciones previas. Solo se reconstruyen valores
    // de pasos observacionales/puros necesarios por el paso confirmado.
    for (var index = 0; index < startIndex; index++) {
      final prior = ordered[index];
      final priorDefinition = semanticActionDefinition(prior.semanticAction)!;
      if (!priorDefinition.rebuildOnResume) {
        continue;
      }
      activeRun.enterStep(index);
      if (priorDefinition.risk != SemanticActionRisk.observation &&
          priorDefinition.risk != SemanticActionRisk.navigation) {
        activeRun.markPhysicalEffectDispatched();
      }
      final rebuiltContext = await _captureDecisionContext(
        run: activeRun,
        step: prior,
        values: values,
        conversation: conversation,
      );
      final rebuilt = await _runStep(
        prior,
        rebuiltContext,
        navigationHistory: activeRun.navigationHistory,
      );
      results.add(rebuilt);
      if (rebuilt.isFailure) return results;
      final rebuiltEvidence = rebuilt.evidence;
      if (rebuiltEvidence != null) {
        activeRun.recordEvidence(prior.id, rebuiltEvidence);
      }
      if (prior.produces != null && rebuilt.output != null) {
        values[prior.produces!] = rebuilt.output!;
      }
    }

    for (var stepIndex = startIndex; stepIndex < ordered.length; stepIndex++) {
      final step = ordered[stepIndex];
      // A16 — cancelación cooperativa: aborta ANTES del siguiente paso.
      try {
        activeRun.cancellation.throwIfCancelled();
      } on ExecutionCancelled {
        results.add(
          TaskStepResult(
            status: activeRun.hasDispatchedPhysicalEffect
                ? TaskStepStatus.needsMoreEvidence
                : TaskStepStatus.failed,
            reason: activeRun.hasDispatchedPhysicalEffect
                ? 'cancelado tras iniciar efectos físicos; resultado incierto'
                : 'cancelado por el usuario',
            failureKind: TaskFailureKind.terminal,
          ),
        );
        break;
      }
      activeRun.enterStep(stepIndex);
      var decisionContext = await _captureDecisionContext(
        run: activeRun,
        step: step,
        values: values,
        conversation: conversation,
      );
      final insufficient = _insufficientDependency(
        step,
        decisionContext.evidence,
      );
      if (insufficient != null) {
        final blocked = TaskStepResult(
          status: TaskStepStatus.needsMoreEvidence,
          reason: insufficient,
          failureKind: TaskFailureKind.terminal,
        );
        results.add(blocked);
        break;
      }
      final definition = semanticActionDefinition(step.semanticAction)!;
      if (definition.requiresContextLock && _commitGuard == null) {
        results.add(
          TaskStepResult(
            status: TaskStepStatus.needsMoreEvidence,
            reason:
                '${step.semanticAction} requiere ContextLock según la política semántica',
            failureKind: TaskFailureKind.terminal,
          ),
        );
        break;
      }
      final irreversible = definition.irreversible;
      final semanticActionSignature = _semanticActionSignature(
        planSignature: planSignature,
        step: step,
        goal: plan.goal,
      );
      final plannedEntry = ExecutionJournalEntry(
        runId: runId,
        planSignature: planSignature,
        goalFingerprint: goalFingerprint,
        currentStep: stepIndex,
        stepId: step.id,
        status: ExecutionJournalStatus.planned,
        irreversible: irreversible,
        actionSignature: semanticActionSignature,
        verificationState: 'plan validado; acción aún no iniciada',
        timestamp: DateTime.now().toUtc(),
        evidenceByStep: decisionContext.evidence,
        semanticAction: step.semanticAction,
      );
      final confirmedStep =
          validConfirmation && stepIndex == presentedConfirmation!.stepIndex;
      ExecutionJournalEntry? executionIntent;
      if (irreversible) {
        if (journal == null) {
          results.add(
            const TaskStepResult(
              status: TaskStepStatus.denied,
              reason:
                  'acción irreversible bloqueada: no hay journal durable disponible',
              failureKind: TaskFailureKind.terminal,
            ),
          );
          break;
        }
        try {
          if (confirmedStep) {
            executionIntent = resumedEntry;
          } else {
            await journal.save(plannedEntry);
            if (!definition.requiresConfirmation) {
              executionIntent = plannedEntry.copyWith(
                status: ExecutionJournalStatus.authorized,
                verificationState:
                    'política satisfecha; acción aún no iniciada',
                timestamp: DateTime.now().toUtc(),
              );
              await journal.save(executionIntent);
            }
          }
          if (confirmedStep && executionIntent == null) {
            results.add(
              const TaskStepResult(
                status: TaskStepStatus.denied,
                reason:
                    'la confirmación no produjo una intención durable autorizada',
                failureKind: TaskFailureKind.terminal,
              ),
            );
            break;
          }
        } on Object catch (error) {
          results.add(
            TaskStepResult(
              status: TaskStepStatus.denied,
              reason:
                  'acción irreversible bloqueada antes de ejecutar: journal no disponible ($error)',
              failureKind: TaskFailureKind.terminal,
            ),
          );
          break;
        }
      } else {
        await journal?.save(plannedEntry);
      }
      final decisionJournal = executionIntent ?? plannedEntry;
      decisionContext = decisionContext.withExecution(
        AutomationExecutionSnapshot.fromRun(
          activeRun,
          journalEntry: decisionJournal,
        ),
        capturedAt: DateTime.now().toUtc(),
      );
      if (definition.risk != SemanticActionRisk.observation &&
          definition.risk != SemanticActionRisk.navigation) {
        activeRun.markPhysicalEffectDispatched();
      }
      var result = await _runStep(
        step,
        decisionContext,
        navigationHistory: activeRun.navigationHistory,
        executionIntent: executionIntent,
        confirmedActionSignature: confirmedStep
            ? presentedConfirmation.actionSignature
            : null,
      );
      if (result.status == TaskStepStatus.needsConfirmation &&
          result.pendingActionSignature != null) {
        result = TaskStepResult(
          status: result.status,
          reason: result.reason,
          failureKind: result.failureKind,
          pendingActionSignature: result.pendingActionSignature,
          confirmation: ActionConfirmation(
            executionId: runId,
            planSignature: planSignature,
            stepIndex: stepIndex,
            stepId: step.id,
            actionSignature: result.pendingActionSignature!,
          ),
        );
        activeRun.waitForConfirmation(result.confirmation!);
      }
      var attempts = 1;
      final navigationStep = step.semanticAction == 'openConversation';
      final attemptLimit = navigationStep
          ? activeRun.navigationHistory.budget.maxNavigationSteps + 1
          : maxAttemptsPerStep;

      while (!result.isCompleted &&
          result.isRecoverable &&
          definition.replayPolicy == SemanticReplayPolicy.safeReplace &&
          attempts < attemptLimit &&
          (navigationStep || replans < maxReplansPerTask)) {
        try {
          activeRun.cancellation.throwIfCancelled();
        } on ExecutionCancelled {
          result = const TaskStepResult(
            status: TaskStepStatus.failed,
            reason: 'cancelado por el usuario durante recuperación',
            failureKind: TaskFailureKind.terminal,
          );
          break;
        }
        if (!navigationStep) replans++;
        attempts++;
        final retryContext = await _captureDecisionContext(
          run: activeRun,
          step: step,
          values: values,
          conversation: conversation,
          journalEntry: decisionJournal,
        );
        final next = await _runStep(
          step,
          retryContext,
          navigationHistory: activeRun.navigationHistory,
        );
        // Los pasos no navegacionales conservan el guard previo. Navegación
        // usa firmas de situación observada en NavigationHistory.
        if (!navigationStep &&
            next.reason == result.reason &&
            !next.isCompleted) {
          result = next;
          break;
        }
        result = next;
      }

      final finalEvidence = result.evidence;
      if (finalEvidence != null) {
        activeRun.recordEvidence(step.id, finalEvidence);
      }
      if (result.status != TaskStepStatus.needsConfirmation) {
        activeRun.beginVerification();
      }
      final finalEntry = ExecutionJournalEntry(
        runId: runId,
        planSignature: planSignature,
        goalFingerprint: goalFingerprint,
        currentStep: stepIndex,
        stepId: step.id,
        status: _journalStatus(result.status),
        irreversible: irreversible,
        actionSignature: semanticActionSignature,
        verificationState: result.reason,
        timestamp: DateTime.now().toUtc(),
        pendingConfirmation: result.confirmation,
        evidenceByStep: activeRun.evidenceSnapshot,
        semanticAction: step.semanticAction,
      );
      try {
        await journal?.save(finalEntry);
      } on Object catch (error) {
        if (!irreversible) rethrow;
        result = TaskStepResult(
          status: TaskStepStatus.outcomeUnknown,
          reason:
              'la acción pudo ejecutarse, pero no se pudo cerrar el journal ($error); no debe repetirse',
          failureKind: TaskFailureKind.terminal,
        );
      }
      results.add(result);
      if (result.isFailure) break;

      // SKILL-01 — notificar la traza VERIFICADA (best-effort): el extractor
      // la convierte en draft de skill. Nunca interfiere con la ejecución:
      // cualquier fallo del collector se traga aquí.
      final verifiedHook = _onVerifiedStep;
      if (verifiedHook != null &&
          finalEntry.status == ExecutionJournalStatus.verified) {
        try {
          verifiedHook(finalEntry);
        } on Object {
          // Best-effort: la recolección de skills jamás falla la tarea.
        }
      }

      if (step.produces != null && result.output != null) {
        values[step.produces!] = result.output!;
      }
    }
    return results;
  }

  Future<AutomationContext> _captureDecisionContext({
    required AutomationRun run,
    required TaskStep step,
    required Map<TaskValueId, TaskValue> values,
    required AutomationConversationSnapshot conversation,
    ExecutionJournalEntry? journalEntry,
  }) async {
    var notifications = const <NotificationObject>[];
    String? notificationFailure;
    final needsNotifications =
        step.semanticAction == 'readNotification' ||
        ((step.semanticAction == 'openApp' ||
                step.semanticAction == 'openConversation') &&
            conversation.appName.isEmpty &&
            conversation.target.isNotEmpty);
    if (needsNotifications) {
      try {
        notifications = [
          for (final map in (await _listNotifications()).whereType<Map>())
            NotificationObject.fromMap(map.cast<dynamic, dynamic>()),
        ];
      } on Object catch (error) {
        notificationFailure = 'no se pudieron leer notificaciones: $error';
      }
    }

    AutomationPerceptionSnapshot perception =
        const AutomationPerceptionSnapshot.notRequired();
    final needsStructuralSituation =
        step.semanticAction == 'openConversation' ||
        step.semanticAction == 'activateElement' ||
        step.semanticAction == 'fillElement';
    if (needsStructuralSituation) {
      final observe = _currentSituationSource;
      if (observe == null) {
        perception = const AutomationPerceptionSnapshot.unavailable(
          'sin fuente de situación actual para navegar',
        );
      } else {
        try {
          final situation = await observe();
          if (situation == null ||
              !situation.hasStructuralEvidence ||
              situation.packageName.isEmpty) {
            perception = const AutomationPerceptionSnapshot.unavailable(
              'situación actual ausente o sin evidencia estructural',
            );
          } else {
            perception = AutomationPerceptionSnapshot.observed(situation);
          }
        } on Object catch (error) {
          perception = AutomationPerceptionSnapshot.unavailable(
            'no se pudo observar la situación actual: $error',
          );
        }
      }
    }

    final memory = _memorySource?.call();
    final targetConcept = conversation.target.isNotEmpty
        ? conversation.target
        : conversation.query.isNotEmpty
        ? conversation.query
        : conversation.uiActionTarget.isNotEmpty
        ? conversation.uiActionTarget
        : conversation.uiTarget.isNotEmpty
        ? conversation.uiTarget
        : conversation.appName;
    return AutomationContext(
      goal: run.goal,
      decisionStepId: step.id,
      execution: AutomationExecutionSnapshot.fromRun(
        run,
        journalEntry: journalEntry,
      ),
      world: AutomationWorldSnapshot(
        values,
        notifications: notifications,
        notificationFailure: notificationFailure,
      ),
      perception: perception,
      conversation: conversation,
      relevantMemory: memory == null
          ? null
          : RelevantAutomationMemory(
              objectMemory: memory,
              targetConcept: targetConcept,
              packageName: perception.situation?.packageName ?? '',
            ),
      evidence: run.evidenceSnapshot,
      capturedAt: DateTime.now().toUtc(),
    );
  }

  String? _insufficientDependency(
    TaskStep step,
    Map<String, RequiredEvidence> evidenceByStep,
  ) {
    for (final dependency in step.dependencies) {
      final required = step.evidenceRequiredFrom(dependency);
      final actual = evidenceByStep[dependency];
      if (actual == null ||
          (required == RequiredEvidence.verified &&
              actual != RequiredEvidence.verified)) {
        return 'La dependencia "$dependency" no aporta evidencia '
            '${required.name}; se bloquea ${step.semanticAction}.';
      }
    }
    return null;
  }

  static int _runSequence = 0;
  static String _newRunId() =>
      'task-${DateTime.now().microsecondsSinceEpoch}-${++_runSequence}';

  String _semanticActionSignature({
    required String planSignature,
    required TaskStep step,
    required String goal,
  }) => canonicalFingerprint({
    'plan': planSignature,
    'step': step.id,
    'action': step.semanticAction,
    'goal': goal,
  });

  ExecutionJournalStatus _journalStatus(TaskStepStatus status) =>
      switch (status) {
        TaskStepStatus.completed => ExecutionJournalStatus.verified,
        TaskStepStatus.completedUnverified =>
          ExecutionJournalStatus.completedUnverified,
        TaskStepStatus.needsConfirmation =>
          ExecutionJournalStatus.waitingConfirmation,
        TaskStepStatus.outcomeUnknown => ExecutionJournalStatus.outcomeUnknown,
        TaskStepStatus.denied => ExecutionJournalStatus.cancelled,
        TaskStepStatus.needsMoreEvidence ||
        TaskStepStatus.failed => ExecutionJournalStatus.failed,
      };
}
