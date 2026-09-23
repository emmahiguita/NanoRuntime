import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/domain/data_models.dart';
import '../business/business_facts_providers.dart';
import 'business_column_detector.dart';
import 'business_connector_models.dart';
import 'business_data_normalizer.dart';
import 'business_data_source_adapters.dart';

// business_data_connector_service.dart
//
// QUÉ HACE:
// Orquesta el ciclo completo de integración de datos empresariales:
// adquisición desde la fuente, detección de columnas, validación y sincronización atómica.
//
// CÓMO FUNCIONA:
// - Despacha la carga de datos al adaptador correspondiente según BusinessSourceType.
// - Proporciona el mapeo inicial detectado para revisión del usuario.
// - Aplica la normalización y registra los productos resultantes en BusinessFactsNotifier.
//
// POR QUÉ:
// Centraliza el caso de uso de sincronización empresarial aplicando Inversión de Dependencias
// (DIP) y desacoplando la lógica de negocio de los componentes visuales.

class BusinessDataConnectorService {
  final Ref _ref;

  const BusinessDataConnectorService(this._ref);

  /// Carga la tabla de datos cruda según la configuración de la fuente.
  Future<DataTable> loadSourceTable(BusinessSourceConfig config) async {
    switch (config.type) {
      case BusinessSourceType.excel:
      case BusinessSourceType.csv:
        return BusinessDataSourceAdapters.loadFromFile(
          filePath: config.sourceUri,
          fileName: config.name,
        );
      case BusinessSourceType.googleSheets:
        return BusinessDataSourceAdapters.loadFromGoogleSheets(
          sheetUrl: config.sourceUri,
          tableName: config.name,
        );
      case BusinessSourceType.sqlite:
        return BusinessDataSourceAdapters.loadFromSqlite(
          dbPath: config.sourceUri,
          tableName: config.sheetName ?? 'products',
        );
      case BusinessSourceType.restApi:
        return BusinessDataSourceAdapters.loadFromRestApi(
          endpointUrl: config.sourceUri,
        );
    }
  }

  /// Propone el mapeo de columnas automático para una tabla cargada.
  BusinessColumnMapping proposeMapping(DataTable table) {
    return BusinessColumnDetector.detect(table.columns);
  }

  /// Ejecuta la validación y normalización de una tabla con un mapeo seleccionado.
  BusinessValidationReport validate({
    required DataTable table,
    required BusinessColumnMapping mapping,
  }) {
    return BusinessDataNormalizer.normalize(table: table, mapping: mapping);
  }

  /// Aplica los productos validados al catálogo activo del agente comercial.
  Future<bool> commitImport({
    required BusinessValidationReport report,
    required bool replaceExisting,
  }) async {
    if (!report.hasValidData) return false;

    final notifier = _ref.read(businessFactsNotifierProvider.notifier);
    return notifier.importProducts(
      report.validProducts,
      replaceAll: replaceExisting,
    );
  }
}

final businessDataConnectorServiceProvider = Provider<BusinessDataConnectorService>((ref) {
  return BusinessDataConnectorService(ref);
});
