import '../business/business_facts.dart';

// business_connector_models.dart
//
// QUÉ HACE:
// Define modelos inmutables y contratos de datos para fuentes empresariales
// (Excel, CSV, Google Sheets, SQLite, REST API) y validación de importación.
//
// CÓMO FUNCIONA:
// - Encapsula metadatos de fuentes externas con BusinessSourceConfig.
// - Modela la asignación de columnas con BusinessColumnMapping.
// - Estructura el reporte de auditoría y validación con BusinessValidationReport.
//
// POR QUÉ:
// Aplica el principio de Responsabilidad Única (SRP) y garantiza integridad
// comercial antes de impactar el catálogo en memoria o almacenamiento local.

/// Tipos de fuentes de datos comerciales soportadas.
enum BusinessSourceType {
  excel('Excel (.xlsx)', 'icon_excel'),
  csv('CSV / TSV delimitado', 'icon_csv'),
  googleSheets('Google Sheets', 'icon_sheets'),
  sqlite('Base de datos SQLite', 'icon_sqlite'),
  restApi('Sistema Empresarial REST / JSON', 'icon_api');

  final String label;
  final String iconKey;
  const BusinessSourceType(this.label, this.iconKey);
}

/// Estado de sincronización de una fuente comercial.
enum SyncStatus { idle, syncing, success, error }

/// Configuración y estado de una fuente de datos conectada.
class BusinessSourceConfig {
  final String id;
  final String name;
  final BusinessSourceType type;
  final String sourceUri;

  /// Credencial efímera: se usa en la petición y nunca se persiste ni registra.
  final String? authToken;
  final String? sheetName;
  final DateTime? lastSync;
  final int recordCount;
  final SyncStatus status;
  final String? errorMessage;

  const BusinessSourceConfig({
    required this.id,
    required this.name,
    required this.type,
    required this.sourceUri,
    this.authToken,
    this.sheetName,
    this.lastSync,
    this.recordCount = 0,
    this.status = SyncStatus.idle,
    this.errorMessage,
  });

  BusinessSourceConfig copyWith({
    String? name,
    String? sourceUri,
    String? authToken,
    String? sheetName,
    DateTime? lastSync,
    int? recordCount,
    SyncStatus? status,
    String? errorMessage,
  }) {
    return BusinessSourceConfig(
      id: id,
      name: name ?? this.name,
      type: type,
      sourceUri: sourceUri ?? this.sourceUri,
      authToken: authToken ?? this.authToken,
      sheetName: sheetName ?? this.sheetName,
      lastSync: lastSync ?? this.lastSync,
      recordCount: recordCount ?? this.recordCount,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Mapeo de correspondencias entre columnas de la fuente y el modelo comercial.
class BusinessColumnMapping {
  final String? nameColumn;
  final String? priceColumn;
  final String? stockColumn;
  final String? skuColumn;
  final String? categoryColumn;
  final String? detailsColumn;

  const BusinessColumnMapping({
    this.nameColumn,
    this.priceColumn,
    this.stockColumn,
    this.skuColumn,
    this.categoryColumn,
    this.detailsColumn,
  });

  bool get isValid => nameColumn != null && priceColumn != null;

  BusinessColumnMapping copyWith({
    String? nameColumn,
    String? priceColumn,
    String? stockColumn,
    String? skuColumn,
    String? categoryColumn,
    String? detailsColumn,
  }) {
    return BusinessColumnMapping(
      nameColumn: nameColumn ?? this.nameColumn,
      priceColumn: priceColumn ?? this.priceColumn,
      stockColumn: stockColumn ?? this.stockColumn,
      skuColumn: skuColumn ?? this.skuColumn,
      categoryColumn: categoryColumn ?? this.categoryColumn,
      detailsColumn: detailsColumn ?? this.detailsColumn,
    );
  }
}

/// Reporte previo de validación de datos comerciales.
class BusinessValidationReport {
  final int totalRows;
  final int validCount;
  final int invalidCount;
  final int duplicateCount;
  final List<String> warnings;
  final List<BusinessProduct> validProducts;

  const BusinessValidationReport({
    required this.totalRows,
    required this.validCount,
    required this.invalidCount,
    required this.duplicateCount,
    required this.warnings,
    required this.validProducts,
  });

  bool get hasValidData => validCount > 0;
  bool get hasErrors => invalidCount > 0 || duplicateCount > 0;
}
