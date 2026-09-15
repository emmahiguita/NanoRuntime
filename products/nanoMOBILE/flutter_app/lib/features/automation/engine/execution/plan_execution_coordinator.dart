import 'dart:async';

import '../governance/action_confirmation.dart';
import '../governance/rule_execution_authority.dart';
import '../orchestration/execution_journal.dart';
import '../voice/execution_cancellation.dart';
import 'action_path_router.dart';
import 'agent_executor.dart';
import 'tool_call.dart';
import 'tool_loop_detector.dart';
import 'tool_outcome.dart';
import 'tool_registry.dart';

/// Coordinador de ejecución de planes multi-paso y acciones irreversibles bajo Journaling.
/// Cumple SRP: orquesta la secuencia de pasos, consumo de tokens de confirmación,
/// detección de bucles de estado, persistencia de transiciones de journal y timeout.
class PlanExecutionCoordinator {
  PlanExecutionCoordinator({
    required PolicyEngine policy,
    required ActionPathRouter router,
    required AgentExecutor executor,
    required Future<ToolOutcome> Function(
      ToolCall call, {
      bool humanInitiated,
      bool confirmed,
      String? executionId,
      ToolExecutionBudget? budget,
      ExecutionCancellationToken? cancellation,
      ExecutionJournalEntry? executionIntent,
      RuleExecutionAuthority? authority,
      void Function()? onPhysicalEffectDispatched,
    }) runToolGuarded,
    required Future<String> Function(
      ToolCall call,
      ToolDefinition tool,
      ToolExecutionBudget budget,
    ) executeWithTimeout,
    ExecutionJournal? executionJournal,
  })  : _policy = policy,
        _router = router,
        _executor = executor,
        _runToolGuarded = runToolGuarded,
        _executeWithTimeout = executeWithTimeout,
        _executionJournal = executionJournal;

  final PolicyEngine _policy;
  final ActionPathRouter _router;
  final AgentExecutor _executor;
  final Future<ToolOutcome> Function(
    ToolCall call, {
    bool humanInitiated,
    bool confirmed,
    String? executionId,
    ToolExecutionBudget? budget,
    ExecutionCancellationToken? cancellation,
    ExecutionJournalEntry? executionIntent,
    RuleExecutionAuthority? authority,
    void Function()? onPhysicalEffectDispatched,
  }) _runToolGuarded;
  final Future<String> Function(
    ToolCall call,
    ToolDefinition tool,
    ToolExecutionBudget budget,
  ) _executeWithTimeout;
  final ExecutionJournal? _executionJournal;
  Future<void>? _journalRecovery;

  static const uiStateSensitiveTools = {
    'tap',
    'back',
    'launch_app',
    'write',
    'home',
    'recents',
    'open_notifications',
    'open_quick_settings',
    'swipe',
    'scroll',
    'long_press',
  };

  static bool requiresGoalDirectedExecution(List<ToolCall> plan) =>
      plan.where((call) => uiStateSensitiveTools.contains(call.tool)).length > 1;

  static String planSignature(List<ToolCall> plan) => canonicalFingerprint(
        plan.map((call) => call.confirmationSignature).toList(growable: false),
      );

  static int _runSequence = 0;
  static String newRunId() =>
      'tool-${DateTime.now().microsecondsSinceEpoch}-${++_runSequence}';

  static bool isFailedFeedback(String feedback) {
    return RegExp(r'^\[[a-zA-Z]+(:|\])').hasMatch(feedback);
  }

  static ToolExecutionStatus executionStatusFor(String feedback) {
    if (feedback.startsWith('[completed]')) {
      return ToolExecutionStatus.completed;
    }
    if (feedback.startsWith('[completedUnverified]')) {
      return ToolExecutionStatus.completedUnverified;
    }
    if (feedback.startsWith('[timeoutOutcomeUnknown]')) {
      return ToolExecutionStatus.outcomeUnknown;
    }
    if (isFailedFeedback(feedback)) return ToolExecutionStatus.failed;
    return ToolExecutionStatus.completed;
  }

