// QUÉ: ejecuta la orden escrita usando los motores y políticas existentes.
// CÓMO: prioriza diagnóstico, luego herramientas y finalmente objetivos.
// POR QUÉ: @diag no debe confundirse con una herramienta desconocida.
part of 'automation_dashboard.dart';

extension _AutomationDashboardExecution on _AutomationDashboardState {
  Future<AutomationResult?> _runTask(
    String text, {
    ActionConfirmation? confirmation,
    bool fromVoice = false,
    bool speakResult = true,
  }) async {
    final goal = text.trim();
    if (goal.isEmpty || _running) return null;
    final executionId = confirmation?.executionId ?? 'dash-${UniqueKey()}';
    _activeEngine = ref.read(automationEngineProvider);
    _activeExecutionId = executionId;
    _updateExecutionState(() {
      _running = true;
      _lastGoal = goal;
      _lastStatus = null;
      _lastReason = '';
    });

    // Los comandos explícitos deben ir al router de herramientas; como objetivos,
    // el planner intentaba interpretarlos como tareas normales y no ejecutaba MCP.
    // El diagnóstico interno tiene prioridad sobre el router genérico de @.
    if (!isDiagCommand(goal) && AgentToolDispatcher.isToolCommand(goal)) {
      try {
        final feedback = await _activeEngine!.runCommand(goal);
        if (!mounted) return null;
        setState(() {
          _lastStatus = AutomationCommandFeedback.statusFor(feedback);
          _lastReason = feedback;
          _lastConfirmation = null;
          _running = false;
        });
      } on Object catch (error) {
        if (!mounted) return null;
        setState(() {
          _lastStatus = AutomationResultStatus.failed;
          _lastReason =
              'No se pudo ejecutar el comando de Automatización (${error.runtimeType}).';
          _lastConfirmation = null;
          _running = false;
        });
      }
      return null;
    }

    final result = await AutomationDashboardRunner.execute(
      text: goal,
      engine: _activeEngine!,
      diagnostics: ref.read(automationDiagnosticsProvider),
      confirmation: confirmation,
      executionId: executionId,
    );

    if (mounted && result != null) {
      setState(() {
        _lastStatus = result.status;
        _lastReason = automationUserFacingReason(result.reason);
        _lastConfirmation = result.confirmation;
        _running = false;
      });
      if (result.status == AutomationResultStatus.paused &&
          result.confirmation != null) {
        unawaited(NanoRuntimeApi.instance.showAutomationConfirmation());
      }
      if (ref.read(settingsProvider).voiceEnabled &&
          speakResult &&
          !isDiagCommand(goal)) {
        await ref
            .read(chatProvider.notifier)
            .voiceSession
            .respond(AutomationDashboardRunner.spokenResult(result));
      }
    }
    return result;
  }
}
