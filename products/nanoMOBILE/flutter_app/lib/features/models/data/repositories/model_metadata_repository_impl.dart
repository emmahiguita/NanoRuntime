/// Implementación del repositorio de metadatos verificados (DIP, SRP, OCP).
library;

import '../../../../core/models/catalog_models.dart';
import '../../domain/model_metadata_entities.dart';
import '../../domain/repositories/i_model_metadata_repository.dart';
import '../datasources/i_model_metadata_datasource.dart';
import '../model_source_registry.dart';

class ModelMetadataRepositoryImpl implements IModelMetadataRepository {
  final IModelRemoteMetadataDataSource _remoteDataSource;
  final IModelLocalMetadataCache _localCache;
  static const Duration _cacheTtl = Duration(hours: 24);
  final Set<String> _inFlightRequests = {};

  ModelMetadataRepositoryImpl({
    required IModelRemoteMetadataDataSource remoteDataSource,
    required IModelLocalMetadataCache localCache,
  }) : _remoteDataSource = remoteDataSource,
       _localCache = localCache;

  @override
  Future<void> initialize() async {
    await _localCache.initialize();
  }

  @override
  VerifiedModelInfo getVerifiedModelInfo({
    required String modelName,
    required double phoneTotalRamGb,
    double? customRamGb,
    double? customSizeGb,
    String? customQuant,
    double? measuredTokensPerSec,
    double? measuredRamGb,
  }) {
    final def = ModelSourceRegistry.definitionFor(modelName);
    final isCatalog = NeuralCatalog.models.any((m) => m.name == modelName);
    final catalogEntry = isCatalog ? NeuralCatalog.entryOf(modelName) : null;

    final quant = customQuant ?? catalogEntry?.quant ?? 'Q4_K_M';
    final sizeGb = customSizeGb ?? catalogEntry?.sizeGb ?? 0.0;
    final fileSizeBytes = (sizeGb * 1024 * 1024 * 1024).round();
    final estimatedRam =
        customRamGb ?? catalogEntry?.ramGb ?? (sizeGb * 1.2 + 0.6);

    final remote =
        _localCache.get(def.quantizedRepo) ?? _localCache.get(def.officialRepo);
    final lastFetched =
        _localCache.getTimestamp(def.quantizedRepo) ??
        _localCache.getTimestamp(def.officialRepo);

    final officialSource = ModelSource(
      label: '${def.developerName} (Official Developer)',
      url: 'https://huggingface.co/${def.officialRepo}',
      provenance: ModelDataProvenance.official,
    );

    final hfSource = ModelSource(
      label: 'Hugging Face Hub API (${def.officialRepo})',
      url: 'https://huggingface.co/${def.officialRepo}',
      provenance: ModelDataProvenance.huggingFace,
    );

    final quantSource = ModelSource(
      label: '${def.quantizationSource} (GGUF Source)',
      url: 'https://huggingface.co/${def.quantizedRepo}',
      provenance: ModelDataProvenance.quantization,
    );

    const localSource = ModelSource(
      label: 'NanoAI Local Telemetry',
      url: 'local://device/telemetry',
      provenance: ModelDataProvenance.localMeasured,
    );

    final sourcesList = <ModelSource>[
      officialSource,
      if (def.officialRepo != def.quantizedRepo) quantSource,
      hfSource,
      if (measuredRamGb != null || measuredTokensPerSec != null) localSource,
    ];

    return VerifiedModelInfo(
      id: def.id,
      displayName: modelName,
      developer: ModelFact(
        value: def.developerName,
        provenance: ModelDataProvenance.official,
        source: officialSource,
      ),
      license: ModelFact(
        value: def.officialLicense,
        provenance: ModelDataProvenance.official,
        source: officialSource,
      ),
      architecture: ModelFact(
        value: def.baseArchitecture,
        provenance: ModelDataProvenance.official,
        source: officialSource,
      ),
      parametersBillions: ModelFact(
        value: def.officialParams,
        provenance: ModelDataProvenance.official,
        source: officialSource,
      ),
      contextLength: ModelFact(
        value: def.officialContext,
        provenance: ModelDataProvenance.official,
        source: officialSource,
      ),
      vocabularySize: ModelFact(
        value: def.officialVocab,
        provenance: ModelDataProvenance.official,
        source: officialSource,
      ),
      quantization: ModelFact(
        value: quant,
        provenance: ModelDataProvenance.quantization,
        source: quantSource,
      ),
      fileSizeBytes: ModelFact(
        value: fileSizeBytes,
        provenance: ModelDataProvenance.quantization,
        source: quantSource,
      ),
      estimatedRamGb: ModelFact(
        value: estimatedRam,
        provenance: ModelDataProvenance.estimated,
      ),
      measuredRamGb: ModelFact(
        value: measuredRamGb,
        provenance: measuredRamGb != null
            ? ModelDataProvenance.localMeasured
            : ModelDataProvenance.unavailable,
      ),
      measuredTokensPerSec: ModelFact(
        value: measuredTokensPerSec,
        provenance: measuredTokensPerSec != null
            ? ModelDataProvenance.localMeasured
            : ModelDataProvenance.unavailable,
      ),
      benchmarks: def.officialBenchmarks,
      capabilities: def.officialCapabilities,
      sources: sourcesList,
      lastUpdated: lastFetched ?? DateTime.now(),
      remoteSha: remote?.sha,
      downloads: remote?.downloads,
      likes: remote?.likes,
      isOffline: lastFetched == null,
      story: def.story,
    );
  }

  @override
  Future<void> refreshRemoteMetadata(String repoId) async {
    if (_inFlightRequests.contains(repoId)) return;
    if (_localCache.isFresh(repoId, _cacheTtl)) return;

    _inFlightRequests.add(repoId);
    try {
      final remote = await _remoteDataSource.fetchModelMetadata(repoId);
      if (remote != null) {
        await _localCache.save(repoId, remote, DateTime.now());
      }
    } finally {
      _inFlightRequests.remove(repoId);
    }
  }
}
