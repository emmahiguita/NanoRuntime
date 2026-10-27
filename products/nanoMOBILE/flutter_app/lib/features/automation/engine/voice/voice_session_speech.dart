part of 'voice_runtime.dart';

/// Síntesis y espera separadas del propietario de sesión; conserva su API.
extension _VoiceSessionSpeech on VoiceSessionManager {
  /// Publica respuesta/temporizador solo si su operación sigue vigente.
  Future<void> _respondOwned(String text, int revision) async {
    if (_disposed || text.trim().isEmpty) return;
    _followUpTimer?.cancel();
    _set(VoiceSessionState.speaking);
    final sw = Stopwatch()..start();
    final bool spoken;
    try {
      spoken = await _synthesis.speak(text);
    } catch (_) {
      sw.stop();
      ttsLatencyMs = sw.elapsedMilliseconds;
      if (revision == _revision) _set(VoiceSessionState.idle);
      return;
    }
    if (_disposed || revision != _revision) return;
    sw.stop();
    ttsLatencyMs = sw.elapsedMilliseconds;
    if (!spoken) {
      _set(VoiceSessionState.idle);
      return;
    }
    context.lastAssistantResponse = text;
    context.touch();
    _set(VoiceSessionState.waitingFollowUp);
    _followUpTimer = Timer(followUpWindow, () {
      if (!_disposed &&
          revision == _revision &&
          _state == VoiceSessionState.waitingFollowUp) {
        _set(VoiceSessionState.idle);
      }
    });
  }

  /// Espera fin de audio con plazo y cancelación explícita, sin nueva escucha.
  Future<void> _waitForSpeechEnd({
    Duration timeout = const Duration(seconds: 30),
    bool Function()? isCancelled,
  }) async {
    final deadline = DateTime.now().add(timeout);
    var silentSamples = 0;
    while (silentSamples < 2) {
      if (_disposed || (isCancelled?.call() ?? false)) return;
      if (DateTime.now().isAfter(deadline)) {
        await _synthesis.stop();
        return;
      }
      if (await _synthesis.isSpeaking()) {
        silentSamples = 0;
      } else {
        silentSamples++;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  /// Devuelve el siguiente turno al mismo dueño y descarta resultados sustituidos.
  Future<VoiceTurn?> _respondAndListenOwned(
    String text, {
    Object? owner,
  }) async {
    if (_disposed || text.trim().isEmpty) return null;
    await respond(text, owner: owner);
    if (_disposed ||
        (owner != null && !isOwnedBy(owner)) ||
        _state != VoiceSessionState.waitingFollowUp) {
      return null;
    }
    // Espera el fin REAL de la locución (el canal reporta isSpeaking).
    // Bounded: si el motor nunca reporta fin (fallo del canal), se detiene
    // el TTS y se aborta el turno — fail honesto, sin espera infinita.
    // Comparte la espera con waitForSpeechEnd (DRY): la única diferencia es
    // la cancelación cuando la sesión deja de esperar follow-up.
    await waitForSpeechEnd(
      isCancelled: () =>
          (owner != null && !isOwnedBy(owner)) ||
          _state != VoiceSessionState.waitingFollowUp,
    );
    if (_disposed ||
        (owner != null && !isOwnedBy(owner)) ||
        _state != VoiceSessionState.waitingFollowUp) {
      return null;
    }
    return pushToTalk(owner: owner);
  }

  /// Una interrupción tardía no cambia el estado de un nuevo propietario.
  Future<void> _bargeInOwned(int revision) async {
    if (_state == VoiceSessionState.speaking) {
      await _synthesis.stop();
      if (revision == _revision) _set(VoiceSessionState.interrupted);
    }
  }
}
