import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/models/catalog_models.dart';
import 'package:nanoai/core/models/chat_models.dart';
import 'package:nanoai/features/automation/engine/model/automation_model.dart';
import 'package:nanoai/features/models/data/catalog_local_model_repository.dart';

void main() {
  group('Multi-Mobile Model Catalog Injection', () {
    const requiredModels = [
      'LFM2.5-1.2B-Instruct-Q4_0-QAD',
      'Qwen3.5-2B-Q4_K_M',
      'LFM2.5-1.2B-Thinking',
      'LFM2.5-2.6B-Q4_0-QAD',
      'Gemma-3n-E2B-IT',
    ];

    test('NeuralCatalog contains all 5 specialized mobile models', () {
      final names = NeuralCatalog.models.map((m) => m.name).toSet();
      for (final model in requiredModels) {
        expect(names, contains(model), reason: 'Model $model not found in catalog');
      }
    });

    test('each injected model has valid HuggingFace resolve URL and exact 64-char SHA256', () {
      for (final modelName in requiredModels) {
        final entry = NeuralCatalog.entryOf(modelName);
        expect(entry.name, equals(modelName));
        expect(entry.url, startsWith('https://huggingface.co/'));
        expect(entry.url, contains('/resolve/main/'));
        expect(entry.file, endsWith('.gguf'));
        expect(entry.sha256.length, equals(64), reason: 'Invalid SHA256 length for $modelName');
        expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(entry.sha256), isTrue,
            reason: 'SHA256 must be hex lowercase for $modelName');
        expect(entry.sizeGb, greaterThan(0.5));
        expect(entry.ramGb, greaterThan(0.5));
      }
    });

    test('chat template resolves accurately for LFM and Gemma families', () {
      expect(NeuralCatalog.templateOf('LFM2.5-1.2B-Instruct-Q4_0-QAD'), equals(ChatTemplate.qwen));
      expect(NeuralCatalog.templateOf('Qwen3.5-2B-Q4_K_M'), equals(ChatTemplate.qwen));
      expect(NeuralCatalog.templateOf('LFM2.5-1.2B-Thinking'), equals(ChatTemplate.qwen));
      expect(NeuralCatalog.templateOf('LFM2.5-2.6B-Q4_0-QAD'), equals(ChatTemplate.qwen));
      expect(NeuralCatalog.templateOf('Gemma-3n-E2B-IT'), equals(ChatTemplate.gemma));
    });

    test('AutomationTierPresets correctly configure mobile hardware profiles', () {
      expect(AutomationTierPresets.tiers.length, equals(3));

      // 4GB lightweight tier
      final tier4 = AutomationTierPresets.lightweight4Gb;
      expect(tier4.recommendedModel, equals('LFM2.5-1.2B-Instruct-Q4_0-QAD'));
      expect(tier4.estimatedRamGb, lessThanOrEqualTo(1.5));
      expect(tier4.roles, contains(AutomationModelRole.draftWriter));

      // 6GB - 8GB balanced tier
      final tier6to8 = AutomationTierPresets.balanced6to8Gb;
      expect(tier6to8.recommendedModel, equals('Qwen3.5-2B-Q4_K_M'));
      expect(tier6to8.reasoningModel, equals('LFM2.5-1.2B-Thinking'));
      expect(tier6to8.roles, contains(AutomationModelRole.reasoning));

      // 12GB advanced tier
      final tier12 = AutomationTierPresets.advanced12Gb;
      expect(tier12.recommendedModel, equals('LFM2.5-2.6B-Q4_0-QAD'));
      expect(tier12.visionModel, equals('Gemma-3n-E2B-IT'));
      expect(tier12.roles, contains(AutomationModelRole.planner));
      expect(tier12.roles, contains(AutomationModelRole.vision));
    });
  });
}
