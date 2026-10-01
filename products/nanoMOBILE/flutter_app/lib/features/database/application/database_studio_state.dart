// database_studio_state.dart
//
// QUÉ HACE:
// Estado inmutable del estudio de bases de datos, hojas de cálculo y reportes ejecutivos.
//
// CÓMO FUNCIONA:
// - Retiene el mapa de tablas disponibles, la tabla seleccionada y el resultado de la última consulta.
// - Rastrea historial de queries (últimas 20), indicadores de carga y mensajes de estado / error.
//
// POR QUÉ:
// Aplica SOLID (SRP) separando el modelo de estado de la lógica del StateNotifier (< 70 líneas).

library;

import '../domain/data_models.dart';

class DatabaseStudioState {
  final Map<String, DataTable> tables;
  final String selectedTableName;
  final QueryResult? queryResult;
  final String currentQuery;
  final List<String> queryHistory;
  final bool isLoading;
  final String? errorMessage;
  final String? statusMessage;
  final bool isShellConnected;
  final String? databasePath;

  const DatabaseStudioState({
    required this.tables,
    required this.selectedTableName,
    this.queryResult,
    this.currentQuery = '',
    this.queryHistory = const [],
    this.isLoading = false,
    this.errorMessage,
    this.statusMessage,
    this.isShellConnected = true,
    this.databasePath,
  });

  DataTable? get currentTable => tables[selectedTableName];
  DataTable? get activeDisplayTable => queryResult?.table ?? currentTable;
  String get selectedTableSql => databasePath == null
      ? selectedTableName
      : '"${selectedTableName.replaceAll('"', '""')}"';

  DatabaseStudioState withImportedTable(DataTable table, String message) =>
      copyWith(
        tables: {table.name: table},
        selectedTableName: table.name,
        currentQuery: 'SELECT * FROM ${table.name} LIMIT 50;',
        isLoading: false,
        statusMessage: '$message · ${table.rowCount} filas',
        clearDatabasePath: true,
        clearError: true,
      );

  DatabaseStudioState copyWith({
    Map<String, DataTable>? tables,
    String? selectedTableName,
    QueryResult? queryResult,
    String? currentQuery,
    List<String>? queryHistory,
    bool? isLoading,
    String? errorMessage,
    String? statusMessage,
    bool? isShellConnected,
    String? databasePath,
    bool clearDatabasePath = false,
    bool clearError = false,
    bool clearQueryResult = false,
  }) {
    return DatabaseStudioState(
      tables: tables ?? this.tables,
      selectedTableName: selectedTableName ?? this.selectedTableName,
      queryResult: clearQueryResult ? null : queryResult ?? this.queryResult,
      currentQuery: currentQuery ?? this.currentQuery,
      queryHistory: queryHistory ?? this.queryHistory,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      statusMessage: statusMessage,
      isShellConnected: isShellConnected ?? this.isShellConnected,
      databasePath: clearDatabasePath
          ? null
          : databasePath ?? this.databasePath,
    );
  }
}
