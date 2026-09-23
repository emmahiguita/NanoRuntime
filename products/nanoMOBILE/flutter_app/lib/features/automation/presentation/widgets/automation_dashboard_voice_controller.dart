/// AUTOMATION-DASHBOARD-VOICE-CONTROLLER — Controlador de voz y conversación.
///
/// QUÉ HACE:
/// Gestiona la escucha por micrófono, conversación manos libres y ojos de pantalla.
///
/// CÓMO FUNCIONA:
/// Coordina la sesión con [VoiceSessionManager] y [CurrentSituation].
///
/// POR QUÉ:
/// Mantiene `automation_dashboard.dart` bajo el límite estricto de 200 líneas.
library;

import 'package:flutter/foundation.dart';
import '../../engine/perception/current_situation.dart';
import '../../engine/voice/voice_runtime.dart';
import 'automation_dashboard_runner.dart';
import 'automation_dashboard_voice.dart';

class AutomationVoiceController {
  final VoiceSessionManager voiceSession;
  final ValueGetter<bool> isRunning;
  final ValueGetter<bool> isSensing;
  final ValueChanged<String?> onFeedback;

  bool conversationActive = false;

  AutomationVoiceController({
    required this.voiceSession,
    required this.isRunning,
    required this.isSensing,
    required this.onFeedback,
  });

  Future<void> activateVoice({
    required Future<void> Function(String goal) onGoalRecognized,
  }) async {
    if (isRunning() || isSensing()) return;
    onFeedback('Escuchando una orden…');
    try {
      final turn = await voiceSession.pushToTalk();
      if (turn == null) return;
      final goal = (turn.resolvedGoal ?? turn.transcript).trim();
      if (goal.isEmpty) return;
      onFeedback('Orden reconocida · ejecutando');
      await onGoalRecognized(goal);
    } catch (_) {
      onFeedback('No fue posible iniciar el micrófono.');
    }
  }

  Future<void> activateConversation({
    required Future<dynamic> Function(String transcript) onTurn,
  }) async {
    if (conversationActive) {
      conversationActive = false;
      await voiceSession.stop();
      onFeedback('Conversación detenida.');
      return;
    }
    if (isRunning()) return;
    conversationActive = true;
    try {
      await voiceSession.respond('Hola, soy Nano. Dime qué quieres que haga.');
      await voiceSession.waitForSpeechEnd();
      while (conversationActive) {
        onFeedback('Conversación activa · habla…');
        final turn = await voiceSession.pushToTalk();
        if (!conversationActive) break;
        final transcript = turn?.transcript.trim() ?? '';
        if (transcript.isEmpty) break;
        final result = await onTurn(transcript);
        if (!conversationActive || result == null) break;
        await voiceSession.respondAndListen(AutomationDashboardRunner.spokenResult(result));
      }
    } finally {
      conversationActive = false;
      onFeedback(null);
    }
  }

  Future<void> observeScreen({
    required Future<CurrentSituation?> Function() situationSource,
  }) async {
    if (isRunning() || isSensing()) return;
    onFeedback('Observando la pantalla…');
    try {
      final situation = await situationSource();
      onFeedback(
        situation == null
            ? 'Sin lectura de pantalla · comprueba Accesibilidad.'
            : AutomationVoiceHandler.describeSituation(situation),
      );
    } catch (_) {
      onFeedback('Ojos no disponibles.');
    }
  }
}
