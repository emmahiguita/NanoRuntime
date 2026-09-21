import 'package:flutter_test/flutter_test.dart';
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
  });
}
