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

import 'package:flutter/foundation.dart' show debugPrint;

import 'conversation/conversational_world_state.dart';
import 'conversation/grounding_resolver.dart';
import 'execution_cancellation.dart';

part 'voice_session_manager.dart';
part 'voice_session_speech.dart';
part 'voice_session_lifecycle.dart';

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
  Future<void> cancel();
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
