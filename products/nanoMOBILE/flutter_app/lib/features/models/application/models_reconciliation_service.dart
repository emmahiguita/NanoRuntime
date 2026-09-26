// models_reconciliation_service.dart — Servicio de reconciliación entre storage y catálogo.
// QUÉ HACE: Coteja modelos escaneados en almacenamiento local con las entradas del catálogo.
// CÓMO FUNCIONA: Verifica tamaño y manifiesto SHA-256 para enlazar archivos físicos con el catálogo.
// POR QUÉ: Desacopla la lógica algorítmica de matching del StateNotifier para cumplir < 200 líneas.
library;

import 'dart:io';
import '../data/model_integrity.dart';
import '../domain/detected_model.dart';
import '../domain/local_model.dart';

class CatalogReconciliation {
  const CatalogReconciliation(this.models, this.detected);

  final List<LocalModel> models;
  final List<DetectedModel> detected;
}

class ModelsReconciliationService {
  const ModelsReconciliationService();

  /// Reconcilia los modelos encontrados en storage externo con el catálogo descargable.
  CatalogReconciliation reconcile(
    List<DetectedModel> detected, {
    required List<LocalModel> currentModels,
  }) {
    final detectedByName = {
      for (final model in detected)
        if (model.usable && model.path != null) model.name.toLowerCase(): model,
    };

    final reconciledModels = [
      for (final model in currentModels)
        if (detectedByName[model.fileName.toLowerCase()] case final found?
            when sizeMatchesCatalog(model, found))
          model.copyWith(
            downloadState: ModelDownloadState.installed,
            progress: 1,
            localPath: found.path,
            clearError: true,
          )
        else
          model,
    ];

    final catalogNames = {
      for (final model in reconciledModels)
        if (model.installed) model.fileName.toLowerCase(),
    };
    final visibleDetected = [
      for (final model in detected)
        if (!catalogNames.contains(model.name.toLowerCase())) model,
    ];

    return CatalogReconciliation(reconciledModels, visibleDetected);
  }

  /// Verifica si el tamaño del archivo detectado coincide con el declarado en el catálogo (±10%).
  bool sizeMatchesCatalog(LocalModel catalog, DetectedModel found) {
    if (found.sizeBytes <= 0) return false;
    final expectedBytes = catalog.sizeGb * 1024 * 1024 * 1024;
    final delta = (found.sizeBytes - expectedBytes).abs();
    if (delta > expectedBytes * 0.10 || found.path == null) return false;
    return ModelIntegrity.hasTrustedManifest(File(found.path!), catalog.sha256);
  }

  // QUÉ HACE: Verifica integridad de archivos existentes en la carpeta de descargas configurada.
  // POR QUÉ: Permite detectar modelos descargados previamente al iniciar la app.
  Future<List<LocalModel>> verifyConfiguredDirectory(List<LocalModel> models, String? dir) async {
    if (dir == null) return models;
    final results = <LocalModel>[];
    for (final m in models) {
      if (!m.installed && await ModelIntegrity.verify(File('$dir/${m.fileName}'), m.sha256)) {
        results.add(m.copyWith(downloadState: ModelDownloadState.installed, progress: 1, localPath: '$dir/${m.fileName}', clearError: true));
      } else {
        results.add(m);
      }
    }
    return results;
  }
}
