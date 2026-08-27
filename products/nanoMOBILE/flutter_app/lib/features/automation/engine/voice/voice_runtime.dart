/// A16 — NanoVoice Runtime (fundación SOLID).
///
/// La voz es OTRA interfaz del MISMO agente (AutomationCoordinator), no un
/// segundo chat ni un segundo motor. Este archivo define:
/// - interfaces DIP (STT/TTS/wake-word);
/// - la máquina de estados de sesión conversacional;
/// - el contexto de conversación (referentes grounded, TTL acotado).
///
/// No ejecuta, no autoriza, no usa LLM. El contenido hablado es OBSERVACIÓN.
library;

import 'dart:async';

import 'execution_cancellation.dart';

/// Estado tipado de la sesión de voz (sin bool soup).
enum VoiceSessionState {
  idle,
  wakeListening,
  listening,
  processing,
  speaking,
  interrupted,
  waitingFollowUp,
  error,
}

/// Backend de reconocimiento de voz (STT). DIP: el manager no depende de
/// MethodChannel/Android.
abstract interface class SpeechRecognitionBackend {
  Future<String?> listen({String language = 'es-ES'});
}

/// Backend de síntesis de voz (TTS).
abstract interface class SpeechSynthesisBackend {
  Future<bool> speak(String text);
  Future<void> stop();
  Future<bool> isSpeaking();
}

/// Detector de wake word de bajo consumo. Solo despierta el pipeline; NUNCA
/// pasa la frase de activación como goal. Impl: AlwaysOnHotwordDetector (modelo
/// del sistema) o detector local.
abstract interface class WakeWordDetector {
  Stream<void> get wakeEvents;
  Future<void> start();
  Future<void> stop();
}

/// Contexto conversacional de corta vida (referentes grounded). TTL acotado:
/// no es vigilancia permanente.
class VoiceConversationContext {
  String? lastUtterance;
  String? lastAssistantResponse;
  String? activeGoal;

  /// Entidades recientes para resolver "respóndele", "abre esa", "el segundo".
  final Map<String, String> referents = {};

  DateTime? _touchedAt;

  void touch() => _touchedAt = DateTime.now();

  bool get isStale =>
      _touchedAt == null ||
      DateTime.now().difference(_touchedAt!) > const Duration(minutes: 10);

  void clear() {
    lastUtterance = null;
    lastAssistantResponse = null;
    activeGoal = null;
    referents.clear();
    _touchedAt = null;
  }
}

/// Resultado de una orden de voz resuelta a un goal del MISMO motor.
class VoiceTurn {
  final String transcript;
  final String? resolvedGoal;
  const VoiceTurn({required this.transcript, this.resolvedGoal});
}

/// Orquesta la sesión de voz (estado + conversación) sobre el MISMO agente.
/// `resolveGoal` convierte el transcript final en un goal del AutomationCoordinator
/// (inyectado; no usa LLM aquí). No ejecuta por sí mismo: delega al coordinador.
class VoiceSessionManager {
  VoiceSessionManager({
    required SpeechRecognitionBackend recognition,
    required SpeechSynthesisBackend synthesis,
    WakeWordDetector? wakeWord,
    required Future<String?> Function(String transcript) resolveGoal,
    this.followUpWindow = const Duration(seconds: 8),
    this.listenTimeout = const Duration(seconds: 15),
  }) : _recognition = recognition,
       _synthesis = synthesis,
       _wakeWord = wakeWord,
       _resolveGoal = resolveGoal;

  final SpeechRecognitionBackend _recognition;
  final SpeechSynthesisBackend _synthesis;
  final WakeWordDetector? _wakeWord;
  final Future<String?> Function(String transcript) _resolveGoal;
  final Duration followUpWindow;

  /// Timeout defensivo de escucha: si el reconocedor no devuelve (se cuelga),
  /// se aborta el turno en vez de quedar escuchando indefinidamente.
  final Duration listenTimeout;

