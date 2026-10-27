// QUÉ: materializa metadatos/tablas de una sesión SQLite para la UI.
// CÓMO: lista tablas y obtiene una vista acotada de 1000 filas por tabla.
// POR QUÉ: separa hidratación de sesión de las decisiones del controlador.

import '../domain/data_models.dart';
import '../domain/database_port.dart';

final class DatabaseSessionSnapshot {
  final String path;
  final Map<String, DataTable> tables;
  final String selectedTable;
  final String query;
  const DatabaseSessionSnapshot(
    this.path,
    this.tables,
    this.selectedTable,
    this.query,
  );
}

final class DatabaseSessionLoader {
  const DatabaseSessionLoader();

  Future<DatabaseSessionSnapshot> load(
    DatabasePort database,
    String path,
  ) async {
    final names = await database.listTables(path);
    final tables = <String, DataTable>{};
    for (final name in names) {
      final safeName = name.replaceAll('"', '""');
      final result = await database.execute(
        path: path,
        query: 'SELECT * FROM "$safeName" LIMIT 1000;',
      );
      if (result.table != null) {
        tables[name] = result.table!.copyWith(name: name);
      }
    }
    // Prioridad: dashboard_servicios (vista KPI principal del portafolio).
    // Si no existe, toma la primera tabla/vista disponible.
    // BUG CORREGIDO: antes priorizaba 'dashboard_ventas' de la demo antigua.
    final selected = names.contains('dashboard_servicios')
        ? 'dashboard_servicios'
        : names.firstOrNull ?? '';
    final query = selected.isEmpty
        ? 'SELECT name FROM sqlite_master WHERE type = \'table\';'
        : 'SELECT * FROM "$selected" LIMIT 50;';
    return DatabaseSessionSnapshot(path, tables, selected, query);
  }
}
