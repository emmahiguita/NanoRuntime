import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../domain/data_models.dart';
import 'csv_tsv_parser.dart';
import 'sql_query_engine.dart';
import 'report_generator_service.dart';

/// Estado inmutable del Estudio de Base de Datos y Hojas de Cálculo
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
  });

  DataTable? get currentTable => tables[selectedTableName];
  DataTable? get activeDisplayTable => queryResult?.table ?? currentTable;

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
  }) {
    return DatabaseStudioState(
      tables: tables ?? this.tables,
      selectedTableName: selectedTableName ?? this.selectedTableName,
      queryResult: queryResult ?? this.queryResult,
      currentQuery: currentQuery ?? this.currentQuery,
      queryHistory: queryHistory ?? this.queryHistory,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      statusMessage: statusMessage,
      isShellConnected: isShellConnected ?? this.isShellConnected,
    );
  }
}

/// Proveedor Riverpod para el controlador del estudio de datos
final databaseStudioControllerProvider =
    StateNotifierProvider<DatabaseStudioController, DatabaseStudioState>((ref) {
  return DatabaseStudioController();
});

class DatabaseStudioController extends StateNotifier<DatabaseStudioState> {
  DatabaseStudioController()
      : super(
          const DatabaseStudioState(
            tables: {},
            selectedTableName: '',
            currentQuery: 'SELECT * FROM ventas_globales LIMIT 25;',
          ),
        ) {
    _loadInitialSampleDatasets();
  }

  void _loadInitialSampleDatasets() {
    final ventasTable = CsvTsvParser.parse(
      name: 'ventas_globales',
      rawContent: _sampleVentasCsv,
    );

    final metricasTable = CsvTsvParser.parse(
      name: 'metricas_sistema_shell',
      rawContent: _sampleMetricasTsv,
    );

    final usuariosTable = CsvTsvParser.parse(
      name: 'usuarios_servicios',
      rawContent: _sampleUsuariosCsv,
    );

    final initialTables = {
      'ventas_globales': ventasTable,
      'metricas_sistema_shell': metricasTable,
      'usuarios_servicios': usuariosTable,
    };

    const defaultQuery = 'SELECT * FROM ventas_globales LIMIT 25;';
    final initialResult = SqlQueryEngine.executeMemoryQuery(
      query: defaultQuery,
      tables: initialTables,
    );

    state = state.copyWith(
      tables: initialTables,
      selectedTableName: 'ventas_globales',
      currentQuery: defaultQuery,
      queryResult: initialResult,
      queryHistory: [
        defaultQuery,
        'SELECT categoria, COUNT(*) FROM ventas_globales GROUP BY categoria;',
        'SELECT pais, SUM(total) FROM ventas_globales GROUP BY pais;',
        'SELECT * FROM metricas_sistema_shell WHERE cpu_pct > 50;',
      ],
      statusMessage: '3 conjuntos de datos cargados (CSV, TSV y Hojas Shell).',
    );
  }

  void updateQueryText(String query) {
    state = state.copyWith(currentQuery: query);
  }

  void selectTable(String tableName) {
    if (!state.tables.containsKey(tableName)) return;
    final newQuery = 'SELECT * FROM $tableName LIMIT 50;';
    final result = SqlQueryEngine.executeMemoryQuery(
      query: newQuery,
      tables: state.tables,
    );

    state = state.copyWith(
      selectedTableName: tableName,
      currentQuery: newQuery,
      queryResult: result,
      statusMessage: 'Tabla activa: $tableName (${state.tables[tableName]!.rowCount} filas)',
    );
  }

