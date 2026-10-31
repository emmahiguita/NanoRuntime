// QUÉ: ejecuta la orden escrita usando los motores y políticas existentes.
// CÓMO: prioriza diagnóstico, luego herramientas y finalmente objetivos.
// POR QUÉ: @diag no debe confundirse con una herramienta desconocida.
part of 'automation_dashboard.dart';

extension _AutomationDashboardExecution on _AutomationDashboardState {
  // Detener conserva el dueño de la ejecución y también cubre la precondición.
  void _stopActiveTask() {
    _cancelRequested = true;
    _pendingGoal = null;
    _lastConfirmation = null;
    final id = _activeExecutionId;
    if (id != null) _activeEngine?.cancelExecution(id);
  }

  // Solo reconstruye cuando cambian los datos visibles, no por cada carácter.
  void _refreshInputContext() => _updateExecutionState(() {});

  Future<AutomationResult?> _runTask(
    String text, {
    ActionConfirmation? confirmation,
    bool fromVoice = false,
    bool speakResult = true,
  }) async {
    if (!mounted) return null;
    final goal = text.trim();
    if (goal.isEmpty) return null;
    if (WhatsAppComponentRequests.isCancel(goal)) {
      _stopActiveTask();
      if (!_running) {
        _updateExecutionState(() {
          _lastStatus = AutomationResultStatus.cancelled;
          _lastReason = 'Tarea pendiente descartada.';
        });
        _inputContext.finish(AutomationResultStatus.cancelled, _lastReason);
      }
      return null;
    }
    if (_running) return null;
    if (confirmation == null && WhatsAppComponentRequests.isConfirm(goal)) {
      final pending = _lastConfirmation;
      if (pending != null && !pending.expired && !pending.consumed) {
        return _runTask(
          _lastGoal,
          confirmation: pending,
          speakResult: speakResult,
        );
      }
      _updateExecutionState(() {
        _lastStatus = AutomationResultStatus.failed;
        _lastReason = 'No hay una confirmación pendiente vigente.';
      });
      return null;
    }
    if (confirmation == null) {
      _pendingGoal = null;
      _lastConfirmation = null;
    }
    final String command;
    var attachmentUsed = false;
    var preparedGoal = goal;
    try {
      if (confirmation != null) {
        final pending = _pendingGoal;
        if (pending == null ||
            pending.original != goal ||
            pending.id != confirmation.executionId) {
          throw const FormatException(
            'La tarea pendiente cambió. Escribe de nuevo la instrucción.',
          );
        }
        command = pending.command;
        attachmentUsed = pending.usesAttachment;
        preparedGoal = command;
      } else {
        final prepared = prepareAutomationDraft(goal, _attachment);
        preparedGoal = prepared.goal;
        attachmentUsed = prepared.usesAttachment;
        if (attachmentUsed && !_inputContext.selected) {
          throw const FormatException(
            'Activa WhatsApp desde + → Complementos para compartir el adjunto.',
          );
        }
        command = _inputContext.commandFor(preparedGoal);
      }
    } on FormatException catch (error) {
      _updateExecutionState(() {
        _lastGoal = goal;
        _lastStatus = AutomationResultStatus.failed;
        _lastReason = error.message;
      });
      return null;
    }
    final executionId = confirmation?.executionId ?? 'dash-${UniqueKey()}';
    _activeEngine = ref.read(automationEngineProvider);
    _activeExecutionId = executionId;
    _cancelRequested = false;
    _inputContext.begin(executionId, preparedGoal);
    _updateExecutionState(() {
      _running = true;
      _lastGoal = goal;
      _lastStatus = null;
      _lastReason = '';
    });

    if (AutomationAccessController.requiresAccessibility(command)) {
      final ready = await _access.refresh();
      if (!mounted) return null;
      if (!ready || _cancelRequested) {
        final status = _cancelRequested
            ? AutomationResultStatus.cancelled
            : AutomationResultStatus.denied;
        final reason = _cancelRequested
            ? 'Ejecución cancelada antes del envío.'
            : 'Activa la accesibilidad de Nano en Android. No se inició el envío.';
        setState(() {
          _running = false;
          _lastStatus = status;
          _lastReason = reason;
        });
        _inputContext.finish(status, reason);
        AutomationActivityStore.instance.record(
          runId: executionId,
          route: 'Automatización → comprobación de accesibilidad',
          state: status.name,
          detail: reason,
        );
        return null;
      }
    }

    // Los comandos explícitos deben ir al router de herramientas; como objetivos,
    // el planner intentaba interpretarlos como tareas normales y no ejecutaba MCP.
    // El diagnóstico interno tiene prioridad sobre el router genérico de @.
    if (!isDiagCommand(command) && AgentToolDispatcher.isToolCommand(command)) {
      try {
        final feedback = await _activeEngine!.runCommand(
          command,
          executionId: executionId,
        );
        if (!mounted) return null;
        setState(() {
          _lastStatus = AutomationCommandFeedback.statusFor(feedback);
          _lastReason = AutomationCommandFeedback.displayReason(feedback);
          _lastConfirmation = null;
          _running = false;
          if (_lastStatus == AutomationResultStatus.completed ||
              _lastStatus == AutomationResultStatus.completedUnverified) {
            if (attachmentUsed) _attachment = null;
            _commandController.clear();
          }
        });
      } on Object {
        if (!mounted) return null;
        setState(() {
          _lastStatus = AutomationResultStatus.outcomeUnknown;
          _lastReason =
              'No se recibió un resultado final. Revisa la app antes de repetir.';
          _lastConfirmation = null;
          _running = false;
        });
      }
      if (mounted) _inputContext.finish(_lastStatus, _lastReason);
      return null;
    }

    return _runPreparedGoal(
      command,
      originalGoal: goal,
      executionId: executionId,
      confirmation: confirmation,
      attachmentUsed: attachmentUsed,
      speakResult: speakResult,
    );
  }
}
