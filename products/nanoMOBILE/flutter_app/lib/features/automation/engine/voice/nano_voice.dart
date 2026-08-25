/// NanoVoice (A15) — capa de voz separada del automation core.
///
/// Flujo: mic → STT → user goal → automation → verified result → respuesta
/// natural → TTS. REGLA DE HONESTIDAD: NO anunciar éxito ("Hecho") hasta que el
/// resultado esté VERIFICADO (GoalVerifier satisfied). Los backends STT/TTS son
/// futuros (contratos aquí, sin implementación concreta en A15).
library;

import '../../domain/automation_result.dart';

abstract interface class SpeechToText {
  /// mic → texto del goal. null/empty si no se entendió.
  Future<String?> listen();
}

abstract interface class TextToSpeech {
  Future<void> speak(String text);
}

/// Orquesta un ciclo de voz: STT → goal → automation → verified → TTS.
class VoiceSessionManager {
  VoiceSessionManager({
    required SpeechToText stt,
    required TextToSpeech tts,
    required Future<AutomationResult> Function(String goal) execute,
  }) : _stt = stt,
       _tts = tts,
       _execute = execute;

  final SpeechToText _stt;
  final TextToSpeech _tts;
  final Future<AutomationResult> Function(String goal) _execute;

  /// Ejecuta un ciclo completo. Devuelve la respuesta hablada (para tests/log).
  Future<String> run() async {
    final goal = await _stt.listen();
    if (goal == null || goal.trim().isEmpty) {
      return 'no entendí';
    }
    final result = await _execute(goal);

    // Honestidad: solo éxito VERIFICADO se anuncia como éxito.
    if (result.isVerifiedSuccess) {
      final response = 'Hecho: $goal';
      await _tts.speak(response);
      return response;
    }
    final response = 'No pude completar "$goal": ${result.reason}';
    await _tts.speak(response);
    return response;
  }
}
