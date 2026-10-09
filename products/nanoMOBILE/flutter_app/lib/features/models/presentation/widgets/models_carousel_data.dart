// QUÉ: metadatos existentes del carrusel; no cambia evidencia ni selección.
// POR QUÉ: separa el mapeo de datos del diseño para mantener archivos breves.
import '../../../../core/models/catalog_models.dart';

/// QUÉ HACE: DTO (Data Transfer Object) inmutable con los metadatos de un modelo para la tarjeta.
/// CÓMO FUNCIONA: Extrae propiedades verificadas del catálogo sin benchmarks simulados.
class RecommendedModelCardData {
  final String title;
  final String params;
  final String quantization;
  final String downloadSize;
  final String memoryReference;
  final String description;
  final String deviceEvidence;
  final bool isDefault;

  const RecommendedModelCardData({
    required this.title,
    required this.params,
    required this.quantization,
    required this.downloadSize,
    required this.memoryReference,
    required this.description,
    required this.deviceEvidence,
    required this.isDefault,
  });

  /// CÓMO FUNCIONA: Fábrica que mapea LmCatalogEntry hacia la tarjeta visual.
  factory RecommendedModelCardData.fromCatalog(LmCatalogEntry entry) {
    final measuredOnOppo = entry.name == 'Qwen3-0.6B-Instruct (LiteRT)';
    final memoryNote = entry.name == 'Qwen2.5-1.5B-Instruct (LiteRT)'
        ? 'RAM ref. ≈${entry.ramGb.toStringAsFixed(1)} GB (otro)'
        : 'RAM ref. ≈${entry.ramGb.toStringAsFixed(1)} GB';
    return RecommendedModelCardData(
      title: entry.name,
      params: entry.params,
      quantization: entry.quant,
      downloadSize: '${entry.sizeGb.toStringAsFixed(2)} GB',
      memoryReference: memoryNote,
      description: 'Motor ${entry.backendType.name.toUpperCase()}',
      deviceEvidence: measuredOnOppo
          ? 'Prueba CPH2557: ≈7,53 tok/s; TTFT ≈12,2 s'
          : 'CPH2557: velocidad pendiente',
      isDefault: entry.tier == ModelTier.interactive,
    );
  }
}
