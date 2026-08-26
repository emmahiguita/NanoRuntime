/// Servicio de metadata de Hugging Face Hub con política Offline-First y caché persistente.
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/catalog_models.dart';
import '../domain/model_metadata_entities.dart';
import 'model_source_registry.dart';

class RemoteModelMetadata {
  final String id;
  final String? author;
  final String? sha;
  final DateTime? lastModified;
  final int? downloads;
  final int? likes;
  final List<String> tags;
  final String? pipelineTag;
  final Map<String, dynamic> cardData;

  const RemoteModelMetadata({
    required this.id,
    this.author,
    this.sha,
    this.lastModified,
    this.downloads,
    this.likes,
    this.tags = const [],
    this.pipelineTag,
    this.cardData = const {},
  });

  factory RemoteModelMetadata.fromJson(Map<String, dynamic> json) {
    DateTime? mod;
    if (json['lastModified'] != null) {
      try {
        mod = DateTime.parse(json['lastModified'] as String);
      } catch (_) {}
    }

    return RemoteModelMetadata(
      id: json['id'] as String? ?? '',
      author: json['author'] as String?,
      sha: json['sha'] as String?,
      lastModified: mod,
      downloads: json['downloads'] as int?,
      likes: json['likes'] as int?,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      pipelineTag: json['pipeline_tag'] as String?,
      cardData: (json['cardData'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'author': author,
    'sha': sha,
    'lastModified': lastModified?.toIso8601String(),
    'downloads': downloads,
    'likes': likes,
    'tags': tags,
    'pipeline_tag': pipelineTag,
    'cardData': cardData,
  };
}

class HuggingFaceMetadataService {
  HuggingFaceMetadataService._();
  static final HuggingFaceMetadataService instance =
      HuggingFaceMetadataService._();

  static const Duration _cacheTtl = Duration(hours: 24);
  static const Duration _requestTimeout = Duration(seconds: 4);
  static const String _prefPrefix = 'hf_meta_cache_';

  final Map<String, RemoteModelMetadata> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Set<String> _inFlightRequests = {};

  /// Construye la entidad de información verificada inmediata (desde registro canónico + cache).
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
        _memoryCache[def.quantizedRepo] ?? _memoryCache[def.officialRepo];
    final lastFetched =
        _cacheTimestamps[def.quantizedRepo] ??
        _cacheTimestamps[def.officialRepo];

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

  /// Carga la caché persistente desde SharedPreferences.
  Future<void> initializeCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_prefPrefix));
      for (final key in keys) {
        final repoId = key.substring(_prefPrefix.length);
        final raw = prefs.getString(key);
        if (raw != null) {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          final timestamp =
              DateTime.tryParse(map['_cached_at'] as String? ?? '') ??
              DateTime.now();
          final meta = RemoteModelMetadata.fromJson(map);
          _memoryCache[repoId] = meta;
          _cacheTimestamps[repoId] = timestamp;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cargando cache persistente HF: $e');
      }
    }
  }

  /// Refresca en segundo plano la metadata de un repositorio en el Hub de Hugging Face.
  Future<RemoteModelMetadata?> refreshModelMetadata(String repoId) async {
    if (_inFlightRequests.contains(repoId)) return _memoryCache[repoId];

    final lastFetched = _cacheTimestamps[repoId];
    if (lastFetched != null &&
        DateTime.now().difference(lastFetched) < _cacheTtl) {
      return _memoryCache[repoId];
    }

    _inFlightRequests.add(repoId);

    try {
      final uri = Uri.https('huggingface.co', '/api/models/$repoId');
      final response = await http.get(uri).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final metadata = RemoteModelMetadata.fromJson(json);

        _memoryCache[repoId] = metadata;
        final now = DateTime.now();
        _cacheTimestamps[repoId] = now;

        // Persistir en SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final toSave = metadata.toJson()
          ..['_cached_at'] = now.toIso8601String();
        await prefs.setString('$_prefPrefix$repoId', jsonEncode(toSave));

        return metadata;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Hugging Face Hub offline / fallback activado para $repoId: $e');
      }
    } finally {
      _inFlightRequests.remove(repoId);
    }

    return _memoryCache[repoId];
  }
}
