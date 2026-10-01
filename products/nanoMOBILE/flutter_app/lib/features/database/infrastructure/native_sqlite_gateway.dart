// QUÉ: adaptador SQLite real respaldado por android.database.sqlite.
// CÓMO: traduce MethodChannel a contratos DataTable/QueryResult tipados.
// POR QUÉ: funciona en el APK sin instalar ni simular un ejecutable sqlite3.

import 'package:flutter/services.dart';
import '../domain/data_models.dart';
import '../domain/database_port.dart';

final class NativeSqliteGateway implements DatabasePort {
  static const _channel = MethodChannel('com.nanoai/data_studio');

  const NativeSqliteGateway();

  @override
  Future<String> ensureDefaultDatabase() async =>
      (await _channel.invokeMethod<String>('defaultDatabase'))!;

  @override
  Future<String> ensureDemoDatabase() async =>
      (await _channel.invokeMethod<String>('demoDatabase'))!;

  @override
  Future<String> createDatabase(String name) async =>
      (await _channel.invokeMethod<String>('createDatabase', {'name': name}))!;

  @override
  Future<List<String>> listTables(String path) async {
    final result = await _channel.invokeListMethod<String>('listTables', {
      'path': path,
    });
    return result ?? const [];
  }

  @override
  Future<QueryResult> execute({
    required String path,
    required String query,
  }) async {
    final timer = Stopwatch()..start();
    try {
      final payload = await _channel.invokeMapMethod<String, dynamic>('query', {
        'path': path,
        'sql': query,
      });
      timer.stop();
      if (payload == null) {
        return QueryResult.error(query, 'SQLite no devolvió resultado.');
      }
      final columns = (payload['columns'] as List? ?? const [])
          .map((e) => '$e')
          .toList();
      final rows = (payload['rows'] as List? ?? const [])
          .map((row) => List<dynamic>.from(row as List))
          .toList();
      return QueryResult.success(
        query: query,
        // Las mutaciones no devuelven tabla; la UI conserva la vista anterior.
        table: columns.isEmpty
            ? null
            : DataTable(name: 'sqlite_result', columns: columns, rows: rows),
        executionTimeMs: timer.elapsedMilliseconds,
        affectedRows: (payload['affectedRows'] as num?)?.toInt(),
        truncated: payload['truncated'] == true,
      );
    } on PlatformException catch (error) {
      timer.stop();
      return QueryResult.error(
        query,
        error.message ?? error.code,
        executionTimeMs: timer.elapsedMilliseconds,
      );
    }
  }

  @override
  Future<void> createTable({
    required String path,
    required String table,
    required List<DatabaseColumnDefinition> columns,
  }) async {
    await _channel.invokeMethod<void>('createTable', {
      'path': path,
      'table': table,
      'columns': columns.map((column) => column.toMap()).toList(),
    });
  }
}
