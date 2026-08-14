import 'package:nanoai/features/models/domain/local_model.dart';

class ModelsState {
  final List<LocalModel> models;
  final String query;
  final String? quantFilter;

  const ModelsState({
    this.models = const [],
    this.query = '',
    this.quantFilter,
  });

  List<LocalModel> get visibleModels {
    final normalizedQuery = query.trim().toLowerCase();
    return models
        .where((model) {
          final matchesQuery =
              normalizedQuery.isEmpty ||
              model.name.toLowerCase().contains(normalizedQuery) ||
              model.params.toLowerCase().contains(normalizedQuery) ||
              model.quant.toLowerCase().contains(normalizedQuery) ||
              model.fileName.toLowerCase().contains(normalizedQuery);
          final matchesQuant =
              quantFilter == null || model.quant == quantFilter;
          return matchesQuery && matchesQuant;
        })
        .toList(growable: false);
  }

  List<String> get availableQuants {
    final values = models.map((model) => model.quant).toSet().toList()..sort();
    return values;
  }

  ModelsState copyWith({
    List<LocalModel>? models,
    String? query,
    Object? quantFilter = _sentinel,
  }) {
    return ModelsState(
      models: models ?? this.models,
      query: query ?? this.query,
      quantFilter: identical(quantFilter, _sentinel)
          ? this.quantFilter
          : quantFilter as String?,
    );
  }
}

const Object _sentinel = Object();

/// Backwards-compatible alias used by older UI/tests.
typedef ModelItem = LocalModel;
