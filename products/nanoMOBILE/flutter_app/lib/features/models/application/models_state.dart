import 'package:nanoai/features/models/domain/detected_model.dart';
import 'package:nanoai/features/models/domain/local_model.dart';

class ModelsState {
  final List<LocalModel> models;

  /// Modelos detectados en el storage SAF (sin copiar, deduplicados contra
  /// el catálogo por nombre de archivo).
  final List<DetectedModel> detected;

  /// true mientras el walk del storage corre en Kotlin.
  final bool scanning;

  /// true cuando hay un árbol SAF concedido y persistido.
  final bool treeGranted;

  /// true cuando MANAGE_EXTERNAL_STORAGE está concedido (escaneo de todo
  /// el storage compartido con rutas directas).
  final bool allFilesGranted;

  /// Mensaje honesto del último fallo de escaneo o apertura de fd.
  final String? scanError;

  /// uri o path del detectado que se está abriendo (spinner en su botón).
  final String? loadingDetectedUri;

  const ModelsState({
    this.models = const [],
    this.detected = const [],
    this.scanning = false,
    this.treeGranted = false,
    this.allFilesGranted = false,
    this.scanError,
    this.loadingDetectedUri,
  });

  ModelsState copyWith({
    List<LocalModel>? models,
    List<DetectedModel>? detected,
    bool? scanning,
    bool? treeGranted,
    bool? allFilesGranted,
    Object? scanError = _sentinel,
    Object? loadingDetectedUri = _sentinel,
  }) {
    return ModelsState(
      models: models ?? this.models,
      detected: detected ?? this.detected,
      scanning: scanning ?? this.scanning,
      treeGranted: treeGranted ?? this.treeGranted,
      allFilesGranted: allFilesGranted ?? this.allFilesGranted,
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
