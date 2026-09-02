import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/model/automation_model.dart';

void main() {
  group('AutomationModelProfile', () {
    test('round-trip JSON preserva roles/flag/temperature', () {
      const p = AutomationModelProfile(
        modelId: 'qwen3-4b',
        modelPath: '/models/qwen3-4b.gguf',
        enabledForAutomation: true,
        roles: {
          AutomationModelRole.draftWriter,
          AutomationModelRole.selector,
        },
        temperature: 0.4,
      );
      final back = AutomationModelProfile.fromJson(p.toJson());
      expect(back.modelId, 'qwen3-4b');
      expect(back.modelPath, '/models/qwen3-4b.gguf');
      expect(back.enabledForAutomation, isTrue);
      expect(back.hasRole(AutomationModelRole.draftWriter), isTrue);
      expect(back.hasRole(AutomationModelRole.planner), isFalse);
      expect(back.temperature, 0.4);
    });

    test('hasRole devuelve false para rol no asignado', () {
      const p = AutomationModelProfile(
        modelId: 'x',
        modelPath: '/x.gguf',
        roles: {AutomationModelRole.summarizer},
      );
      expect(p.hasRole(AutomationModelRole.summarizer), isTrue);
      expect(p.hasRole(AutomationModelRole.draftWriter), isFalse);
    });
  });

  group('AutomationModelMode', () {
    test('names estables para persistencia', () {
      expect(AutomationModelMode.sameAsChat.name, 'sameAsChat');
      expect(AutomationModelMode.specificModel.name, 'specificModel');
      expect(AutomationModelMode.deterministicOnly.name, 'deterministicOnly');
    });
  });
}