  /// Ejecuta la consulta SQL actual
  Future<void> executeCurrentQuery() async {
    final query = state.currentQuery.trim();
    if (query.isEmpty) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final result = SqlQueryEngine.executeMemoryQuery(
        query: query,
        tables: state.tables,
      );

      final updatedHistory = List<String>.from(state.queryHistory);
      if (!updatedHistory.contains(query)) {
        updatedHistory.insert(0, query);
        if (updatedHistory.length > 20) updatedHistory.removeLast();
      }

      state = state.copyWith(
        isLoading: false,
        queryResult: result,
        queryHistory: updatedHistory,
        errorMessage: result.errorMessage,
        statusMessage: result.isSuccess
            ? 'Consulta completada en ${result.executionTimeMs}ms (${result.rowCount} filas)'
            : 'Error en consulta SQL',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Fallo de ejecución: $e',
      );
    }
  }

  /// Importa una hoja de cálculo desde un archivo local o de almacenamiento
  Future<bool> importFileFromDevice() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'tsv', 'txt', 'sql', 'sqlite', 'db'],
      );

      if (result == null || result.files.isEmpty) return false;
      final file = result.files.first;
      if (file.path == null) return false;

      final ioFile = File(file.path!);
      final rawContent = await ioFile.readAsString();
      final tableName = file.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '').replaceAll(RegExp(r'\s+'), '_').toLowerCase();

      final parsed = CsvTsvParser.parse(
        name: tableName,
        rawContent: rawContent,
      );

      final updated = Map<String, DataTable>.from(state.tables)..[tableName] = parsed;
      state = state.copyWith(
        tables: updated,
        selectedTableName: tableName,
        currentQuery: 'SELECT * FROM $tableName LIMIT 50;',
        statusMessage: 'Hoja importada exitosamente: $tableName (${parsed.rowCount} filas)',
      );

      await executeCurrentQuery();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Error importando archivo: $e');
      return false;
    }
  }

  /// Conecta e importa una hoja de cálculo directamente desde el sistema de archivos Shell
  Future<bool> importFromShellPath(String shellFilePath) async {
    try {
      final file = File(shellFilePath);
      if (!await file.exists()) {
        state = state.copyWith(errorMessage: 'Archivo Shell no existe: $shellFilePath');
        return false;
      }

      final content = await file.readAsString();
      final name = file.uri.pathSegments.last.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '').toLowerCase();
      final table = CsvTsvParser.parse(name: name, rawContent: content);

      final updated = Map<String, DataTable>.from(state.tables)..[name] = table;
      state = state.copyWith(
        tables: updated,
        selectedTableName: name,
        currentQuery: 'SELECT * FROM $name LIMIT 50;',
        statusMessage: 'Conectado a Shell: $shellFilePath (${table.rowCount} filas)',
      );

      await executeCurrentQuery();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Fallo al leer hoja de shell: $e');
      return false;
    }
  }

  /// Genera y abre el informe PDF profesional del resultado actual
  Future<void> generateAndPreviewPdfReport({
    String? title,
    String? notes,
  }) async {
    final table = state.activeDisplayTable;
    if (table == null || table.isEmpty) {
      state = state.copyWith(errorMessage: 'No hay datos en la tabla para generar informe.');
      return;
    }

    try {
      final config = DataReportConfig(
        title: title ?? 'Informe de ${table.name.replaceAll('_', ' ').toUpperCase()}',
        subtitle: 'Análisis de datos generado desde NanoAI Terminal Studio',
        queryUsed: state.queryResult?.query,
        notes: notes,
      );

      await ReportGeneratorService.previewAndPrint(
        table: table,
        config: config,
        executionTimeMs: state.queryResult?.executionTimeMs,
      );

      state = state.copyWith(statusMessage: 'Informe PDF generado y renderizado.');
    } catch (e) {
      state = state.copyWith(errorMessage: 'Error generando PDF: $e');
    }
  }

  /// Comparte el informe PDF con apps externas
  Future<void> shareCurrentReport({String? title}) async {
    final table = state.activeDisplayTable;
    if (table == null || table.isEmpty) return;

    try {
      final config = DataReportConfig(
        title: title ?? 'Informe ${table.name}',
        queryUsed: state.queryResult?.query,
      );

      await ReportGeneratorService.sharePdfReport(
        table: table,
        config: config,
        executionTimeMs: state.queryResult?.executionTimeMs,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Error compartiendo informe: $e');
    }
  }

  /// Exporta los datos actuales de vuelta a la shell como CSV o TSV
  Future<String?> exportToShellDirectory({bool isTsv = false}) async {
    final table = state.activeDisplayTable;
    if (table == null) return null;

    try {
      final content = isTsv ? table.toTsv() : table.toCsv();
      final ext = isTsv ? 'tsv' : 'csv';
      final fileName = '${table.name}_export_${DateTime.now().millisecondsSinceEpoch}.$ext';

      final savedPath = await ReportGeneratorService.saveToShellFilesystem(
        fileName: fileName,
        content: content,
      );

      state = state.copyWith(
        statusMessage: 'Exportado al entorno Shell en: $savedPath',
      );
      return savedPath;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Fallo al exportar a Shell: $e');
      return null;
    }
  }
}

