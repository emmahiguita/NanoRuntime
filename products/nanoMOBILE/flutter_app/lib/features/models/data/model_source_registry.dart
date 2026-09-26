// model_source_registry.dart — Registro canónico unificado de metadatos de modelos.
// QUÉ HACE: Centraliza la resolución de fuentes, licencias y benchmarks verificados por modelo.
// CÓMO FUNCIONA: Combina registros modulares (DeepSeek, Qwen, LFM, etc.) y provee búsqueda exacta y difusa.
// POR QUÉ: Asegura Clean Architecture y modularidad sin exceder el límite de 200 líneas (SOLID).
library;

import 'registry/deepseek_source_definitions.dart';
import 'registry/edge_other_definitions.dart';
import 'registry/model_source_definition.dart';
import 'registry/qwen_compact_definitions.dart';
import 'registry/qwen_heavy_definitions.dart';
import 'registry/qwen_mid_definitions.dart';

export 'registry/model_source_definition.dart';

abstract final class ModelSourceRegistry {
  static final Map<String, ModelSourceDefinition> registry = {
    ...deepseekSourceDefinitions,
    ...qwenCompactDefinitions,
    ...qwenMidDefinitions,
    ...qwenHeavyDefinitions,
    ...edgeOtherDefinitions,
  };

  /// QUÉ HACE: Resuelve los metadatos canónicos de un modelo por nombre exacto o parcial.
  /// CÓMO FUNCIONA: Busca en el mapa unificado y si no coincide, busca por coincidencia en minúsculas.
  /// POR QUÉ: Evita alucinaciones o datos falsos si el archivo no está en el catálogo oficial.
  static ModelSourceDefinition definitionFor(String name) {
    if (registry.containsKey(name)) {
      return registry[name]!;
    }
    final lower = name.toLowerCase();
    for (final entry in registry.entries) {
      if (lower.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return ModelSourceDefinition.unidentified(name);
  }
}
