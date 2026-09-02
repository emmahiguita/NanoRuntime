import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/performance/memory_budget.dart';

void main() {
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
