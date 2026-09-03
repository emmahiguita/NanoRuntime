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
typedef TaskSwipe =
    Future<TaskActionResult> Function(String direction);
typedef TaskSubmitInput =
    Future<TaskActionResult> Function({String expectedPackageName});
typedef TaskResolveAppPackage = Future<String?> Function(String appReference);
typedef TaskTargetPerception =
    Future<PerceptionResult> Function(String concept, String packageName);

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
          const TaskStepResult(
            status: TaskStepStatus.failed,
            reason: 'cancelado por el usuario',
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

  Future<TaskStepResult> _runStep(
    TaskStep step,
    AutomationContext context, {
    required NavigationHistory navigationHistory,
    String? confirmedActionSignature,
    ExecutionJournalEntry? executionIntent,
  }) async {
    final values = context.world.values;
    final goal = context.conversation;
    switch (step.semanticAction) {
      case 'readNotification':
        return _readNotification(context);
      case 'extractUrl':
        return _extractUrl(step, values);
      case 'writeFile':
        return _writeFileStep(
          step,
          values,
          confirmedActionSignature: confirmedActionSignature,
        );
      case 'openUrl':
        return _openUrlStep(
          step,
          values,
          confirmedActionSignature: confirmedActionSignature,
        );
      case 'openApp':
        return _openApp(
          context,
          goal,
          confirmedActionSignature: confirmedActionSignature,
        );
      case 'openConversation':
        return _openConversation(
          context,
          goal,
          navigationHistory: navigationHistory,
          executionId: context.execution.executionId,
          confirmedActionSignature: confirmedActionSignature,
        );
      case 'activateElement':
        return _activateElement(
          context,
          goal,
          executionIntent: executionIntent,
          confirmedActionSignature: confirmedActionSignature,
        );
      case 'fillElement':
        return _fillElement(
          context,
          goal,
          confirmedActionSignature: confirmedActionSignature,
        );
      case 'writeMessage':
        return _writeMessage(
          goal,
          confirmedActionSignature: confirmedActionSignature,
        );
      case 'sendMessage':
        return _sendMessage(
          goal,
          executionId: context.execution.executionId,
          confirmedActionSignature: confirmedActionSignature,
          executionIntent: executionIntent,
        );
      case 'writeQuery':
        return _writeQuery(
          goal,
          executionId: context.execution.executionId,
          confirmedActionSignature: confirmedActionSignature,
        );
      case 'submitSearch':
        return _submitSearch(
          goal,
          executionId: context.execution.executionId,
          confirmedActionSignature: confirmedActionSignature,
        );
      case 'selectResult':
        return _selectResult(
          goal,
          executionId: context.execution.executionId,
          confirmedActionSignature: confirmedActionSignature,
        );
      default:
        return const TaskStepResult(
          status: TaskStepStatus.needsMoreEvidence,
          reason: 'semántica desconocida',
        );
    }
  }

  TaskStepResult _readNotification(AutomationContext context) {
    final failure = context.world.notificationFailure;
    if (failure != null) {
      return TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: failure,
        failureKind: TaskFailureKind.terminal,
      );
    }
    final notifications = context.world.notifications;
    if (notifications.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin notificaciones activas',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final first = notifications.first;
    final text = first.messageText.isNotEmpty ? first.messageText : first.text;
    return TaskStepResult(
      status: TaskStepStatus.completed,
      reason: 'notificación más reciente leída',
      output: TextValue(text),
    );
  }

  TaskStepResult _extractUrl(
    TaskStep step,
    Map<TaskValueId, TaskValue> values,
  ) {
    final binding = step.inputBindings['text'];
    final source = binding == null ? null : values[binding.source];
    if (source is! TextValue || source.text.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin texto fuente para extraer URL',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final data = const ObservedDataExtractor().extract(source.text);
    final url = data.primary;
    if (url == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'no se encontró URL en el texto observado',
        failureKind: TaskFailureKind.terminal,
      );
    }
    return TaskStepResult(
      status: TaskStepStatus.completed,
      reason: 'URL extraída',
      output: UrlValue(url),
    );
  }

  Future<TaskStepResult> _writeFileStep(
    TaskStep step,
    Map<TaskValueId, TaskValue> values, {
    String? confirmedActionSignature,
  }) async {
    final binding = step.inputBindings['content'];
    final value = binding == null ? null : values[binding.source];
    if (value is! UrlValue) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin URL para escribir',
      );
    }
    const path = '/root/nano_observed_link.txt';
    final action = await _writeFile(
      path,
      value.url,
      confirmedActionSignature: confirmedActionSignature,
      semanticAction: 'writeFile',
    );
    return _stepFromAction(
      action,
      completedReason: 'URL escrita a archivo',
      output: const FilePathValue(path),
      recoverable: true,
    );
  }

  Future<TaskStepResult> _openUrlStep(
    TaskStep step,
    Map<TaskValueId, TaskValue> values, {
    String? confirmedActionSignature,
  }) async {
    final binding = step.inputBindings['url'];
    final value = binding == null ? null : values[binding.source];
    if (value is! UrlValue) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin URL para abrir',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final action = await _openUrl(
      value.url,
      confirmedActionSignature: confirmedActionSignature,
      semanticAction: 'openUrl',
    );
    return _stepFromAction(
      action,
      completedReason: 'URL abierta',
      recoverable: true,
    );
  }

  // ── A15.4 — pasos UI (delegan al dispatcher/ScreenGraph) ──────────────────

  Future<TaskStepResult> _openApp(
    AutomationContext context,
    AutomationConversationSnapshot goal, {
    String? confirmedActionSignature,
  }) async {
    // T2.8: si el objetivo no nombra la app ("escríbele a Juan"), derivarla de
    // la notificación activa cuyo sender/conversación matchea el target. El
    // package sale de la evidencia real, nunca se inventa. Sin app derivable →
    // needsMoreEvidence honesto (el humano/planner aclara en qué app).
    final notificationFailure = context.world.notificationFailure;
    if (goal.appName.isEmpty && notificationFailure != null) {
      return TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: notificationFailure,
        failureKind: TaskFailureKind.terminal,
      );
    }
    final app = _resolveMessagingApp(context, goal);
    if (app == null || app.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin app en el objetivo ni en notificaciones',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final launch = _launchApp;
    if (launch == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin fuente de launch',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final action = await launch(
      app,
      confirmedActionSignature: confirmedActionSignature,
      semanticAction: 'openApp',
    );
    return _stepFromAction(
      action,
      completedReason: 'app abierta',
      recoverable: true,
    );
  }

  /// Deriva la app de mensajería a abrir: el nombre explícito del objetivo si
  /// existe; si no, el packageName de la notificación activa que matchea el
  /// target (sender/conversationTitle/title). null = sin evidencia.
  String? _resolveMessagingApp(
    AutomationContext context,
    AutomationConversationSnapshot goal,
  ) {
    if (goal.appName.isNotEmpty) return goal.appName;
    if (goal.target.isEmpty) return null;

    for (final n in context.world.notifications) {
      if (n.packageName.isEmpty) continue;
      if (n.matchesRecipient(goal.target)) return n.packageName;
    }
    return null;
  }

  Future<TaskStepResult> _openConversation(
    AutomationContext context,
    AutomationConversationSnapshot goal, {
    required NavigationHistory navigationHistory,
    required String executionId,
    String? confirmedActionSignature,
  }) async {
    if (goal.target.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin conversación objetivo',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final resolveAppPackage = _resolveAppPackage;
    if (resolveAppPackage == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin catálogo para resolver el paquete de navegación',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final String? appReference;
    final notificationFailure = context.world.notificationFailure;
    if (goal.appName.isEmpty && notificationFailure != null) {
      return TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: notificationFailure,
        failureKind: TaskFailureKind.terminal,
      );
    }
    appReference = _resolveMessagingApp(context, goal);
    if (appReference == null || appReference.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin app grounded para la conversación objetivo',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final String? targetPackage;
    try {
      targetPackage = await resolveAppPackage(appReference);
    } on Object catch (error) {
      return TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'no se pudo resolver el paquete objetivo: $error',
        failureKind: TaskFailureKind.terminal,
      );
    }
    if (targetPackage == null || targetPackage.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'app objetivo ausente o ambigua en el catálogo instalado',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final current = context.perception.situation;
    if (!context.perception.isObserved || current == null) {
      return TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason:
            context.perception.reason ??
            'situación actual ausente o sin evidencia estructural',
        failureKind: TaskFailureKind.terminal,
      );
    }

    final navigationGoal = NavigationGoal(
      targetPackage: targetPackage,
      targetSurface: CurrentSurfaceKind.editable,
      targetEntity: goal.target,
    );
    var decision = _navigator.decide(
      current,
      navigationGoal,
      memory: _memory,
    );
    if (decision.status == NavigationDecisionStatus.needsMoreEvidence &&
        decision.permitsPerceptionEscalation) {
      final perceived = await _perceivedNavigationDecision(
        current,
        navigationGoal,
        decision,
      );
      if (perceived != null) decision = perceived;
    }
    final transition = _transitionVerifier.verify(
      history: navigationHistory,
      current: current,
      goal: navigationGoal,
      decision: decision,
    );
    // AUT-MEM-01: una transición VERIFICADA por la reobservación (cambio real
    // o meta alcanzada) se aprende. La memoria solo registra lo confirmado;
    // el no-progreso (unchanged) nunca se aprende.
    final previousEntry = navigationHistory.lastEntry;
    final memory = _memory;
    if (memory != null &&
        previousEntry != null &&
        (transition.status == NavigationTransitionStatus.changed ||
            transition.status == NavigationTransitionStatus.goalReached)) {
      memory.record(
        packageName: current.packageName,
        fromSurface: previousEntry.fromSurface,
        action: previousEntry.actionKind,
        resultingSurface: current.surfaceKind,
      );
    }
    final progress = navigationHistory.assess(
      situation: current,
      goal: navigationGoal,
      decision: decision,
      transitionUnchanged: transition.isUnchanged,
    );
    if (!progress.mayAct) {
      return TaskStepResult(
        status: TaskStepStatus.failed,
        reason: progress.reason,
        failureKind: TaskFailureKind.terminal,
      );
    }
    switch (decision.status) {
      case NavigationDecisionStatus.arrived:
        return TaskStepResult(
          status: TaskStepStatus.completed,
          reason: '${decision.reason}; ${transition.reason}',
        );
      case NavigationDecisionStatus.needsMoreEvidence:
        return TaskStepResult(
          status: TaskStepStatus.needsMoreEvidence,
          reason: '${decision.reason}; ${transition.reason}',
          failureKind: TaskFailureKind.terminal,
        );
      case NavigationDecisionStatus.act:
        return _executeNavigationDecision(
          decision,
          current: current,
          goal: navigationGoal,
          navigationHistory: navigationHistory,
          executionId: executionId,
          confirmedActionSignature: confirmedActionSignature,
        );
    }
  }

  /// Escalado visual acotado para navegación. Solo entra cuando el navegador
  /// estructural no pudo decidir. Accessibility → OCR → Vision pueden aportar
  /// evidencia, pero el resultado únicamente se convierte en acción si puede
  /// ligarse de nuevo a UN control accesible clicable de la situación actual.
  /// Nunca se toca una coordenada inferida ni se cambia el objetivo.
  Future<NavigationDecision?> _perceivedNavigationDecision(
    CurrentSituation current,
    NavigationGoal goal,
    NavigationDecision fallback,
  ) async {
    final perceive = _targetPerception;
    if (perceive == null || current.packageName != goal.targetPackage) {
      return null;
    }

    final concepts = _perceptionConcepts(current, goal);
    for (final concept in concepts) {
      final result = await perceive(concept, goal.targetPackage);
      if (result is! PerceptionResolved || result.confidence < 0.72) continue;
      final grounded = _groundPerceivedObject(
        current.structuralEvidence,
        result.object,
      );
      if (grounded == null ||
          grounded.editable ||
          grounded.isEditableRole ||
          _selectedInChain(current.structuralEvidence, grounded)) {
        continue;
      }
      final selector = _selectorForPerceivedObject(
        current.structuralEvidence,
        grounded,
      );
      if (selector == null) continue;
      final source = result.evidence.isEmpty
          ? 'percepción'
          : result.evidence.last.source.name;
      return NavigationDecision.act(
        diff: fallback.diff,
        action: NavigationAction.tap(selector),
        reason: 'destino "$concept" observado por $source y revalidado',
      );
    }
    return null;
  }

  /// El escalado caro no prueba una lista universal de palabras. Primero usa
  /// destinos que ya tienen alguna evidencia visible en el snapshot y luego
  /// el objetivo. Queda limitado a tres observaciones por decisión fallida.
  List<String> _perceptionConcepts(
    CurrentSituation current,
    NavigationGoal goal,
  ) {
    const conversationTerms = {
      'chats',
      'mensajes',
      'conversaciones',
      'messages',
      'conversations',
    };
    const searchTerms = {'buscar', 'busca', 'search', 'find'};
    String? conversationConcept;
    String? searchConcept;

    for (final object in current.structuralEvidence.objects) {
      if (!object.visible) continue;
      for (final raw in [object.description, object.text, object.label]) {
        final value = raw.trim();
        if (value.isEmpty) continue;
        final normalized = value.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
        final firstSegment = normalized.split(RegExp(r'[,;|•·]')).first.trim();
        if (conversationConcept == null &&
            (conversationTerms.contains(normalized) ||
                conversationTerms.contains(firstSegment))) {
          conversationConcept = value;
        }
        if (searchConcept == null &&
            (searchTerms.contains(normalized) ||
                searchTerms.contains(firstSegment))) {
          searchConcept = value;
        }
      }
    }

    final concepts = <String>{
      if (conversationConcept != null) conversationConcept,
      if (goal.targetEntity case final entity?) entity,
      if (searchConcept != null) searchConcept,
    };
    return List.unmodifiable(concepts.take(3));
  }

  NanoUiObject? _groundPerceivedObject(
    ScreenGraph graph,
    NanoUiObject perceived,
  ) {
    NanoUiObject? observed;
    if (perceived.sourceIndex >= 0) {
      for (final object in graph.objects) {
        if (object.sourceIndex == perceived.sourceIndex &&
            object.windowId == perceived.windowId &&
            object.bounds.left == perceived.bounds.left &&
            object.bounds.top == perceived.bounds.top &&
            object.bounds.right == perceived.bounds.right &&
            object.bounds.bottom == perceived.bounds.bottom) {
          observed = object;
          break;
        }
      }
    } else {
      // OCR/Vision produce un objeto virtual. Se usa solo para encontrar la
      // región correspondiente en el ScreenGraph, nunca como target directo.
      final x = perceived.bounds.centerX;
      final y = perceived.bounds.centerY;
      final spatial =
          graph.objects
              .where((object) {
                final bounds = object.bounds;
                return object.visible &&
                    object.enabled &&
                    bounds.left <= x &&
                    x <= bounds.right &&
                    bounds.top <= y &&
                    y <= bounds.bottom;
              })
              .toList(growable: false)
            ..sort((a, b) {
              final aArea = a.bounds.width * a.bounds.height;
              final bArea = b.bounds.width * b.bounds.height;
              return aArea.compareTo(bArea);
            });
      final byTapTarget = <String, NanoUiObject>{};
      for (final anchor in spatial) {
        final target = _clickableTarget(graph, anchor);
        if (target != null) byTapTarget.putIfAbsent(target.id, () => anchor);
      }
      if (byTapTarget.length == 1) observed = byTapTarget.values.single;
    }
    if (observed == null) return null;
    return _clickableTarget(graph, observed) == null ? null : observed;
  }

  NanoUiObject? _clickableTarget(ScreenGraph graph, NanoUiObject anchor) {
    var current = anchor;
    for (var depth = 0; depth < 6; depth++) {
      if (current.visible && current.enabled && current.clickable) {
        return current;
      }
      final parent = graph.parentOf(current.id);
      if (parent == null) return null;
      current = parent;
    }
    return null;
  }

  String? _selectorForPerceivedObject(ScreenGraph graph, NanoUiObject anchor) {
    final target = _clickableTarget(graph, anchor);
    if (target == null) return null;
    (String, String)? semantic;
    for (final identity in <(String, String)>[
      ('desc', anchor.description),
      ('text', anchor.text),
      ('desc', target.description),
      ('text', target.text),
    ]) {
      final value = identity.$2.trim();
      if (value.isEmpty || value.contains(';')) continue;
      semantic = identity;
      break;
    }

    final resource = anchor.resourceId.isNotEmpty
        ? anchor.resourceId
        : target.resourceId;
    final resourceUnique =
        resource.isNotEmpty &&
        !resource.contains(';') &&
        graph.objects
                .where(
                  (object) =>
                      object.visible &&
                      object.enabled &&
                      object.resourceId == resource,
                )
                .length ==
            1;
    if (semantic == null && !resourceUnique) return null;

    return <String>[
      if (target.packageName.isNotEmpty) 'pkg=${target.packageName}',
      // Un id compartido puede conservarse como ancla secundaria solo cuando
      // el texto/desc exacto lo desambigua. Sin evidencia semántica se exige
      // que el id sea único en el snapshot.
      if (resource.isNotEmpty && !resource.contains(';')) 'id=$resource',
      if (semantic != null) '${semantic.$1}=${semantic.$2.trim()}',
      'editable=false',
    ].join(';');
  }

  bool _selectedInChain(ScreenGraph graph, NanoUiObject anchor) {
    var current = anchor;
    for (var depth = 0; depth < 6; depth++) {
      if (current.selected || current.checked) return true;
      final parent = graph.parentOf(current.id);
      if (parent == null) return false;
      current = parent;
    }
    return false;
  }

  Future<TaskStepResult> _executeNavigationDecision(
    NavigationDecision decision, {
    required CurrentSituation current,
    required NavigationGoal goal,
    required NavigationHistory navigationHistory,
    required String executionId,
    String? confirmedActionSignature,
  }) async {
    final action = decision.action!;
    final TaskActionResult result;
    switch (action.kind) {
      case NavigationActionKind.launchPackage:
        final launch = _launchApp;
        if (launch == null) {
          return const TaskStepResult(
            status: TaskStepStatus.needsMoreEvidence,
            reason: 'sin fuente para abrir el paquete decidido',
            failureKind: TaskFailureKind.terminal,
          );
        }
        result = await launch(
          action.packageName!,
          confirmedActionSignature: confirmedActionSignature,
          semanticAction: 'openConversation',
        );
      case NavigationActionKind.tap:
        final tap = _tap;
        if (tap == null) {
          return const TaskStepResult(
            status: TaskStepStatus.needsMoreEvidence,
            reason: 'sin fuente de tap para la decisión de navegación',
            failureKind: TaskFailureKind.terminal,
          );
        }
        result = await tap(
          action.selector!,
          confirmedActionSignature: confirmedActionSignature,
          semanticAction: 'openConversation',
          executionId: executionId,
        );
      case NavigationActionKind.write:
        final write = _writeText;
        if (write == null) {
          return const TaskStepResult(
            status: TaskStepStatus.needsMoreEvidence,
            reason: 'sin fuente de escritura para la decisión de navegación',
            failureKind: TaskFailureKind.terminal,
          );
        }
        result = await write(
          action.selector!,
          action.text!,
          confirmedActionSignature: confirmedActionSignature,
          semanticAction: 'openConversation',
        );
      case NavigationActionKind.back:
        final back = _back;
        if (back == null) {
          return const TaskStepResult(
            status: TaskStepStatus.needsMoreEvidence,
            reason: 'sin fuente de back para la decisión de navegación',
            failureKind: TaskFailureKind.terminal,
          );
        }
        result = await back(
          confirmedActionSignature: confirmedActionSignature,
          semanticAction: 'openConversation',
        );
      case NavigationActionKind.scroll:
        final swipe = _swipe;
        if (swipe == null) {
          return const TaskStepResult(
            status: TaskStepStatus.needsMoreEvidence,
            reason: 'sin fuente de desplazamiento para la decisión',
            failureKind: TaskFailureKind.terminal,
          );
        }
        result = await swipe(
          action.scrollDirection == ScrollDirection.up ? 'up' : 'down',
        );
    }

    // El presupuesto de navegación solo cuenta acciones que realmente fueron
    // aceptadas por el adaptador. Un selector ambiguo/notFound devuelve
    // `failed`: registrarlo como gesto intentado falseaba el stuck detector y
    // detenía la recuperación aunque ningún tap hubiera salido al dispositivo.
    if (result.status == TaskActionStatus.completed ||
        result.status == TaskActionStatus.completedUnverified ||
        result.status == TaskActionStatus.outcomeUnknown) {
      navigationHistory.recordAttempted(
        situation: current,
        goal: goal,
        decision: decision,
      );
    }

    if (result.status == TaskActionStatus.completed) {
      return TaskStepResult(
        status: TaskStepStatus.failed,
        reason:
            '${decision.reason}; acción ejecutada, requiere nueva observación',
        failureKind: TaskFailureKind.recoverable,
      );
    }
    if (result.status == TaskActionStatus.completedUnverified) {
      return TaskStepResult(
        status: TaskStepStatus.outcomeUnknown,
        reason:
            '${decision.reason}; la acción fue despachada sin transición verificable',
        failureKind: TaskFailureKind.terminal,
      );
    }
    return _stepFromAction(
      result,
      completedReason: 'decisión de navegación ejecutada',
      recoverable: true,
    );
  }

  Future<TaskStepResult> _writeMessage(
    AutomationConversationSnapshot goal, {
    String? confirmedActionSignature,
  }) async {
    if (goal.draft.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin borrador de mensaje',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final resolve = _resolveInputSurfaceFor;
    final write = _writeText;
    if (resolve == null || write == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin fuente de escritura/observación de pantalla',
        failureKind: TaskFailureKind.terminal,
      );
    }
    // Resolver el compositor REAL en lugar de escribir en un selector vacío.
    final selector = await resolve('message');
    if (selector == null || selector.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin superficie de entrada editable visible',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final action = await write(
      selector,
      goal.draft,
      confirmedActionSignature: confirmedActionSignature,
      semanticAction: 'writeMessage',
    );
    return _stepFromAction(
      action,
      completedReason: 'mensaje escrito en superficie editable',
      recoverable: true,
    );
  }

  Future<TaskStepResult> _activateElement(
    AutomationContext context,
    AutomationConversationSnapshot goal, {
    String? confirmedActionSignature,
    ExecutionJournalEntry? executionIntent,
  }) async {
    final actionTarget = goal.uiActionTarget.isNotEmpty
        ? goal.uiActionTarget
        : goal.uiTarget;
    if (actionTarget.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin elemento UI objetivo en la orden',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final situation = context.perception.situation;
    if (!context.perception.isObserved || situation == null) {
      return TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason:
            context.perception.reason ??
            'sin situación estructural para resolver el elemento',
        failureKind: TaskFailureKind.terminal,
      );
    }
    var candidates = const EntityActionSurfaceResolver().resolve(
      situation.structuralEvidence,
      actionTarget,
    );
    String? perceptionSource;
    if (candidates.isEmpty) {
      final perceived = await _perceivedActionSurface(situation, actionTarget);
      if (perceived != null) {
        candidates = [perceived.$1];
        perceptionSource = perceived.$2;
      }
    }
    final tap = _tap;
    if (tap == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin fuente de interacción UI',
        failureKind: TaskFailureKind.terminal,
      );
    }

    // Un target de menú no existe en el árbol hasta abrir el overflow. Se
    // permite revelar UNA única superficie transitoria observada, se vuelve a
    // capturar el estado y recién entonces se resuelve el target final. El tap
    // de reveal usa política de navegación; nunca consume ni sustituye la
    // confirmación requerida por activateElement.
    if (candidates.isEmpty) {
      final overflow = const ActionSurfaceResolver().resolve(
        situation.structuralEvidence,
        kind: 'overflow',
      );
      final observe = _currentSituationSource;
      if (overflow != null && observe != null) {
        final revealed = await tap(
          overflow.selector,
          semanticAction: 'revealElement',
          executionId: context.execution.executionId,
        );
        if (!revealed.completed) {
          return _stepFromAction(
            revealed,
            completedReason: 'menú transitorio revelado',
            recoverable: false,
          );
        }
        final refreshed = await observe();
        if (refreshed != null &&
            refreshed.packageName == situation.packageName &&
            refreshed.hasStructuralEvidence) {
          candidates = const EntityActionSurfaceResolver().resolve(
            refreshed.structuralEvidence,
            actionTarget,
          );
          if (candidates.isEmpty) {
            final perceived = await _perceivedActionSurface(
              refreshed,
              actionTarget,
            );
            if (perceived != null) {
              candidates = [perceived.$1];
              perceptionSource = perceived.$2;
            }
          }
        }
      }
    }
    if (candidates.isEmpty) {
      return TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'elemento "$actionTarget" no visible o no accionable',
        failureKind: TaskFailureKind.terminal,
      );
    }
    if (candidates.length != 1) {
      return TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason:
            'elemento "$actionTarget" ambiguo: '
            '${candidates.length} destinos accionables',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final action = await tap(
      candidates.single.selector,
      confirmedActionSignature: confirmedActionSignature,
      semanticAction: 'activateElement',
      executionId: context.execution.executionId,
      executionIntent: executionIntent,
    );
    return _stepFromAction(
      action,
      completedReason:
          'elemento "$actionTarget" activado con transición verificada'
          '${perceptionSource == null ? '' : ' ($perceptionSource)'}',
      recoverable: false,
    );
  }

  /// Escalado visual para una acción genérica. Comparte exactamente la misma
  /// regla de seguridad de navegación: OCR/Vision solo aportan evidencia; el
  /// target final debe existir como un único control accesible clicable en el
  /// ScreenGraph capturado por el owner de la decisión.
  Future<(ResolvedSurface, String)?> _perceivedActionSurface(
    CurrentSituation situation,
    String concept,
  ) async {
    final perceive = _targetPerception;
    if (perceive == null || situation.packageName.isEmpty) return null;
    final result = await perceive(concept, situation.packageName);
    if (result is! PerceptionResolved || result.confidence < 0.72) return null;
    final grounded = _groundPerceivedObject(
      situation.structuralEvidence,
      result.object,
    );
    if (grounded == null ||
        grounded.editable ||
        grounded.isEditableRole ||
        _selectedInChain(situation.structuralEvidence, grounded)) {
      return null;
    }
    final selector = _selectorForPerceivedObject(
      situation.structuralEvidence,
      grounded,
    );
    if (selector == null) return null;
    final source = result.evidence.isEmpty
        ? 'percepción revalidada'
        : '${result.evidence.last.source.name} revalidado';
    return (
      ResolvedSurface(grounded, selector, 'target visual grounded'),
      source,
    );
  }

  Future<TaskStepResult> _fillElement(
    AutomationContext context,
    AutomationConversationSnapshot goal, {
    String? confirmedActionSignature,
  }) async {
    final mayUseSoleEditable =
        goal.uiTarget.isEmpty && goal.uiActionTarget.isNotEmpty;
    if (goal.uiText.isEmpty || (goal.uiTarget.isEmpty && !mayUseSoleEditable)) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin campo UI o texto objetivo en la orden',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final situation = context.perception.situation;
    if (!context.perception.isObserved || situation == null) {
      return TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason:
            context.perception.reason ??
            'sin situación estructural para resolver el campo',
        failureKind: TaskFailureKind.terminal,
      );
    }
    const inputResolver = EntityInputSurfaceResolver();
    final candidates = mayUseSoleEditable
        ? inputResolver.resolveSoleEditable(
            situation.structuralEvidence,
            packageName: situation.packageName,
          )
        : inputResolver.resolve(
            situation.structuralEvidence,
            goal.uiTarget,
            packageName: situation.packageName,
          );
    final fieldLabel = mayUseSoleEditable
        ? 'único campo editable'
        : 'campo "${goal.uiTarget}"';
    if (candidates.isEmpty) {
      return TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: '$fieldLabel no visible o sin selector estable',
        failureKind: TaskFailureKind.terminal,
      );
    }
    if (candidates.length != 1) {
      return TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason:
            '$fieldLabel ambiguo: '
            '${candidates.length} editables coinciden',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final write = _writeText;
    if (write == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin fuente de escritura UI',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final action = await write(
      candidates.single.selector,
      goal.uiText,
      confirmedActionSignature: confirmedActionSignature,
      semanticAction: 'fillElement',
    );
    return _stepFromAction(
      action,
      completedReason: '$fieldLabel escrito y verificado exactamente',
      recoverable: true,
    );
  }

  Future<TaskStepResult> _sendMessage(
    AutomationConversationSnapshot goal, {
    required String executionId,
    String? confirmedActionSignature,
    ExecutionJournalEntry? executionIntent,
  }) async {
    final guard = _commitGuard;
    final tap = _tap;
    if (guard == null || tap == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin ContextGuard/observación para envío irreversible',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final captured = await guard.capture(
      conversation: goal.target,
      draft: goal.draft,
    );
    if (!captured.ready) {
      return TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'context lock rechazó el envío: ${captured.reason}',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final context = captured.context!;
    final locked = await guard.revalidate(context);
    if (!locked.ready) {
      return TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'contexto cambió antes de enviar: ${locked.reason}',
        failureKind: TaskFailureKind.terminal,
      );
    }

    // ACT ONCE. Desde este punto nunca se reintenta el tap automáticamente.
    final action = await tap(
      context.sendSelector,
      confirmedActionSignature: confirmedActionSignature,
      semanticAction: 'sendMessage',
      executionId: executionId,
      executionIntent: executionIntent,
    );
    if (!action.completed) {
      return _stepFromAction(
        action,
        completedReason: 'botón de envío pulsado',
        recoverable: false,
      );
    }
    final evidence = await guard.verifyAfterDispatch(context);
    return switch (evidence.status) {
      SendEvidenceStatus.localSendVerified => TaskStepResult(
        status: TaskStepStatus.completed,
        reason:
            'envío local verificado: ${evidence.reason}; entrega remota desconocida',
      ),
      SendEvidenceStatus.dispatchedUnverified => TaskStepResult(
        status: TaskStepStatus.completedUnverified,
        reason: evidence.reason,
      ),
      SendEvidenceStatus.outcomeUnknown ||
      SendEvidenceStatus.contextChanged ||
      SendEvidenceStatus.incompleteEvidence ||
      SendEvidenceStatus.notExecuted => TaskStepResult(
        status: TaskStepStatus.outcomeUnknown,
        reason: evidence.reason,
        failureKind: TaskFailureKind.terminal,
      ),
    };
  }

  // ── T2.9 — búsqueda genérica dentro de una app ─────────────────────────────

  Future<TaskStepResult> _writeQuery(
    AutomationConversationSnapshot goal, {
    required String executionId,
    String? confirmedActionSignature,
  }) async {
    if (goal.query.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin query de búsqueda',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final resolveInput = _resolveInputSurfaceFor;
    final write = _writeText;
    if (resolveInput == null || write == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin fuente de escritura/observación',
        failureKind: TaskFailureKind.terminal,
      );
    }

    var input = await resolveInput('search');
    if (input == null || input.isEmpty) {
      // No hay campo visible: abrir la búsqueda tocando el icono (si existe).
      final resolveAction = _resolveActionSurface;
      final tap = _tap;
      if (resolveAction == null || tap == null) {
        return const TaskStepResult(
          status: TaskStepStatus.failed,
          reason: 'sin campo de búsqueda ni fuente para abrirlo',
          failureKind: TaskFailureKind.recoverable,
        );
      }
      final icon = await resolveAction('search');
      if (icon == null || icon.isEmpty) {
        // Recuperación: una superficie interna sin búsqueda visible (player,
        // detalle). Primero el botón atrás de la UI (vuelve a la raíz de la
        // MISMA app); solo si no existe, el back del sistema — y únicamente
        // cuando la app activa es la esperada (el back del sistema puede
        // salir de la app). El retry reintenta con la búsqueda disponible;
        // acotado por el presupuesto de reintentos.
        final uiBack = await resolveAction('back');
        if (uiBack != null && uiBack.isNotEmpty) {
          final backed = await tap(
            uiBack,
            semanticAction: 'writeQuery',
          );
          if (backed.status == TaskActionStatus.completed) {
            return const TaskStepResult(
              status: TaskStepStatus.failed,
              reason:
                  'superficie interna sin búsqueda; botón atrás ejecutado, reintentar',
              failureKind: TaskFailureKind.recoverable,
            );
          }
        }
        final expectedPackage = goal.appName.isEmpty
            ? ''
            : await _resolveAppPackage?.call(goal.appName) ?? '';
        final situation = _currentSituationSource == null
            ? null
            : await _currentSituationSource();
        final activePackage = situation?.packageName ?? '';
        final back = _back;
        if (back != null &&
            expectedPackage.isNotEmpty &&
            activePackage == expectedPackage) {
          final backed = await back(semanticAction: 'writeQuery');
          if (backed.status == TaskActionStatus.completed) {
            return const TaskStepResult(
              status: TaskStepStatus.failed,
              reason:
                  'superficie interna sin búsqueda; atrás ejecutado, reintentar',
              failureKind: TaskFailureKind.recoverable,
            );
          }
        }
        return const TaskStepResult(
          status: TaskStepStatus.failed,
          reason: 'sin superficie de búsqueda',
          failureKind: TaskFailureKind.recoverable,
        );
      }
      final openSearch = await tap(
        icon,
        confirmedActionSignature: confirmedActionSignature,
        semanticAction: 'writeQuery',
        executionId: executionId,
      );
      if (!openSearch.completed) {
        return _stepFromAction(
          openSearch,
          completedReason: 'búsqueda abierta',
          recoverable: true,
        );
      }
      // La pantalla de búsqueda aparece con una transición: reobservar con
      // esperas cortas hasta que el campo editable sea observable. Sin
      // espera, el snapshot captura la pantalla previa y el campo "no
      // existe" aunque ya esté apareciendo.
      input = await _resolveInputWithSettle(resolveInput);
      if (input == null || input.isEmpty) {
        return const TaskStepResult(
          status: TaskStepStatus.failed,
          reason: 'el icono de búsqueda no abrió un campo editable',
          failureKind: TaskFailureKind.recoverable,
        );
      }
    }

    final action = await write(
      input,
      goal.query,
      confirmedActionSignature: confirmedActionSignature,
      semanticAction: 'writeQuery',
    );
    return _stepFromAction(
      action,
      completedReason: 'query escrita en el campo de búsqueda',
      recoverable: true,
    );
  }

  Future<TaskStepResult> _submitSearch(
    AutomationConversationSnapshot goal, {
    required String executionId,
    String? confirmedActionSignature,
  }) async {
    // Captura PRE una sola vez. Tanto el botón visible como ACTION_IME_ENTER
    // deben demostrar después una transición observable; aceptar la acción del
    // sistema no equivale por sí mismo a completar la búsqueda.
    final readText = _readVisibleText;
    final detect = _detectSearchResults;
    final before = readText != null ? await readText() : null;
    final beforeResults = detect != null ? await detect() : null;
    final resolveAction = _resolveActionSurface;
    final tap = _tap;
    final action = resolveAction == null ? null : await resolveAction('search');
    if (action == null || action.isEmpty) {
      // Navegadores y muchas superficies no exponen un botón de submit en el
      // árbol de la app: la acción real vive en el editor/IME. Se ejecuta sólo
      // sobre el único campo editable enfocado y, si se expresó una app, el
      // nativo exige que el package siga coincidiendo.
      final submitInput = _submitInput;
      if (submitInput == null) {
        return const TaskStepResult(
          status: TaskStepStatus.completedUnverified,
          reason: 'query escrita; sin botón ni adaptador IME para submit',
        );
      }
      final expectedPackage = goal.appName.isEmpty
          ? ''
          : await _resolveAppPackage?.call(goal.appName) ?? '';
      final submitted = await submitInput(expectedPackageName: expectedPackage);
      if (!submitted.completed) {
        return _stepFromAction(
          submitted,
          completedReason: 'búsqueda enviada mediante el editor',
          recoverable: true,
        );
      }
      return _verifySearchSubmission(
        beforeText: before,
        beforeResults: beforeResults,
        acceptedReason: submitted.reason,
      );
    }
    if (tap == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'botón de búsqueda observado, pero no hay ejecutor de toque',
        failureKind: TaskFailureKind.terminal,
      );
    }

    final submitted = await tap(
      action,
      confirmedActionSignature: confirmedActionSignature,
      semanticAction: 'submitSearch',
      executionId: executionId,
    );
    if (!submitted.completed) {
      return _stepFromAction(
        submitted,
        completedReason: 'búsqueda enviada',
        recoverable: true,
      );
    }

    return _verifySearchSubmission(
      beforeText: before,
      beforeResults: beforeResults,
      acceptedReason: 'botón de búsqueda aceptado',
    );
  }

  /// Verificación POST acotada y solo observacional. Las aplicaciones actualizan
  /// su árbol de accesibilidad de forma asíncrona; por eso se reobserva con un
  /// presupuesto corto. Nunca repite el submit ni transforma ausencia de
  /// evidencia en éxito.
  Future<TaskStepResult> _verifySearchSubmission({
    required String? beforeText,
    required int? beforeResults,
    required String acceptedReason,
  }) async {
    final readText = _readVisibleText;
    final detect = _detectSearchResults;
    if (readText == null && detect == null) {
      return TaskStepResult(
        status: TaskStepStatus.completedUnverified,
        reason: '$acceptedReason; sin fuente de verificación posterior',
      );
    }

    const waits = <Duration>[
      Duration.zero,
      Duration(milliseconds: 120),
      Duration(milliseconds: 240),
      Duration(milliseconds: 480),
    ];
    var partialEvidence = false;
    for (final wait in waits) {
      if (wait != Duration.zero) await Future<void>.delayed(wait);
      final afterText = readText != null ? await readText() : null;
      final afterResults = detect != null ? await detect() : null;
      final changed =
          beforeText != null && afterText != null && beforeText != afterText;
      final hasResults = afterResults != null && afterResults > 0;
      final resultSetChanged =
          beforeResults != null &&
          afterResults != null &&
          beforeResults != afterResults;

      if (changed && (hasResults || resultSetChanged)) {
        return TaskStepResult(
          status: TaskStepStatus.completed,
          reason:
              'búsqueda verificada: cambió la superficie y se observaron '
              '$afterResults resultado(s)',
        );
      }
      partialEvidence = partialEvidence || changed || resultSetChanged;
    }

    return TaskStepResult(
      status: TaskStepStatus.completedUnverified,
      reason: partialEvidence
          ? '$acceptedReason; transición observada sin resultados suficientes'
          : '$acceptedReason; sin cambio detectable dentro del presupuesto',
    );
  }

  // ── T2.9-select — selección semántica de resultado observado ───────────────

  Future<TaskStepResult> _selectResult(
    AutomationConversationSnapshot goal, {
    required String executionId,
    String? confirmedActionSignature,
  }) async {
    final resolve = _resolveResult;
    final tap = _tap;
    if (resolve == null || tap == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin fuente de resolución/tap de resultados',
        failureKind: TaskFailureKind.terminal,
      );
    }

    final ResultTarget target;
    if (goal.resultOrdinal != null) {
      target = ResultOrdinal(goal.resultOrdinal!);
    } else if (goal.resultText.isNotEmpty) {
      target = ResultText(goal.resultText);
    } else {
      // Reproducción automática ("reproduce X"): el primer resultado es el
      // destino por defecto; la unicidad se re-verifica en el snapshot.
      target = const ResultOrdinal(1);
    }

    final resolution = await resolve(target);
    if (resolution == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin snapshot de pantalla para resolver resultados',
        failureKind: TaskFailureKind.terminal,
      );
    }
    if (resolution is ResultNotFound) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'resultado no encontrado en pantalla',
        failureKind: TaskFailureKind.terminal,
      );
    }
    if (resolution is ResultIncompleteEvidence) {
      return TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason:
            'snapshot incompleto: ${resolution.observed.length} resultado(s) '
            'observados no prueban una selección única',
        failureKind: TaskFailureKind.terminal,
      );
    }
    if (resolution is ResultAmbiguous) {
      return TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason:
            'resultado ambiguo entre ${resolution.candidates.length} coincidencias (clarificación)',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final candidate = (resolution as ResultResolved).candidate;

    // PRE: snapshot A (fingerprint de texto visible).
    final readText = _readVisibleText;
    final before = readText != null ? await readText() : null;

    final selected = await tap(
      candidate.selector,
      confirmedActionSignature: confirmedActionSignature,
      semanticAction: 'selectResult',
      executionId: executionId,
    );
    if (!selected.completed) {
      return _stepFromAction(
        selected,
        completedReason: 'resultado seleccionado',
        recoverable: true,
      );
    }

    // POST: SearchResultVerification de apertura — "tap aceptado" NO es apertura.
    final after = readText != null ? await readText() : null;
    final changed = before != null && after != null && before != after;
    final title = candidate.title.toLowerCase();
    final contentObserved =
        after != null &&
        title.isNotEmpty &&
        after.toLowerCase().contains(title);

    if (changed && contentObserved) {
      // YouTube (y reproductores similares): el anuncio aparece tras unos
      // segundos de reproducción. Un intento único de salto — si no hay
      // botón observable, el video continúa sin intervención.
      await _skipAdIfPresent();
      return const TaskStepResult(
        status: TaskStepStatus.completed,
        reason: 'resultado abierto: contenido objetivo observado',
      );
    }
    if (changed) {
      return const TaskStepResult(
        status: TaskStepStatus.completedUnverified,
        reason: 'pantalla cambió (evidencia parcial de apertura)',
      );
    }
    return const TaskStepResult(
      status: TaskStepStatus.completedUnverified,
      reason: 'tap aceptado; sin cambio detectable de pantalla',
    );
  }

  /// Reobserva el campo de búsqueda con esperas cortas: las pantallas de
  /// búsqueda entran con transición y el snapshot inmediato captura la
  /// pantalla anterior. Presupuesto acotado (~2s total).
  Future<String?> _resolveInputWithSettle(
    Future<String?> Function(String kind) resolveInput,
  ) async {
    const waits = <Duration>[
      Duration.zero,
      Duration(milliseconds: 250),
      Duration(milliseconds: 500),
      Duration(milliseconds: 1000),
    ];
    for (final wait in waits) {
      if (wait != Duration.zero) await Future<void>.delayed(wait);
      final input = await resolveInput('search');
      if (input != null && input.isNotEmpty) return input;
    }
    return null;
  }

  /// Intento único de saltar un anuncio tras abrir un video. Espera el
  /// intervalo típico de aparición y, si el botón es observable, lo toca.
  /// Sin botón → no-op honesto (el video sigue reproduciéndose).
  Future<void> _skipAdIfPresent() async {
    final resolveAction = _resolveActionSurface;
    final tap = _tap;
    if (resolveAction == null || tap == null) return;
    await Future<void>.delayed(const Duration(seconds: 3));
    final skip = await resolveAction('skipAd');
    if (skip == null || skip.isEmpty) return;
    await tap(skip, semanticAction: 'selectResult');
  }

  TaskStepResult _stepFromAction(
    TaskActionResult action, {
    required String completedReason,
    TaskValue? output,
    bool recoverable = false,
  }) {
    return switch (action.status) {
      TaskActionStatus.completed => TaskStepResult(
        status: TaskStepStatus.completed,
        reason: completedReason,
        output: output,
      ),
      TaskActionStatus.completedUnverified => TaskStepResult(
        status: TaskStepStatus.completedUnverified,
        reason: action.reason,
        output: output,
      ),
      TaskActionStatus.needsConfirmation => TaskStepResult(
        status: TaskStepStatus.needsConfirmation,
        reason: action.reason,
        failureKind: TaskFailureKind.terminal,
        pendingActionSignature: action.actionSignature,
      ),
      TaskActionStatus.denied => TaskStepResult(
        status: TaskStepStatus.denied,
        reason: action.reason,
        failureKind: TaskFailureKind.terminal,
      ),
      TaskActionStatus.outcomeUnknown => TaskStepResult(
        status: TaskStepStatus.outcomeUnknown,
        reason: action.reason,
        failureKind: TaskFailureKind.terminal,
      ),
      TaskActionStatus.failed => TaskStepResult(
        status: TaskStepStatus.failed,
        reason: action.reason,
        failureKind: recoverable
            ? TaskFailureKind.recoverable
            : TaskFailureKind.terminal,
      ),
    };
  }

  String _planSignature(TaskPlan plan, List<TaskStep> ordered) =>
      canonicalFingerprint({
        'goal': plan.goal,
        'steps': [
          for (var index = 0; index < ordered.length; index++)
            {
              'index': index,
              'id': ordered[index].id,
              'action': ordered[index].semanticAction,
              'dependencies': ordered[index].dependencies,
              'bindings': {
                for (final entry in ordered[index].inputBindings.entries)
                  entry.key: entry.value.source.value,
              },
              'evidence': {
                for (final entry in ordered[index].dependencyEvidence.entries)
                  entry.key: entry.value.name,
              },
            },
        ],
      });

  AutomationConversationSnapshot _parseGoal(String goal) {
    final g = goal.toLowerCase();

    // Intención de mensaje (app/recipient/message) vía el parser ÚNICO.
    final intent = const MessageIntentParser().parse(goal);
    const genericParser = GenericUiIntentParser();
    final genericUi = genericParser.parse(goal);
    final genericFill = genericParser.parseFill(goal);
    final genericCompose = genericParser.parseCompose(goal);
    final search = genericParser.parseSearch(goal);

    // Cada parser conserva intención; package y superficies se resuelven
    // después contra inventario/Accessibility. La búsqueda comparte exactamente
    // la misma gramática que TaskPlanner, incluidas apps de varias palabras.
    var appName = intent.app;
    if (genericUi.app.isNotEmpty) appName = genericUi.app;
    if (genericFill.app.isNotEmpty) appName = genericFill.app;
    if (genericCompose.app.isNotEmpty) appName = genericCompose.app;
    if (search.app.isNotEmpty) appName = search.app;

    // T2.9-select: ordinal ("segundo") o texto ("que dice X") del resultado.
    final resultOrdinal = _parseResultOrdinal(g);
    final resultText = _parseResultText(goal);

    return AutomationConversationSnapshot(
      appName: appName,
      target: intent.recipient,
      draft: intent.message,
      query: search.query,
      resultOrdinal: resultOrdinal,
      resultText: resultText,
      uiActionTarget: genericCompose.actionTarget,
      uiTarget: genericCompose.fieldTarget.isNotEmpty
          ? genericCompose.fieldTarget
          : genericFill.target.isNotEmpty
          ? genericFill.target
          : genericUi.target,
      uiText: genericCompose.text.isNotEmpty
          ? genericCompose.text
          : genericFill.text,
    );
  }

  /// Ordinal determinista de resultado: "primero"=1, "segundo"=2, "resultado 3",
  /// "el de arriba"=1. null = sin ordinal explícito.
  int? _parseResultOrdinal(String g) {
    const words = {
      'primero': 1,
      'primer': 1,
      'primera': 1,
      'segundo': 2,
      'segunda': 2,
      'tercero': 3,
      'tercer': 3,
      'tercera': 3,
      'cuarto': 4,
      'cuarta': 4,
      'quinto': 5,
      'quinta': 5,
    };
    for (final e in words.entries) {
      if (g.contains(e.key)) return e.value;
    }
    final nMatch = RegExp(r'resultado\s+(\d+)').firstMatch(g);
    if (nMatch != null) return int.tryParse(nMatch.group(1)!);
    if (g.contains('de arriba')) return 1;
    return null;
  }

  /// Texto objetivo del resultado: "que dice X" / "dice X". '' = sin texto.
  /// Se recorta del ORIGINAL para conservar el case ("NanoRuntime").
  String _parseResultText(String goal) {
    final m = RegExp(r'dice\s+(.+)$', caseSensitive: false).firstMatch(goal);
    return m?.group(1)?.trim() ?? '';
  }
}
