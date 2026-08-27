/// A16 — implementaciones Android de los backends de voz (envuelven el canal
/// nativo `com.nanoai/speech`). DIP: el VoiceSessionManager solo ve interfaces.
library;

import 'package:nanoai/core/services/nano_runtime_api.dart';

import 'voice_runtime.dart';

/// STT vía Android SpeechRecognizer (offline preferido, natural).
class AndroidSpeechRecognitionBackend implements SpeechRecognitionBackend {
  const AndroidSpeechRecognitionBackend();

  @override
  Future<String?> listen({String language = 'es-ES'}) =>
      NanoRuntimeApi.instance.startVoiceRecognition(language: language);
}

/// TTS vía Android TextToSpeech (motor Google preferido, natural).
class AndroidSpeechSynthesisBackend implements SpeechSynthesisBackend {
  const AndroidSpeechSynthesisBackend();

  @override
  Future<bool> speak(String text) => NanoRuntimeApi.instance.speak(text);

  @override
  Future<void> stop() async {
    await NanoRuntimeApi.instance.stopSpeech();
  }

  @override
  Future<bool> isSpeaking() async => false; // no expuesto por el canal aún.
}