// --- Datasets Canónicos de Demostración y Trabajo ---

const _sampleVentasCsv = '''id,fecha,producto,categoria,unidades,precio_unitario,total,pais,vendedor
1,2026-01-10,NanoEngine Pro,Software,15,450.00,6750.00,Colombia,Carlos Mendoza
2,2026-01-12,Servidor Edge ARM,Hardware,4,1200.00,4800.00,Mexico,Ana Sofia Rios
3,2026-01-15,Licencia Enterprise,Software,2,3500.00,7000.00,España,Javier Ortega
4,2026-01-18,Soporte L3 24/7,Servicios,8,600.00,4800.00,Chile,Camila Valenzuela
5,2026-01-22,Cluster Microvnc,Infraestructura,3,2800.00,8400.00,Argentina,Martin Palermo
6,2026-01-28,NanoEngine Pro,Software,20,450.00,9000.00,Colombia,Carlos Mendoza
7,2026-02-02,Dispositivo Edge IOT,Hardware,12,350.00,4200.00,Peru,Diego Quispe
8,2026-02-05,Licencia Enterprise,Software,5,3500.00,17500.00,Mexico,Ana Sofia Rios
9,2026-02-11,Modulo SQLite Sync,Software,30,120.00,3600.00,Colombia,Emmanuel Higuita
10,2026-02-14,Servidor Edge ARM,Hardware,6,1200.00,7200.00,España,Javier Ortega
11,2026-02-20,Consultoria AI On-Premise,Servicios,4,2200.00,8800.00,Chile,Camila Valenzuela
12,2026-02-25,Cluster Microvnc,Infraestructura,2,2800.00,5600.00,Colombia,Emmanuel Higuita
13,2026-03-01,NanoEngine Pro,Software,18,450.00,8100.00,Mexico,Ana Sofia Rios
14,2026-03-05,Licencia Enterprise,Software,3,3500.00,10500.00,Argentina,Martin Palermo
15,2026-03-09,Dispositivo Edge IOT,Hardware,25,350.00,8750.00,Colombia,Carlos Mendoza''';

const _sampleMetricasTsv = "timestamp\tcpu_pct\tram_mb\tdisco_gb\tprocesos\tred_kbps\ttemperatura_c\n"
    "2026-03-10 10:00:00\t14.2\t1240\t18.4\t142\t250\t42.1\n"
    "2026-03-10 10:05:00\t28.5\t1420\t18.4\t150\t1200\t44.5\n"
    "2026-03-10 10:10:00\t65.8\t2100\t18.5\t175\t4800\t51.2\n"
    "2026-03-10 10:15:00\t78.4\t2450\t18.6\t182\t6200\t56.8\n"
    "2026-03-10 10:20:00\t42.1\t1850\t18.6\t160\t1800\t48.3\n"
    "2026-03-10 10:25:00\t19.0\t1320\t18.6\t145\t340\t43.0\n"
    "2026-03-10 10:30:00\t88.6\t2950\t18.7\t198\t8900\t62.4\n"
    "2026-03-10 10:35:00\t55.2\t1980\t18.7\t168\t2400\t52.0";

const _sampleUsuariosCsv = '''usuario_id,nombre,empresa,pais,plan,estado,cuota_tokens,api_calls
usr_101,Sofia Vergara,Tech Andean,Colombia,Enterprise,Activo,5000000,42100
usr_102,Mateo Fernandez,Cloud Sur,Argentina,Pro,Activo,1500000,12300
usr_103,Lucia Morales,Innova Latam,Mexico,Enterprise,Activo,5000000,89400
usr_104,Gabriel Costa,Rio Software,Brasil,Starter,Inactivo,500000,2100
usr_105,Valentina Gomez,Optima Corp,Chile,Pro,Activo,1500000,18500
usr_106,Esteban Ramirez,Data Vector,España,Enterprise,Activo,5000000,64200
usr_107,Mariana Herrera,Fintech Sol,Colombia,Starter,Pendiente,500000,850
usr_108,Alejandro Ruiz,Cyber Shield,Mexico,Pro,Activo,1500000,24600''';
