import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/domain/automation_result.dart';
import 'package:nanoai/features/automation/engine/performance/memory_budget.dart';
import 'package:nanoai/features/automation/engine/voice/nano_voice.dart';

class _FakeStt implements SpeechToText {
  _FakeStt(this.result);
  String? result;

  @override
  Future<String?> listen() async => result;
}

class _FakeTts implements TextToSpeech {
  final List<String> spoken = [];

  @override
  Future<void> speak(String text) async => spoken.add(text);
}

void main() {
  group('VoiceSessionManager', () {
    test('STT → goal → verified → TTS anuncia éxito', () async {
      final tts = _FakeTts();
      final session = VoiceSessionManager(
        stt: _FakeStt('abre Chrome'),
        tts: tts,
        execute: (goal) async => const AutomationResult(
          executionId: 'x',
          status: AutomationResultStatus.completed,
          reason: 'ok',
        ),
      );
      final response = await session.run();
      expect(response, 'Hecho: abre Chrome');
      expect(tts.spoken, ['Hecho: abre Chrome']);
    });

    test('NO anuncia éxito si no está verificado (honestidad)', () async {
      final tts = _FakeTts();
      final session = VoiceSessionManager(
        stt: _FakeStt('activa Bluetooth'),
        tts: tts,
        execute: (goal) async => const AutomationResult(
          executionId: 'x',
          status: AutomationResultStatus.completedUnverified,
          reason: 'sin expectativa verificable',
        ),
      );
      final response = await session.run();
      expect(response, contains('No pude completar'));
      expect(tts.spoken.single, contains('No pude completar'));
      expect(tts.spoken.single, isNot(contains('Hecho')));
    });

    test('STT vacío → "no entendí" (sin ejecutar ni TTS éxito)', () async {
      final tts = _FakeTts();
      final session = VoiceSessionManager(
        stt: _FakeStt(''),
        tts: tts,
        execute: (goal) async => const AutomationResult(
          executionId: 'x',
          status: AutomationResultStatus.completed,
          reason: 'ok',
        ),
      );
      final response = await session.run();
      expect(response, 'no entendí');
      expect(tts.spoken, isEmpty);
    });
  });

  group('MemoryBudget', () {
    test('default: LLM hot, VLM/STT/TTS cold (automatización sin Vision)', () {
      const budget = MemoryBudget.defaultBudget;
      expect(budget.isResident(ModelComponent.llm), isTrue);
      expect(budget.isResident(ModelComponent.vlm), isFalse);
      expect(budget.isResident(ModelComponent.stt), isFalse);
      expect(budget.isResident(ModelComponent.tts), isFalse);
      expect(budget.isWarm(ModelComponent.ocr), isTrue);
      expect(budget.stateOf(ModelComponent.vlm), ResidencyState.cold);
    });

    test('componente desconocido → cold (conservador)', () {
      const budget = MemoryBudget({});
      expect(budget.stateOf(ModelComponent.vlm), ResidencyState.cold);
      expect(budget.isResident(ModelComponent.vlm), isFalse);
    });
  });
}
