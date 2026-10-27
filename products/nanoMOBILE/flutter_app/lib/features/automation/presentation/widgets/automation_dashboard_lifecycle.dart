part of 'automation_dashboard.dart';

/// Suscripciones con el mismo propietario que la pantalla; sin temporizadores
/// de permisos. El borrador persiste al reducir la barra y se libera al salir.
extension _AutomationDashboardLifecycle on _AutomationDashboardState {
  void _initializeDashboard() {
    _access.addListener(_refreshInputContext);
    unawaited(_access.refresh());
    _inputContext.addListener(_refreshInputContext);
    final vs = ref.read(chatProvider.notifier).voiceSession;
    _voiceCtrl = AutomationVoiceController(
      voiceSession: vs,
      isRunning: () => _running,
      isSensing: () =>
          vs.state == VoiceSessionState.listening ||
          vs.state == VoiceSessionState.processing,
      onFeedback: (fb) {
        if (mounted) setState(() {});
      },
    );
    _voiceSub = vs.states.listen((_) {
      if (mounted) setState(() {});
    });
    _confirmSub = NanoRuntimeApi.instance.automationConfirmationActions.listen((
      action,
    ) {
      if (action == 'cancel' && mounted) {
        _stopActiveTask();
        _updateExecutionState(() {
          _lastStatus = AutomationResultStatus.cancelled;
          _lastReason = 'Tarea pendiente descartada.';
        });
        _inputContext.finish(AutomationResultStatus.cancelled, _lastReason);
      }
      if (action == 'confirm' &&
          mounted &&
          !_running &&
          _lastConfirmation != null) {
        unawaited(_runTask(_lastGoal, confirmation: _lastConfirmation));
      }
    });
  }
}
