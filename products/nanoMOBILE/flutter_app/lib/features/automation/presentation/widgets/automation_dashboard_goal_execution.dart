part of 'automation_dashboard.dart';

/// Prepara objetivos sin efectos y conserva el mismo plan al confirmar. La
/// instantánea original del chat no se sustituye por otra tomada desde Nano.
extension _DashboardGoalExecution on _AutomationDashboardState {
  Future<AutomationResult?> _runPreparedGoal(
    String command, {
    required String originalGoal,
    required String executionId,
    required bool attachmentUsed,
    required bool speakResult,
    ActionConfirmation? confirmation,
  }) async {
    bool current() =>
        mounted && !_cancelRequested && _activeExecutionId == executionId;
    AutomationResult? result;
    try {
      final prepared = confirmation != null
          ? _pendingGoal!.goal
          : await WhatsAppUiGoalPreparer(
              () => ref.read(agentExecutorProvider),
            ).prepare(command, isCurrent: current);
      if (!current()) {
        result = AutomationResult(
          executionId: executionId,
          status: AutomationResultStatus.cancelled,
          reason: 'Detenida antes de ejecutar el objetivo.',
        );
      } else {
        _pendingGoal = (
          original: originalGoal,
          command: command,
          id: executionId,
          goal: prepared,
          usesAttachment: attachmentUsed,
        );
        result = await AutomationDashboardRunner.execute(
          text: command,
          engine: _activeEngine!,
          diagnostics: ref.read(automationDiagnosticsProvider),
          confirmation: confirmation,
          executionId: executionId,
          preparedGoal: prepared,
          isCurrent: current,
        );
      }
    } on FormatException catch (error) {
      result = AutomationResult(
        executionId: executionId,
        status: AutomationResultStatus.failed,
        reason: error.message,
      );
    } on Object {
      result = AutomationResult(
        executionId: executionId,
        status: current()
            ? AutomationResultStatus.failed
            : AutomationResultStatus.cancelled,
        reason:
            'No se pudo preparar el objetivo. No se despachó ninguna acción.',
      );
    }
    if (!mounted) return result;
    if (result == null) {
      _pendingGoal = null;
      _updateExecutionState(() => _running = false);
      return null;
    }
    final outcome = result;
    if (outcome.status != AutomationResultStatus.paused) _pendingGoal = null;
    _updateExecutionState(() {
      _lastStatus = outcome.status;
      _lastReason = automationUserFacingReason(outcome.reason);
      _lastConfirmation = outcome.confirmation;
      _running = false;
      if (outcome.status == AutomationResultStatus.completed ||
          outcome.status == AutomationResultStatus.completedUnverified) {
        if (attachmentUsed) _attachment = null;
        _commandController.clear();
      }
    });
    _inputContext.finish(outcome.status, _lastReason);
    if (outcome.isPaused && outcome.confirmation != null) {
      unawaited(NanoRuntimeApi.instance.showAutomationConfirmation());
    }
    if (ref.read(settingsProvider).voiceEnabled &&
        speakResult &&
        !isDiagCommand(command)) {
      try {
        await ref
            .read(chatProvider.notifier)
            .voiceSession
            .respond(AutomationDashboardRunner.spokenResult(outcome));
      } on Object {
        // Una salida de voz fallida no cambia ni repite el resultado de envío.
      }
    }
    return outcome;
  }
}