  static ExecutionJournalStatus journalStatusFor(
    ToolExecutionStatus s, {
    required ExecutionJournalStatus notExecutedAs,
  }) =>
      switch (s) {
        ToolExecutionStatus.completed => ExecutionJournalStatus.verified,
        ToolExecutionStatus.completedUnverified =>
          ExecutionJournalStatus.completedUnverified,
        ToolExecutionStatus.outcomeUnknown =>
          ExecutionJournalStatus.outcomeUnknown,
        ToolExecutionStatus.failed => ExecutionJournalStatus.failed,
        ToolExecutionStatus.notExecuted => notExecutedAs,
      };

  /// Ejecuta un plan multi-paso garantizando detección de bucles y control de journal.
  Future<PlanOutcome> runPlanGuarded(
    List<ToolCall> plan, {
    bool humanInitiated = false,
    ActionConfirmation? confirmation,
    String? executionId,
    bool confirmed = false,
    ExecutionCancellationToken? cancellation,
    void Function(int stepIndex)? onStep,
    RuleExecutionAuthority? authority,
    void Function()? onPhysicalEffectDispatched,
  }) async {
    if (requiresGoalDirectedExecution(plan)) {
      const denied = ToolOutcome(
        verdict: PolicyVerdict.denied,
        feedback:
            '[goalDirectedRequired] Plan UI multipaso bloqueado: requiere '
            'observar, clasificar y verificar la superficie entre acciones.',
        executionStatus: ToolExecutionStatus.notExecuted,
      );
      return const PlanOutcome(
        completed: false,
        steps: [denied],
        summary:
            '[goalDirectedRequired] Plan UI multipaso bloqueado: requiere '
            'TaskOrchestrator y nueva observación entre acciones.',
      );
    }
    final outcomes = <ToolOutcome>[];
    final feedbacks = <String>[];
    final paths = <ExecutionPath>[];
    final total = plan.length;
    final loopDetector = ToolLoopDetector();
    final budget = ToolExecutionBudget();
    final signature = planSignature(plan);
    final runId = executionId ?? confirmation?.executionId ?? newRunId();
    final journal = _executionJournal;
    ExecutionJournalEntry? authorizedEntry;
    var validConfirmation = false;
    if (confirmation != null &&
        confirmation.stepIndex >= 0 &&
        confirmation.stepIndex < plan.length) {
      if (journal != null) {
        try {
          authorizedEntry = await journal.consumeConfirmation(confirmation);
          validConfirmation = authorizedEntry != null;
        } on Object {
          validConfirmation = false;
        }
      } else {
        validConfirmation = confirmation.consumeIfAuthorizes(
          executionId: runId,
          planSignature: signature,
          stepIndex: confirmation.stepIndex,
          stepId: 'tool:${confirmation.stepIndex}',
          actionSignature: plan[confirmation.stepIndex].confirmationSignature,
        );
      }
    }
    if (confirmation != null && !validConfirmation) {
      const denied = ToolOutcome(
        verdict: PolicyVerdict.denied,
        feedback:
            '[confirmationInvalid] Confirmación válida, expirada, consumida o no pendiente en el journal.',
      );
      return const PlanOutcome(
        completed: false,
        steps: [denied],
        summary:
            '[confirmationInvalid] Confirmación válida, expirada, consumida o no pendiente en el journal.',
      );
    }
    final confirmedStepIndex =
        validConfirmation ? confirmation!.stepIndex : null;
    final startIndex = confirmedStepIndex ?? 0;
    for (var i = startIndex; i < total; i++) {
      cancellation?.throwIfCancelled();
      onStep?.call(i);
      final call = plan[i];
      paths.add(_router.route(call).path);

      final fp = await loopFingerprint(call);
      if (loopDetector.isLoop(fp)) {
        final loopOutcome = ToolOutcome(
          verdict: PolicyVerdict.denied,
          feedback:
              '[loopDetected] Ciclo en el plan '
              '("${call.tool} ${call.selectorArg ?? ''}${call.textArg != null ? ' ${call.textArg!}' : ''}"). '
              'El mundo no avanza: se aborta en lugar de repetir la acción.',
        );
        outcomes.add(loopOutcome);
        return PlanOutcome(
          completed: false,
          steps: outcomes,
          summary: [...feedbacks, loopOutcome.feedback].join('\n'),
          paths: paths,
        );
      }

      final stepConfirmed = i == confirmedStepIndex;
      final tool = _policy.registry.lookup(call.tool);
      ExecutionJournalEntry? executionIntent;
      if (stepConfirmed && authorizedEntry != null && tool != null) {
        if (tool.irreversible) {
          executionIntent = authorizedEntry;
        } else if (journal != null) {
          final executing = authorizedEntry.copyWith(
            status: ExecutionJournalStatus.executing,
            verificationState: 'acción autorizada; ejecución en curso',
            timestamp: DateTime.now().toUtc(),
          );
          await journal.save(executing);
          authorizedEntry = executing;
        }
      }
      final outcome = await _runToolGuarded(
        call,
        humanInitiated: humanInitiated,
        confirmed: stepConfirmed,
        executionId: runId,
        budget: budget,
        cancellation: cancellation,
        executionIntent: executionIntent,
        authority: authority,
        onPhysicalEffectDispatched: onPhysicalEffectDispatched,
      );
      outcomes.add(outcome);

      if (outcome.needsConfirmation) {
        final request = ActionConfirmation(
          executionId: runId,
          planSignature: signature,
          stepIndex: i,
          stepId: 'tool:$i',
          actionSignature: call.confirmationSignature,
        );
        final pendingTool = _policy.registry.lookup(call.tool);
        if (journal != null && pendingTool != null) {
          try {
            final planned = ExecutionJournalEntry(
              runId: runId,
              planSignature: signature,
              goalFingerprint: canonicalFingerprint({'plan': signature}),
              currentStep: i,
              stepId: 'tool:$i',
              status: ExecutionJournalStatus.planned,
              irreversible: pendingTool.irreversible,
              actionSignature: call.confirmationSignature,
              verificationState: 'acción planificada; aún no autorizada',
              timestamp: DateTime.now().toUtc(),
            );
            await journal.save(planned);
            await journal.save(
              planned.copyWith(
                status: ExecutionJournalStatus.waitingConfirmation,
                verificationState: 'acción pendiente de confirmación explícita',
                timestamp: DateTime.now().toUtc(),
                pendingConfirmation: request,
              ),
            );
          } on Object catch (error) {
            final denied = ToolOutcome(
              verdict: PolicyVerdict.denied,
              feedback:
                  '[journalUnavailable] No se pudo persistir la confirmación: $error.',
            );
            outcomes[outcomes.length - 1] = denied;
            return PlanOutcome(
              completed: false,
              steps: outcomes,
              summary: [...feedbacks, denied.feedback].join('\n'),
              paths: paths,
            );
          }
        }
        return PlanOutcome(
          completed: false,
          steps: outcomes,
          pauseIndex: i,
          pauseCall: call,
          confirmation: request,
          summary: [...feedbacks, outcome.feedback].join('\n'),
          paths: paths,
        );
      }
      if (stepConfirmed &&
          authorizedEntry != null &&
          tool != null &&
          journal != null) {
        final ExecutionJournalEntry verifying;
        if (tool.irreversible) {
          final persisted = await journal.load(authorizedEntry.runId);
          if (persisted == null ||
              persisted.status != ExecutionJournalStatus.verifying) {
            return PlanOutcome(
              completed: false,
              steps: outcomes,
              summary:
                  '[outcomeUnknown] El journal no conserva la fase de verificación de la acción.',
              paths: paths,
            );
          }
          verifying = persisted;
        } else {
          final executed = authorizedEntry.copyWith(
            status: ExecutionJournalStatus.executed,
            verificationState: 'efecto ejecutado; verificación pendiente',
            timestamp: DateTime.now().toUtc(),
          );
          verifying = executed.copyWith(
            status: ExecutionJournalStatus.verifying,
            verificationState: 'verificación en curso',
            timestamp: DateTime.now().toUtc(),
          );
          await journal.save(executed);
          await journal.save(verifying);
        }
        await journal.save(
          verifying.copyWith(
            status: journalStatusFor(
              outcome.executionStatus,
              notExecutedAs: ExecutionJournalStatus.cancelled,
            ),
            verificationState: outcome.feedback,
            timestamp: DateTime.now().toUtc(),
          ),
        );
      }
      feedbacks.add('${i + 1}/$total ${outcome.feedback}');
      if (outcome.verdict != PolicyVerdict.allow || outcome.executionFailed) {
        return PlanOutcome(
          completed: false,
          steps: outcomes,
          summary: feedbacks.join('\n'),
          paths: paths,
        );
      }
    }

    return PlanOutcome(
      completed: true,
      steps: outcomes,
      summary: feedbacks.join('\n'),
      paths: paths,
    );
  }

