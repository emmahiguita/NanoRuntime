/// Contrato del repositorio de metadatos verificados (DIP & ISP).
library;

import '../model_metadata_entities.dart';

abstract interface class IModelMetadataRepository {
  /// Obtiene los metadatos verificados para un modelo dado el catálogo o modelo detectado.
  VerifiedModelInfo getVerifiedModelInfo({
    required String modelName,
    required double phoneTotalRamGb,
    double? customRamGb,
    double? customSizeGb,
    String? customQuant,
    double? measuredTokensPerSec,
    double? measuredRamGb,
  });

  /// Inicializa la caché local de metadatos.
  Future<void> initialize();

  /// Refresca en segundo plano los metadatos de un repositorio remoto en HuggingFace Hub.
  Future<void> refreshRemoteMetadata(String repoId);
}
