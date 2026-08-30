/// A15.0 — TaskOrchestrator: ejecuta un TaskPlan paso a paso, transportando
/// TaskValues TIPADOS entre dominios.
///
/// NO es un segundo AutomationCoordinator ni un workflow engine libre. Cada paso
/// es semántico; la ejecución efectiva se delega a fuentes inyectadas (que a su
/// vez pasan por el pipeline Candidate-First + governance + verificación).
library;

import '../notifications/notification_object.dart';
import '../notifications/observed_data_extractor.dart';
import '../navigation/goal_directed_navigator.dart';
import '../navigation/navigation_decision.dart';
import '../navigation/navigation_goal.dart';
import '../navigation/navigation_history.dart';
import '../navigation/navigation_transition_verifier.dart';
import '../perception/current_situation.dart';
import '../perception/search_result_resolver.dart';
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
typedef TaskResolveAppPackage = Future<String?> Function(String appReference);

bool _isUnresolvedCommit(ExecutionJournalStatus status) =>
    status == ExecutionJournalStatus.executing ||
    status == ExecutionJournalStatus.executed ||
    status == ExecutionJournalStatus.verifying ||
    status == ExecutionJournalStatus.completedUnverified ||
    status == ExecutionJournalStatus.outcomeUnknown;

class TaskOrchestrator {
  TaskOrchestrator({
    required Future<List<dynamic>> Function() listNotifications,
    required TaskOpenUrl openUrl,
    required TaskWriteFile writeFile,
    TaskLaunchApp? launchApp,
    TaskTap? tap,
    TaskWriteText? writeText,
    TaskBack? back,
    TaskResolveAppPackage? resolveAppPackage,
    CurrentSituationSource? currentSituationSource,
    AutomationMemorySource? memorySource,
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
    this.maxAttemptsPerStep = 2,
    this.maxReplansPerTask = 2,
  }) : _listNotifications = listNotifications,
       _openUrl = openUrl,
       _writeFile = writeFile,
       _launchApp = launchApp,
       _tap = tap,
       _writeText = writeText,
       _back = back,
       _resolveAppPackage = resolveAppPackage,
       _currentSituationSource = currentSituationSource,
       _memorySource = memorySource,
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
  final TaskBack? _back;
  final TaskResolveAppPackage? _resolveAppPackage;
  final CurrentSituationSource? _currentSituationSource;
  final AutomationMemorySource? _memorySource;
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
      final unresolved = (await journal.all()).where(
        (entry) =>
            entry.goalFingerprint == goalFingerprint &&
            entry.irreversible &&
            (_isUnresolvedCommit(entry.status)),
      );
      if (unresolved.isNotEmpty) {
        return const [
          TaskStepResult(
            status: TaskStepStatus.outcomeUnknown,
            reason:
                'existe un commit irreversible activo o incierto para este objetivo; '
                'se requiere reconciliación antes de repetir',
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
      try {
        await journal?.save(
          ExecutionJournalEntry(
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
          ),
        );
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
    if (step.semanticAction == 'openConversation') {
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
          confirmedActionSignature: confirmedActionSignature,
          executionIntent: executionIntent,
        );
      case 'writeQuery':
        return _writeQuery(
          goal,
          confirmedActionSignature: confirmedActionSignature,
        );
      case 'submitSearch':
        return _submitSearch(
          goal,
          confirmedActionSignature: confirmedActionSignature,
        );
      case 'selectResult':
        return _selectResult(
          goal,
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
    final decision = _navigator.decide(current, navigationGoal);
    final transition = _transitionVerifier.verify(
      history: navigationHistory,
      current: current,
      goal: navigationGoal,
      decision: decision,
    );
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
          confirmedActionSignature: confirmedActionSignature,
        );
    }
  }

  Future<TaskStepResult> _executeNavigationDecision(
    NavigationDecision decision, {
    required CurrentSituation current,
    required NavigationGoal goal,
    required NavigationHistory navigationHistory,
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
    }

    if (result.status != TaskActionStatus.needsConfirmation &&
        result.status != TaskActionStatus.denied) {
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

  Future<TaskStepResult> _sendMessage(
    AutomationConversationSnapshot goal, {
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
      SendEvidenceStatus.incompleteEvidence => TaskStepResult(
        status: TaskStepStatus.outcomeUnknown,
        reason: evidence.reason,
        failureKind: TaskFailureKind.terminal,
      ),
    };
  }

  // ── T2.9 — búsqueda genérica dentro de una app ─────────────────────────────

  Future<TaskStepResult> _writeQuery(
    AutomationConversationSnapshot goal, {
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
      );
      if (!openSearch.completed) {
        return _stepFromAction(
          openSearch,
          completedReason: 'búsqueda abierta',
          recoverable: true,
        );
      }
      input = await resolveInput('search');
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
    String? confirmedActionSignature,
  }) async {
    final resolveAction = _resolveActionSurface;
    final tap = _tap;
    if (resolveAction == null || tap == null) {
      return const TaskStepResult(
        status: TaskStepStatus.completedUnverified,
        reason: 'query escrita; sin fuente para submit',
      );
    }
    final action = await resolveAction('search');
    if (action == null || action.isEmpty) {
      // Sin botón de submit: búsqueda en vivo (algunas apps buscan al escribir).
      return const TaskStepResult(
        status: TaskStepStatus.completedUnverified,
        reason: 'query escrita; sin botón de submit (búsqueda en vivo)',
      );
    }

    // PRE: snapshot A (fingerprint de texto visible).
    final readText = _readVisibleText;
    final detect = _detectSearchResults;
    final before = readText != null ? await readText() : null;

    final submitted = await tap(
      action,
      confirmedActionSignature: confirmedActionSignature,
      semanticAction: 'submitSearch',
    );
    if (!submitted.completed) {
      return _stepFromAction(
        submitted,
        completedReason: 'búsqueda enviada',
        recoverable: true,
      );
    }

    // POST: SearchResultVerification — "tecla aceptada" NO es búsqueda.
    final after = readText != null ? await readText() : null;
    final results = detect != null ? await detect() : null;
    final changed = before != null && after != null && before != after;
    final hasResults = results != null && results > 0;

    if (changed && hasResults) {
      return TaskStepResult(
        status: TaskStepStatus.completed,
        reason: 'búsqueda verificada: pantalla cambió y $results resultado(s)',
      );
    }
    if (changed || hasResults) {
      return const TaskStepResult(
        status: TaskStepStatus.completedUnverified,
        reason:
            'evidencia parcial de búsqueda (cambio de pantalla o resultados)',
      );
    }
    return const TaskStepResult(
      status: TaskStepStatus.completedUnverified,
      reason: 'submit aceptado; sin cambio detectable de pantalla',
    );
  }

  // ── T2.9-select — selección semántica de resultado observado ───────────────

  Future<TaskStepResult> _selectResult(
    AutomationConversationSnapshot goal, {
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
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin ordinal ni texto de resultado',
        failureKind: TaskFailureKind.terminal,
      );
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

    // App: intent.app ("abre X"/"ve a X") o "… en X" (búsqueda "busca Y en X").
    final enAppMatch = RegExp(r'en\s+(\w+)\s*$').firstMatch(g);
    var appName = intent.app;
    if (enAppMatch != null) appName = enAppMatch.group(1)!;

    // Query: "busca X…" — se recorta del ORIGINAL para conservar el case del
    // término de búsqueda ("NanoRuntime" no debe quedar "nanoruntime").
    var query = '';
    final buscaIdx = g.indexOf('busca');
    if (buscaIdx >= 0) {
      query = goal.substring(buscaIdx + 'busca'.length).trim();
      if (enAppMatch != null) {
        query = query
            .replaceAll(RegExp(r'\s+en\s+\w+\s*$', caseSensitive: false), '')
            .trim();
      }
    }

    // T2.9-select: ordinal ("segundo") o texto ("que dice X") del resultado.
    final resultOrdinal = _parseResultOrdinal(g);
    final resultText = _parseResultText(goal);

    return AutomationConversationSnapshot(
      appName: appName,
      target: intent.recipient,
      draft: intent.message,
      query: query,
      resultOrdinal: resultOrdinal,
      resultText: resultText,
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