  /// Ejecuta una acción irreversible bajo contrato estricto de journal.
  Future<ToolOutcome> runIrreversibleTool(
    ToolCall call,
    ToolDefinition tool,
    ToolExecutionBudget budget, {
    String? executionId,
    ExecutionJournalEntry? executionIntent,
    bool allowPreviouslyUncertain = false,
    ExecutionCancellationToken? cancellation,
    void Function()? onPhysicalEffectDispatched,
  }) async {
    final journal = _executionJournal;
    if (journal == null) {
      return const ToolOutcome(
        verdict: PolicyVerdict.denied,
        feedback:
            '[journalUnavailable] Acción irreversible bloqueada: no hay journal durable.',
        executionStatus: ToolExecutionStatus.notExecuted,
      );
    }

    try {
      await (_journalRecovery ??= journal.recoverInterrupted());
    } on Object catch (error) {
      return ToolOutcome(
        verdict: PolicyVerdict.denied,
        feedback:
            '[journalUnavailable] Acción irreversible bloqueada: no se pudo recuperar el journal ($error).',
        executionStatus: ToolExecutionStatus.notExecuted,
      );
    }

    final actionSignature = call.confirmationSignature;
    final now = DateTime.now().toUtc();
    ExecutionJournalEntry authorizedEntry;
    if (executionIntent != null) {
      final ExecutionJournalEntry? persisted;
      try {
        persisted = await journal.load(executionIntent.runId);
      } on Object catch (error) {
        return ToolOutcome(
          verdict: PolicyVerdict.denied,
          feedback:
              '[journalUnavailable] No se pudo validar la intención autorizada: $error.',
          executionStatus: ToolExecutionStatus.notExecuted,
        );
      }
      if (persisted == null ||
          persisted.status != ExecutionJournalStatus.authorized ||
          !persisted.irreversible ||
          persisted.planSignature != executionIntent.planSignature ||
          persisted.currentStep != executionIntent.currentStep ||
          persisted.stepId != executionIntent.stepId ||
          persisted.actionSignature != executionIntent.actionSignature) {
        return const ToolOutcome(
          verdict: PolicyVerdict.denied,
          feedback:
              '[journalUnavailable] Intención autorizada inválida o no persistida.',
          executionStatus: ToolExecutionStatus.notExecuted,
        );
      }
      authorizedEntry = persisted;
    } else {
      final runId = executionId ?? newRunId();
      authorizedEntry = ExecutionJournalEntry(
        runId: runId,
        planSignature: actionSignature,
        goalFingerprint: canonicalFingerprint({'action': actionSignature}),
        currentStep: 0,
        stepId: 'single:0',
        status: ExecutionJournalStatus.authorized,
        irreversible: true,
        actionSignature: actionSignature,
        verificationState: 'autorizada implícitamente por política/humano',
        timestamp: now,
      );
      try {
        await journal.save(authorizedEntry);
      } on Object catch (error) {
        return ToolOutcome(
          verdict: PolicyVerdict.denied,
          feedback:
              '[journalUnavailable] No se pudo persistir la autorización irreversible: $error.',
          executionStatus: ToolExecutionStatus.notExecuted,
        );
      }
    }

    final executingEntry = authorizedEntry.copyWith(
      status: ExecutionJournalStatus.executing,
      verificationState: 'acción reclamada; aún sin resultado',
      timestamp: DateTime.now().toUtc(),
    );

    try {
      final claimed = await journal.tryBeginIrreversible(
        executingEntry,
        allowPreviouslyUncertain: allowPreviouslyUncertain,
      );
      if (!claimed) {
        return const ToolOutcome(
          verdict: PolicyVerdict.allow,
          feedback:
              '[outcomeUnknown] Existe una ejecución no reconciliada de esta acción; no se repite automáticamente.',
          executionStatus: ToolExecutionStatus.outcomeUnknown,
        );
      }
    } on Object catch (error) {
      return ToolOutcome(
        verdict: PolicyVerdict.denied,
        feedback:
            '[journalUnavailable] Acción irreversible bloqueada antes de ejecutar: $error.',
        executionStatus: ToolExecutionStatus.notExecuted,
      );
    }
    onPhysicalEffectDispatched?.call();
    final feedback = await _executeWithTimeout(call, tool, budget);
    final status = executionStatusFor(feedback);
    final executedEntry = executingEntry.copyWith(
      status: ExecutionJournalStatus.executed,
      verificationState: 'efecto ejecutado; verificación pendiente',
      timestamp: DateTime.now().toUtc(),
    );
    final verifyingEntry = executedEntry.copyWith(
      status: ExecutionJournalStatus.verifying,
      verificationState: 'verificación en curso',
      timestamp: DateTime.now().toUtc(),
    );
    try {
      await journal.save(executedEntry);
      await journal.save(verifyingEntry);
    } on Object catch (error) {
      return ToolOutcome(
        verdict: PolicyVerdict.allow,
        feedback:
            '[outcomeUnknown] La acción pudo ejecutarse, pero no se pudo persistir su verificación ($error). No debe repetirse.',
        executionStatus: ToolExecutionStatus.outcomeUnknown,
      );
    }
    if (executionIntent != null) {
      return ToolOutcome(
        verdict: PolicyVerdict.allow,
        feedback: feedback,
        executionStatus: status,
      );
    }
    final terminalStatus = journalStatusFor(
      status,
      notExecutedAs: ExecutionJournalStatus.failed,
    );
    try {
      await journal.save(
        verifyingEntry.copyWith(
          status: terminalStatus,
          verificationState: feedback,
          timestamp: DateTime.now().toUtc(),
        ),
      );
    } on Object catch (error) {
      return ToolOutcome(
        verdict: PolicyVerdict.allow,
        feedback:
            '[outcomeUnknown] La acción pudo ejecutarse, pero no se pudo cerrar el journal ($error). No debe repetirse.',
        executionStatus: ToolExecutionStatus.outcomeUnknown,
      );
    }
    return ToolOutcome(
      verdict: PolicyVerdict.allow,
      feedback: feedback,
      executionStatus: status,
    );
  }

  /// Calcula la huella única de estado y acción para detectar ciclos repetitivos.
  Future<String> loopFingerprint(ToolCall call) async {
    final action = call.confirmationSignature;
    if (!uiStateSensitiveTools.contains(call.tool)) return action;
    final snapshot = await _executor.snapshot();
    if (snapshot == null) {
      return canonicalFingerprint({'action': action, 'state': 'unavailable'});
    }
    return canonicalFingerprint({
      'action': action,
      'state': {
        'package': snapshot.package,
        'truncated': snapshot.truncated,
        'nodes': [
          for (final node in snapshot.visibleNodes)
            '${node.windowId}:${node.id}:${node.type}:${node.text}:'
                '${node.description}:${node.bounds}',
        ],
      },
    });
  }
}
