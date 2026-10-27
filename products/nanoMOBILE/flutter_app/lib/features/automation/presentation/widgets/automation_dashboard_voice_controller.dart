import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/automation_result.dart';
import '../../engine/perception/current_situation.dart';
import '../../engine/voice/voice_runtime.dart';
import 'automation_dashboard_runner.dart';
import 'automation_dashboard_voice.dart';

/// Posee únicamente la interacción de voz del dashboard. La sesión compartida
/// identifica al dueño; desmontar no detiene audio iniciado por otro módulo.
class AutomationVoiceController {
  AutomationVoiceController({
    required this.voiceSession,
    required this.isRunning,
    required this.isSensing,
    required this.onFeedback,
  });
  final VoiceSessionManager voiceSession;
  final ValueGetter<bool> isRunning, isSensing;
  final ValueChanged<String?> onFeedback;
  final Object _owner = Object();
  bool conversationActive = false, _capturing = false, _disposed = false;
  int _generation = 0;

  /// Invalida callbacks al cerrar; libera solo captura/locución propias.
  void dispose() {
    _disposed = true;
    _generation++;
    conversationActive = false;
    unawaited(_release());
  }

  /// La identidad de operación impide ejecutar una orden reconocida tarde.
  bool _current(int generation) =>
      !_disposed && generation == _generation && voiceSession.isOwnedBy(_owner);

  /// Nunca cierra VoiceSessionManager: también lo utilizan Chat y otros módulos.
  Future<void> _release() async {
    if (!voiceSession.isOwnedBy(_owner)) return;
    try {
      await voiceSession.stop(owner: _owner);
    } on Object {
      // La captura del sistema tiene además su propio límite de inactividad.
    }
  }

  /// Captura una sola orden explícita y conserva su dueño hasta completarla.
  Future<void> activateVoice({
    required Future<void> Function(String goal) onGoalRecognized,
  }) async {
    if (_disposed ||
        _capturing ||
        conversationActive ||
        isRunning() ||
        isSensing()) {
      return;
    }
    final generation = ++_generation;
    _capturing = true;
    onFeedback('Escuchando una orden…');
    try {
      final turn = await voiceSession.pushToTalk(owner: _owner);
      if (!_current(generation) || turn == null) return;
      final goal = (turn.resolvedGoal ?? turn.transcript).trim();
      if (goal.isEmpty) return;
      onFeedback('Orden reconocida · ejecutando');
      await onGoalRecognized(goal);
    } on Object {
      if (_current(generation)) {
        onFeedback('No fue posible completar la captura de voz.');
      }
    } finally {
      if (generation == _generation) _capturing = false;
      await _release();
    }
  }

  /// Reutiliza el turno que devuelve respondAndListen: no lo descarta ni abre
  /// una segunda escucha que obligue al usuario a repetir su frase.
  Future<void> activateConversation({
    required Future<dynamic> Function(String transcript) onTurn,
  }) async {
    if (_disposed) return;
    if (conversationActive) {
      conversationActive = false;
      _generation++;
      await _release();
      if (!_disposed) onFeedback('Conversación detenida.');
      return;
    }
    if (_capturing || isRunning() || isSensing()) return;
    conversationActive = true;
    final generation = ++_generation;
    try {
      await voiceSession.respond(
        'Hola, soy Nano. Dime qué quieres que haga.',
        owner: _owner,
      );
      await voiceSession.waitForSpeechEnd(
        isCancelled: () => !_current(generation),
      );
      VoiceTurn? next;
      while (conversationActive && _current(generation)) {
        onFeedback('Conversación activa · habla…');
        next ??= await voiceSession.pushToTalk(owner: _owner);
        if (!_current(generation) || !conversationActive) break;
        final transcript = next?.transcript.trim() ?? '';
        if (transcript.isEmpty) break;
        final result = await onTurn(transcript);
        if (!_current(generation) ||
            !conversationActive ||
            result is! AutomationResult) {
          break;
        }
        next = await voiceSession.respondAndListen(
          AutomationDashboardRunner.spokenResult(result),
          owner: _owner,
        );
        if (next == null) break;
      }
    } on Object {
      if (_current(generation)) onFeedback('La conversación de voz se detuvo.');
    } finally {
      if (!_disposed && generation == _generation) {
        conversationActive = false;
        onFeedback(null);
      }
      await _release();
    }
  }

  /// Una lectura tardía de pantalla no publica estado después de desmontar.
  Future<void> observeScreen({
    required Future<CurrentSituation?> Function() situationSource,
  }) async {
    if (_disposed || isRunning() || isSensing()) return;
    final generation = _generation;
    onFeedback('Observando la pantalla…');
    try {
      final situation = await situationSource();
      if (_disposed || generation != _generation) return;
      onFeedback(
        situation == null
            ? 'Sin lectura de pantalla · comprueba Accesibilidad.'
            : AutomationVoiceHandler.describeSituation(situation),
      );
    } on Object {
      if (!_disposed && generation == _generation) {
        onFeedback('Lectura de pantalla no disponible.');
      }
    }
  }
}
