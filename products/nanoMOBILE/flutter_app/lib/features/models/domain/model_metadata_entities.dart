/// Entidades de dominio para trazabilidad, procedencia y metadata verificada de modelos.
library;

enum ModelDataProvenance {
  /// Procedente de la documentación / Model Card oficial del desarrollador original.
  official,

  /// Procedente de la API / metadata estructurada de Hugging Face Hub.
  huggingFace,

  /// Procedente del creador de la cuantización / archivo GGUF (Unsloth, Bartowski, etc.).
  quantization,

  /// Medición real realizada localmente en este dispositivo por NanoAI (RAM / velocidad).
  localMeasured,

  /// Cálculo o estimación teórica de NanoRuntime.
  estimated,

  /// Dato no publicado o no disponible en la fuente.
  unavailable,
}

class ModelSource {
  final String label;
  final String url;
  final ModelDataProvenance provenance;

  const ModelSource({
    required this.label,
    required this.url,
    required this.provenance,
  });

  Uri get uri => Uri.parse(url);

  Map<String, dynamic> toJson() => {
    'label': label,
    'url': url,
    'provenance': provenance.name,
  };

  factory ModelSource.fromJson(Map<String, dynamic> json) => ModelSource(
    label: json['label'] as String? ?? '',
    url: json['url'] as String? ?? 'https://huggingface.co',
    provenance: ModelDataProvenance.values.firstWhere(
      (p) => p.name == json['provenance'],
      orElse: () => ModelDataProvenance.huggingFace,
    ),
  );
}

class ModelFact<T> {
  final T? value;
  final ModelDataProvenance provenance;
  final ModelSource? source;
  final DateTime? fetchedAt;

  const ModelFact({
    required this.value,
    required this.provenance,
    this.source,
    this.fetchedAt,
  });

  bool get isAvailable =>
      value != null && provenance != ModelDataProvenance.unavailable;
}

class VerifiedBenchmark {
  final String name;
  final double value;
  final String? unit;
  final String? evaluationVariant;
  final String? datasetVersion;
  final ModelSource source;

  const VerifiedBenchmark({
    required this.name,
    required this.value,
    this.unit,
    this.evaluationVariant,
    this.datasetVersion,
    required this.source,
  });
}

class VerifiedCapability {
  final String name;
  final String description;
  final ModelSource source;

  const VerifiedCapability({
    required this.name,
    required this.description,
    required this.source,
  });
}

class VerifiedModelInfo {
  final String id;
  final String displayName;
  final ModelFact<String> developer;
  final ModelFact<String> license;
  final ModelFact<String> architecture;
  final ModelFact<double> parametersBillions;
  final ModelFact<int> contextLength;
  final ModelFact<int> vocabularySize;
  final ModelFact<String> quantization;
  final ModelFact<int> fileSizeBytes;
  final ModelFact<double> estimatedRamGb;
  final ModelFact<double> measuredRamGb;
  final ModelFact<double> measuredTokensPerSec;
  final List<VerifiedBenchmark> benchmarks;
  final List<VerifiedCapability> capabilities;
  final List<ModelSource> sources;
  final DateTime lastUpdated;
  final String? remoteSha;
  final int? downloads;
  final int? likes;
  final bool isLiveSyncing;
  final bool isOffline;
  final String story;

  const VerifiedModelInfo({
    required this.id,
    required this.displayName,
    required this.developer,
    required this.license,
    required this.architecture,
    required this.parametersBillions,
    required this.contextLength,
    required this.vocabularySize,
    required this.quantization,
    required this.fileSizeBytes,
    required this.estimatedRamGb,
    required this.measuredRamGb,
    required this.measuredTokensPerSec,
    required this.benchmarks,
    required this.capabilities,
    required this.sources,
    required this.lastUpdated,
    this.remoteSha,
    this.downloads,
    this.likes,
    this.isLiveSyncing = false,
    this.isOffline = false,
    required this.story,
  });
}
