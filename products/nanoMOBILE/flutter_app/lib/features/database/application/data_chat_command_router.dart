// QUÉ: ejecuta órdenes de datos explícitas desde el chat local.
// CÓMO: reconoce un conjunto estricto, usa SQLite real y responde con evidencia.
// POR QUÉ: evita que el LLM declare bases, tablas o exportaciones que no existen.

import '../../../core/models/chat_models.dart';
import '../../chat/domain/chat_turn_route_result.dart';
import '../domain/data_models.dart';
import '../domain/database_port.dart';
import '../infrastructure/native_sqlite_gateway.dart';
import 'data_export_service.dart';

final class DataChatCommandRouter {
  final DatabasePort database;
  final DataExportService exporter;
  const DataChatCommandRouter({
    this.database = const NativeSqliteGateway(),
    this.exporter = const DataExportService(),
  });

  Future<ChatTurnRouteResult?> tryRoute(String input) async {
    final text = input.trim();
    final createDatabase = RegExp(
      r'^(?:datos:\s*)?crea(?:r)?\s+(?:una\s+)?base\s+de\s+datos(?:\s+llamada)?\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*$',
      caseSensitive: false,
    ).firstMatch(text);
    if (createDatabase != null) {
      return _run(() async {
        final path = await database.createDatabase(createDatabase.group(1)!);
        return 'Base SQLite creada y verificada.\nRuta: $path';
      });
    }

    final createTable = RegExp(
      r'^(?:datos:\s*)?crea(?:r)?\s+(?:una\s+)?tabla\s+([a-zA-Z_][a-zA-Z0-9_]*)(?:\s+en\s+(?:la\s+)?base\s+([a-zA-Z_][a-zA-Z0-9_]*))?\s+con\s+columnas\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (createTable != null) {
      return _run(() async {
        final path = createTable.group(2) == null
            ? await database.ensureDefaultDatabase()
            : await database.createDatabase(createTable.group(2)!);
        final columns = _parseColumns(createTable.group(3)!);
        await database.createTable(
          path: path,
          table: createTable.group(1)!,
          columns: columns,
        );
        final tables = await database.listTables(path);
        return 'Tabla creada realmente: ${createTable.group(1)}.\nColumnas: ${columns.map((c) => '${c.name} ${c.type}').join(', ')}\nRuta: $path\nTablas verificadas: ${tables.join(', ')}';
      });
    }

    final sql = RegExp(
      r'^(?:datos:\s*)?(?:sql:|consulta\s+sql:?)[\s]*(.+)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);
    if (sql != null) {
      return _run(() async {
        final path = await database.ensureDefaultDatabase();
        final result = await database.execute(path: path, query: sql.group(1)!);
        if (!result.isSuccess) {
          throw StateError(
            result.errorMessage ?? 'SQLite rechazó la consulta.',
          );
        }
        return _receipt(result, path);
      });
    }

    final export = RegExp(
      r'^(?:datos:\s*)?exporta(?:r)?\s+(?:la\s+)?tabla\s+([a-zA-Z_][a-zA-Z0-9_]*)(?:\s+de\s+(?:la\s+)?base\s+([a-zA-Z_][a-zA-Z0-9_]*))?\s+(?:a|en)\s+(csv|tsv|html|pdf)\s*$',
      caseSensitive: false,
    ).firstMatch(text);
    if (export != null) {
      return _run(() async {
        final path = export.group(2) == null
            ? await database.ensureDefaultDatabase()
            : await database.createDatabase(export.group(2)!);
        final tableName = export.group(1)!;
        final result = await database.execute(
          path: path,
          query: 'SELECT * FROM "$tableName" LIMIT 5000;',
        );
        if (!result.isSuccess || result.table == null) {
          throw StateError(
            result.errorMessage ?? 'No se pudo leer $tableName.',
          );
        }
        final table = result.table!.copyWith(name: tableName);
        final format = export.group(3)!.toLowerCase();
        final output = switch (format) {
          'csv' => await exporter.exportDelimited(table),
          'tsv' => await exporter.exportDelimited(table, tsv: true),
          'html' => await exporter.exportHtml(
            table,
            DataReportConfig(title: 'Informe $tableName'),
          ),
          _ => await exporter.exportPdf(
            table,
            DataReportConfig(title: 'Informe $tableName'),
          ),
        };
        return 'Exportación $format completada y verificada.\nFilas: ${table.rowCount}\nArchivo: $output';
      });
    }
    return null;
  }

  static List<DatabaseColumnDefinition> _parseColumns(String raw) {
    final columns = <DatabaseColumnDefinition>[];
    for (final item in raw.split(',')) {
      final parts = item.trim().split(RegExp(r'\s+'));
      if (parts.isEmpty || parts.first.isEmpty) continue;
      final typeText = parts.skip(1).join(' ').toLowerCase();
      final type = typeText.contains('entero') || typeText == 'int'
          ? 'INTEGER'
          : typeText.contains('real') ||
                typeText.contains('decimal') ||
                typeText.contains('numero')
          ? 'REAL'
          : typeText.contains('blob') || typeText.contains('binario')
          ? 'BLOB'
          : 'TEXT';
      columns.add(DatabaseColumnDefinition(parts.first, type: type));
    }
    if (columns.isEmpty) {
      throw const FormatException('Indica columnas separadas por coma.');
    }
    return columns;
  }

  static String _receipt(QueryResult result, String path) {
    final table = result.table;
    if (table == null || table.columns.isEmpty) {
      return 'SQL ejecutado realmente. Filas afectadas: ${result.affectedRows ?? 0}.\nBase: $path';
    }
    final preview = table.rows
        .take(8)
        .map((row) => row.map((value) => '$value').join(' | '))
        .join('\n');
    return 'SQL ejecutado en ${result.executionTimeMs} ms.\n${table.columns.join(' | ')}\n$preview\nFilas devueltas: ${table.rowCount}\nBase: $path';
  }

  static Future<ChatTurnRouteResult> _run(
    Future<String> Function() action,
  ) async {
    try {
      return _message(await action(), MessageStatus.sent);
    } catch (error) {
      return _message(
        'La operación de datos no se completó: $error',
        MessageStatus.error,
      );
    }
  }

  static ChatTurnRouteResult _message(String text, MessageStatus status) =>
      ChatTurnRouteResult.completed(
        ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sender: MessageSender.ai,
          text: text,
          timestamp: DateTime.now(),
          status: status,
          source: MessageSource.device,
        ),
      );
}
