// sql_shell_executor.dart
//
// QUÉ HACE:
// Ejecutor de consultas SQL sobre bases de datos SQLite reales en disco y en el entorno Shell.
//
// CÓMO FUNCIONA:
// - Ejecuta el comando `sqlite3 -header -csv` mediante `Process.run` con argumentos protegidos contra inyección.
// - Aplica fallback transparente hacia el shell del emulador de terminal si el binario no está en el PATH directo.
// - Parsea los resultados formateados como CSV y maneja salidas de error de SQLite.
//
// POR QUÉ:
// Aplica DIP aislando las llamadas al sistema operativo y garantizando consultas seguras (< 90 líneas).

library;

import 'dart:io';
import '../../../core/services/terminal_dependencies.dart';
import '../domain/data_models.dart';
import 'csv_tsv_parser.dart';

class SqlShellExecutor {
  /// Ejecuta una consulta SQL en una base de datos SQLite real.
  static Future<QueryResult> execute({
    required String dbPath,
    required String query,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      String output = '';
      try {
        final res = await Process.run('sqlite3', ['-header', '-csv', dbPath, query]);
        output = res.stdout.toString();
        if (res.exitCode != 0 && output.isEmpty) {
          output = res.stderr.toString();
        }
      } catch (_) {
        final shell = TerminalDependencies.instance.shell;
        if (shell != null && shell.initialized) {
          final safeQuery = query.replaceAll("'", r"'\''");
          final safePath = dbPath.replaceAll("'", r"'\''");
          final cmd = "sqlite3 -header -csv '$safePath' '$safeQuery'";
          final result = await shell.bash(cmd);
          output = result.stdout.isNotEmpty ? result.stdout : result.stderr;
        }
      }

      stopwatch.stop();
      if (output.trim().isEmpty) {
        return QueryResult.success(
          query: query,
          table: const DataTable(name: 'result', columns: ['Resultado'], rows: []),
          executionTimeMs: stopwatch.elapsedMilliseconds,
          affectedRows: 0,
        );
      }

      if (output.startsWith('Error:')) {
        return QueryResult.error(query, output.trim(), executionTimeMs: stopwatch.elapsedMilliseconds);
      }

      final parsedTable = CsvTsvParser.parse(
        name: 'sqlite_query',
        rawContent: output,
        explicitDelimiter: ',',
      );

      return QueryResult.success(
        query: query,
        table: parsedTable,
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return QueryResult.error(query, 'Fallo al ejecutar en SQLite: $e', executionTimeMs: stopwatch.elapsedMilliseconds);
    }
  }
}
