import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/models/catalog_models.dart';
import 'package:nanoai/features/models/data/model_source_registry.dart';
import 'package:nanoai/features/models/domain/model_viability.dart';

void main() {
  group('contrato honesto del catálogo', () {
    test('RAM ausente produce viabilidad desconocida', () {
      expect(viabilityFor(2, 0), ModelViability.unknown);
      expect(viabilityFor(0, 8), ModelViability.unknown);
    });

    test('mantiene los umbrales medibles del RuntimePlanner', () {
      expect(viabilityFor(5.6, 8), ModelViability.fast);
      expect(viabilityFor(8, 8), ModelViability.balanced);
      expect(viabilityFor(12, 8), ModelViability.streaming);
      expect(viabilityFor(17, 8), ModelViability.extreme);
    });

    test('un modelo desconocido no hereda procedencia de Qwen', () {
      final source = ModelSourceRegistry.definitionFor('archivo-propio.gguf');

      expect(source.isIdentified, isFalse);
      expect(source.id, 'archivo-propio.gguf');
      expect(source.officialRepo, isEmpty);
      expect(source.officialCapabilities, isEmpty);
    });

    test('Qwen 3.5 apunta a su repositorio oficial', () {
      expect(
        ModelSourceRegistry.definitionFor('Qwen3.5-4B').officialRepo,
        'Qwen/Qwen3.5-4B',
      );
      expect(
        ModelSourceRegistry.definitionFor('Qwen3.5-4B-Q4_K_M').officialRepo,
        'Qwen/Qwen3.5-4B',
      );
    });

    test('Ministral conserva fuente oficial sin inventar visión activa', () {
      final source = ModelSourceRegistry.definitionFor(
        'Ministral-3-3B-Instruct-2512',
      );

      expect(source.quantizedRepo, contains('mistralai/Ministral-3-3B'));
      expect(source.officialCapabilities, isEmpty);
    });

    test('Modelos LiteRT 2026 tienen URLs HTTPS y SHA-256 hexadecimal válido', () {
      final hex64 = RegExp(r'^[a-f0-9]{64}$');
      for (final entry in NeuralCatalog.models) {
        expect(entry.url, startsWith('https://huggingface.co/'));
        if (entry.backendType != ModelBackendType.mnn) {
          expect(
            hex64.hasMatch(entry.sha256.toLowerCase()),
            isTrue,
            reason: 'SHA-256 inválido en ${entry.name}',
          );
        }
      }
      final names = NeuralCatalog.models.map((m) => m.name).toSet();
      expect(names, containsAll([
        'EmbeddingGemma-2-Text-270M (LiteRT)',
        'EmbeddingGemma-2-Text-Vision-440M (LiteRT)',
        'EmbeddingGemma-2-740M-Omni (LiteRT)',
        'Gemma-4-E2B-it (LiteRT)',
        'Gemma-4-E4B-it (LiteRT)',
        'Gemma-4-12B-it GPU (LiteRT)',
        'Granite-4.1-3B (LiteRT INT4)',
        'Granite-4.2-3B (LiteRT INT4)',
        'Agents-A1-4B (LiteRT INT4)',
        'Agents-A1-4B (LiteRT INT8)',
        'Spark-X2.5-4B (LiteRT INT4)',
        'PaddleOCR-VL-1.6 (LiteRT Visión)',
        'Qwen3-ASR-0.6B (Voz Local LiteRT)',
        'Qwen3-ASR-1.7B (Voz Local LiteRT)',
        'Nemotron-3-Diarization-100M (Voz LiteRT)',
        'Audio8-TTS-Preview-0.6B (Voz LiteRT)',
      ]));
    });
  });
}
