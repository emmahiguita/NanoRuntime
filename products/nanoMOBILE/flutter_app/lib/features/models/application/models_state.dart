import 'package:nanoai/features/models/domain/detected_model.dart';
import 'package:nanoai/features/models/domain/local_model.dart';

class ModelsState {
  final List<LocalModel> models;
  final String query;
  final String? quantFilter;

  /// Modelos detectados en el storage SAF (sin copiar, deduplicados contra
  /// el catálogo por nombre de archivo).
  final List<DetectedModel> detected;

  /// true mientras el walk del storage corre en Kotlin.
  final bool scanning;

  /// true cuando hay un árbol SAF concedido y persistido.
  final bool treeGranted;

  /// Mensaje honesto del último fallo de escaneo o apertura de fd.
  final String? scanError;

  /// uri del detectado cuyo fd se está abriendo (spinner en su botón).
  final String? loadingDetectedUri;

  const ModelsState({
    this.models = const [],
    this.query = '',
    this.quantFilter,
    this.detected = const [],
    this.scanning = false,
    this.treeGranted = false,
    this.scanError,
    this.loadingDetectedUri,
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
    List<DetectedModel>? detected,
    bool? scanning,
    bool? treeGranted,
    Object? scanError = _sentinel,
    Object? loadingDetectedUri = _sentinel,
  }) {
    return ModelsState(
      models: models ?? this.models,
      query: query ?? this.query,
      quantFilter: identical(quantFilter, _sentinel)
          ? this.quantFilter
          : quantFilter as String?,
      detected: detected ?? this.detected,
      scanning: scanning ?? this.scanning,
      treeGranted: treeGranted ?? this.treeGranted,
      scanError: identical(scanError, _sentinel)
          ? this.scanError
          : scanError as String?,
      loadingDetectedUri: identical(loadingDetectedUri, _sentinel)
          ? this.loadingDetectedUri
          : loadingDetectedUri as String?,
    );
  }
}

const Object _sentinel = Object();

/// Backwards-compatible alias used by older UI/tests.
typedef ModelItem = LocalModel;
