import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/voice/voice_runtime.dart';

void main() {
  test('timeout cancela el reconocedor real', () async {
    final recognition = _BlockingRecognition();
    final manager = VoiceSessionManager(
      recognition: recognition,
      synthesis: _SilentSynthesis(),
      resolveGoal: (text) async => text,
      listenTimeout: const Duration(milliseconds: 10),
    );

    expect(await manager.pushToTalk(), isNull);
    expect(recognition.cancelled, isTrue);
    expect(manager.state, VoiceSessionState.idle);
    await manager.dispose();
  });

  test('stop durante escucha libera ASR y completa el turno', () async {
    final recognition = _BlockingRecognition();
    final manager = VoiceSessionManager(
      recognition: recognition,
      synthesis: _SilentSynthesis(),
      resolveGoal: (text) async => text,
      listenTimeout: const Duration(seconds: 5),
    );

    final turn = manager.pushToTalk();
    await recognition.started.future;
    await manager.stop();

    expect(recognition.cancelled, isTrue);
    expect(await turn, isNull);
    expect(manager.state, VoiceSessionState.idle);
    await manager.dispose();
  });
}

class _BlockingRecognition implements SpeechRecognitionBackend {
  final started = Completer<void>();
  final _result = Completer<String?>();
  bool cancelled = false;

  @override
  Future<String?> listen({String language = 'es-ES'}) {
    if (!started.isCompleted) started.complete();
    return _result.future;
  }

  @override
  Future<void> cancel() async {
    cancelled = true;
    if (!_result.isCompleted) _result.complete(null);
  }
}

class _SilentSynthesis implements SpeechSynthesisBackend {
  @override
  Future<bool> isSpeaking() async => false;

  @override
  Future<bool> speak(String text) async => true;

  @override
  Future<void> stop() async {}
}
