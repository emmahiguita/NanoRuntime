part of 'voice_runtime.dart';

/// Ciclo de vida de la sesión compartida, separado de captura y síntesis.
extension _VoiceSessionLifecycle on VoiceSessionManager {
  /// Prepara la escucha sin iniciar captura permanente.
  Future<void> _startSession() async {
    if (_state == VoiceSessionState.idle) {
      _set(VoiceSessionState.wakeListening);
    }
  }

  /// Detiene recursos solo si el dueño coincide; invalida callbacks antes de esperar.
  Future<void> _stopSession({Object? owner}) async {
    if (owner != null && !isOwnedBy(owner)) return;
    final revision = _claim(null);
    _followUpTimer?.cancel();
    try {
      if (_state == VoiceSessionState.listening) {
        await _recognition.cancel();
      } else if (_state == VoiceSessionState.speaking) {
        await _synthesis.stop();
      } else {
        await _synthesis.stop();
      }
    } finally {
      if (revision == _revision) _set(VoiceSessionState.idle);
    }
  }

  /// Activa únicamente el detector wake-word existente.
  Future<void> _startAssistant() async {
    _assistantMode = true;
    await _wakeWord?.start();
  }

  /// Detiene el modo asistente por solicitud explícita del propietario global.
  Future<void> _stopAssistant() async {
    _assistantMode = false;
    await _wakeWord?.stop();
    await stop();
  }

  /// Libera la sesión global y cierra su stream; no se usa al salir del dashboard.
  Future<void> _disposeSession() async {
    if (_disposed) return;
    _claim(null);
    _followUpTimer?.cancel();
    try {
      await _wakeWord?.stop();
      await _recognition.cancel();
      await _synthesis.stop();
    } finally {
      _state = VoiceSessionState.idle;
      _disposed = true;
      await _stateController.close();
    }
  }
}