  final _stateController = StreamController<VoiceSessionState>.broadcast();
  final VoiceConversationContext context = VoiceConversationContext();

  Stream<VoiceSessionState> get states => _stateController.stream;
  VoiceSessionState _state = VoiceSessionState.idle;
  VoiceSessionState get state => _state;
  void _set(VoiceSessionState s) {
    _state = s;
    _stateController.add(s);
  }

  /// Push-to-talk: escucha UNA vez, resuelve y devuelve el turno (sin hablar).
  /// Si Nano estaba hablando, interrumpe primero (barge-in cooperativo).
  Future<VoiceTurn?> pushToTalk() async {
    if (_state == VoiceSessionState.speaking) {
      await bargeIn();
    }
    _set(VoiceSessionState.listening);
    final sw = Stopwatch()..start();
    final String? transcript;
    try {
      transcript = await _recognition.listen().timeout(
        listenTimeout,
        onTimeout: () => null,
      );
    } on ExecutionCancelled {
      _set(VoiceSessionState.idle);
      return null;
    }
    sw.stop();
    sttLatencyMs = sw.elapsedMilliseconds;
    if (transcript == null || transcript.trim().isEmpty) {
      _set(VoiceSessionState.idle);
      return null;
    }
    _set(VoiceSessionState.processing);
    final goal = await _resolveGoal(transcript);
    context.lastUtterance = transcript;
    context.activeGoal = goal;
    context.touch();
    _set(VoiceSessionState.idle);
    return VoiceTurn(transcript: transcript, resolvedGoal: goal);
  }

  /// Habla una respuesta y queda escuchando follow-up (bounded).
  Future<void> respond(String text) async {
    _set(VoiceSessionState.speaking);
    final sw = Stopwatch()..start();
    await _synthesis.speak(text);
    sw.stop();
    ttsLatencyMs = sw.elapsedMilliseconds;
    context.lastAssistantResponse = text;
    context.touch();
    _set(VoiceSessionState.waitingFollowUp);
    Future.delayed(followUpWindow, () {
      if (_state == VoiceSessionState.waitingFollowUp) {
        _set(VoiceSessionState.idle);
      }
    });
  }

  /// A16 — telemetría de voz (sección 19): latencias observadas de STT/TTS.
  int sttLatencyMs = 0;
  int ttsLatencyMs = 0;

  /// Barge-in: el usuario interrumpe la respuesta en curso.
  Future<void> bargeIn() async {
    if (_state == VoiceSessionState.speaking) {
      await _synthesis.stop();
      _set(VoiceSessionState.interrupted);
    }
  }

  // ── Ciclo de vida (start/stop + modo asistente) ──────────────────────────

  /// true si la sesión no está idle.
  bool get isActive => _state != VoiceSessionState.idle;

  bool _assistantMode = false;
  bool get isAssistantMode => _assistantMode;

  /// Inicia la sesión de voz (push-to-talk): deja al manager listo para
  /// [pushToTalk]. Idempotente.
  Future<void> start() async {
    if (_state == VoiceSessionState.idle) {
      _set(VoiceSessionState.wakeListening);
    }
  }

  /// Detiene la sesión por completo: interrumpe habla, apaga síntesis y vuelve
  /// a idle. No cierra el stream (reutilizable entre turnos).
  Future<void> stop() async {
    await bargeIn();
    await _synthesis.stop();
    _set(VoiceSessionState.idle);
  }

  /// Modo asistente: activa el wake word (si hay detector) para escucha pasiva.
  Future<void> startAssistant() async {
    _assistantMode = true;
    await _wakeWord?.start();
  }

  /// Detiene el modo asistente: apaga el wake word y detiene la sesión.
  Future<void> stopAssistant() async {
    _assistantMode = false;
    await _wakeWord?.stop();
    await stop();
  }

  Future<void> dispose() async {
    await _stateController.close();
    await _wakeWord?.stop();
  }
}
