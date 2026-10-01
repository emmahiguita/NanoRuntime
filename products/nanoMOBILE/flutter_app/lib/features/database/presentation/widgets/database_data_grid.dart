// QUÉ: cuadrícula tabular paginada para conjuntos de datos reales.
// CÓMO: PaginatedDataTable solicita únicamente las filas de la página visible.
// POR QUÉ: evita construir miles de celdas a la vez y bloquear la interfaz.

import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import '../../domain/data_models.dart' as dm;

class DatabaseDataGrid extends StatefulWidget {
  final dm.DataTable? table;
  final NanoColors colors;
  const DatabaseDataGrid({
    super.key,
    required this.table,
    required this.colors,
  });

  @override
  State<DatabaseDataGrid> createState() => _DatabaseDataGridState();
}

class _DatabaseDataGridState extends State<DatabaseDataGrid> {
  int _rowsPerPage = 25;
  final _key = GlobalKey<PaginatedDataTableState>();

  @override
  void didUpdateWidget(covariant DatabaseDataGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.table, widget.table)) _key.currentState?.pageTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final table = widget.table;
    if (table == null || table.columns.isEmpty) return _empty();
    final source = _TableRows(table, widget.colors);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth - 20),
          child: PaginatedDataTable(
            key: _key,
            header: Text(
              '${table.name} · ${table.rowCount} registros',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            columns: [
              for (final column in table.columns)
                DataColumn(
                  label: Text(
                    column,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
            source: source,
            rowsPerPage: _rowsPerPage,
            availableRowsPerPage: const [25, 50, 100],
            onRowsPerPageChanged: (value) =>
                setState(() => _rowsPerPage = value ?? 25),
            showFirstLastButtons: true,
            showEmptyRows: false,
            horizontalMargin: 12,
            columnSpacing: 22,
            headingRowColor: WidgetStatePropertyAll(
              widget.colors.surfaceVariant.withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.table_chart_outlined,
          size: 48,
          color: widget.colors.onSurfaceVariant.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 12),
        Text(
          'No hay registros para mostrar',
          style: TextStyle(color: widget.colors.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          'Crea una tabla o importa CSV, Excel, Google Sheets o SQLite',
          style: TextStyle(
            color: widget.colors.onSurfaceVariant.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

class _TableRows extends DataTableSource {
  final dm.DataTable table;
  final NanoColors colors;
  _TableRows(this.table, this.colors);

  @override
  DataRow? getRow(int index) {
    if (index >= table.rows.length) return null;
    final row = table.rows[index];
    return DataRow.byIndex(
      index: index,
      color: WidgetStatePropertyAll(
        index.isEven
            ? colors.surface
            : colors.surfaceVariant.withValues(alpha: 0.15),
      ),
      cells: [
        for (var column = 0; column < table.columnCount; column++)
          DataCell(
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                column < row.length ? '${row[column] ?? '-'}' : '-',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 11,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => table.rowCount;
  @override
  int get selectedRowCount => 0;
}
