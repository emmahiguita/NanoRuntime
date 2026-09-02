/// Inyección de dependencias mediante Riverpod para el módulo de metadatos (DIP).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/huggingface_remote_datasource.dart';
import '../../data/datasources/i_model_metadata_datasource.dart';
import '../../data/datasources/shared_preferences_metadata_cache.dart';
import '../../data/repositories/model_metadata_repository_impl.dart';
import '../../domain/repositories/i_model_metadata_repository.dart';

final modelRemoteDataSourceProvider = Provider<IModelRemoteMetadataDataSource>((
  ref,
) {
  return HuggingFaceRemoteDataSource();
});

final modelMetadataCacheProvider = Provider<IModelLocalMetadataCache>((ref) {
  return SharedPreferencesMetadataCache();
});

final modelMetadataRepositoryProvider = Provider<IModelMetadataRepository>((
  ref,
) {
  final remote = ref.watch(modelRemoteDataSourceProvider);
  final cache = ref.watch(modelMetadataCacheProvider);
  final repo = ModelMetadataRepositoryImpl(
    remoteDataSource: remote,
    localCache: cache,
  );
  repo.initialize();
  return repo;
});
