// model_source_definition.dart — Entidad de definición de fuente y metadatos verificados.
// QUÉ HACE: Modela la procedencia oficial, benchmarks y capacidades de un modelo neural.
// CÓMO FUNCIONA: Clase inmutable con atributos tipados y constructor factory para no identificados.
// POR QUÉ: Desacopla la definición del registro en colecciones modulares (< 200 líneas).
library;

import '../../domain/model_metadata_entities.dart';

class ModelSourceDefinition {
  final String id;
  final String officialRepo;
  final String quantizedRepo;
  final String developerName;
  final String baseArchitecture;
  final String officialLicense;
  final int officialContext;
  final int officialVocab;
  final double officialParams;
  final String quantizationSource;
  final List<VerifiedBenchmark> officialBenchmarks;
  final List<VerifiedCapability> officialCapabilities;
  final String story;

  const ModelSourceDefinition({
    required this.id,
    required this.officialRepo,
    required this.quantizedRepo,
    required this.developerName,
    required this.baseArchitecture,
    required this.officialLicense,
    required this.officialContext,
    required this.officialVocab,
    required this.officialParams,
    required this.quantizationSource,
    required this.officialBenchmarks,
    required this.officialCapabilities,
    required this.story,
  });

  bool get isIdentified => officialRepo.isNotEmpty;

  factory ModelSourceDefinition.unidentified(String id) => ModelSourceDefinition(
    id: id,
    officialRepo: '',
    quantizedRepo: '',
    developerName: 'Origen no identificado',
    baseArchitecture: 'No verificada',
    officialLicense: 'No verificada',
    officialContext: 0,
    officialVocab: 0,
    officialParams: 0,
    quantizationSource: 'No verificada',
    officialBenchmarks: const [],
    officialCapabilities: const [],
    story: 'Nano no encontró una fuente canónica para este archivo.',
  );
}
