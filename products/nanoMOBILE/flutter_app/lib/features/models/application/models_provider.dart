import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/models/application/models_notifier.dart';
import 'package:nanoai/features/models/application/models_state.dart';
import 'package:nanoai/features/models/data/catalog_local_model_repository.dart';
import 'package:nanoai/features/models/data/channel_model_storage_repository.dart';
import 'package:nanoai/features/models/domain/local_model_repository.dart';
import 'package:nanoai/features/models/domain/model_storage_repository.dart';

final localModelRepositoryProvider = Provider<LocalModelRepository>(
  (ref) => const CatalogLocalModelRepository(),
);

final modelStorageRepositoryProvider = Provider<ModelStorageRepository>(
  (ref) => const ChannelModelStorageRepository(),
);

final modelsProvider = StateNotifierProvider<ModelsNotifier, ModelsState>(
  (ref) => ModelsNotifier(
    ref,
    ref.watch(localModelRepositoryProvider),
    storage: ref.watch(modelStorageRepositoryProvider),
  ),
);
