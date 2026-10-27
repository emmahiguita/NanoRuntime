// QUÉ: cuadrícula tabular paginada para conjuntos de datos reales y hojas de Google Sheets.
// CÓMO: PaginatedDataTable solicita únicamente las filas de la página visible y permite edición directa de celdas.
// POR QUÉ: evita construir miles de celdas a la vez y muestra el estado de sincronización sin guiones bajos.

import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import '../../domain/data_models.dart' as dm;

class DatabaseDataGrid extends StatefulWidget {
  final dm.DataTable? table;
  final NanoColors colors;
  final void Function(int rowIndex, int columnIndex, dynamic newValue)? onCellEdit;

  const DatabaseDataGrid({
    super.key,
    required this.table,
    required this.colors,
    this.onCellEdit,
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

  void _editCell(
    BuildContext context,
    int rowIndex,
    int columnIndex,
    dynamic currentValue,
    String columnRawName,
  ) {
    final cleanColName = columnRawName.replaceAll('_', ' ');
    final controller = TextEditingController(text: '${currentValue ?? ''}');
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Editar: $cleanColName', style: const TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fila ${rowIndex + 1} · Valor actual: ${currentValue ?? '-'}',
              style: TextStyle(
                fontSize: 12,
                color: widget.colors.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: cleanColName,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.pop(dialogCtx);
              widget.onCellEdit?.call(rowIndex, columnIndex, text);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final table = widget.table;
    if (table == null || table.columns.isEmpty) return _empty();
    final source = _TableRows(
      table,
      widget.colors,
      onCellTap: widget.onCellEdit != null
          ? (row, col, val, colName) => _editCell(context, row, col, val, colName)
          : null,
    );

    final cleanTableName = table.name.replaceAll('_', ' ');

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth - 20),
          child: PaginatedDataTable(
            key: _key,
            header: Row(
              children: [
                Expanded(
                  child: Text(
                    '$cleanTableName · ${table.rowCount} registros',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (table.isGoogleSheet)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.4),
                      ),
                    ),
                    // El texto depende de la configuración remota de esta tabla.
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sync_rounded, size: 12, color: Color(0xFF10B981)),
                        SizedBox(width: 4),
                        Text(
                          table.syncEndpointUrl == null
                              ? 'Solo lectura'
                              : 'Sync · 15 s',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            columns: [
              for (final column in table.columns)
                DataColumn(
                  label: Text(
                    // Quita el guion bajo en todos los nombres de columnas
                    column.replaceAll('_', ' '),
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
          'Conecta Google Sheets o importa un archivo',
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
  final void Function(int row, int col, dynamic value, String colName)? onCellTap;

  _TableRows(this.table, this.colors, {this.onCellTap});

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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
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
                  if (onCellTap != null) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.edit_note_rounded,
                      size: 14,
                      color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ],
                ],
              ),
            ),
            onTap: onCellTap != null
                ? () {
                    final currentVal = column < row.length ? row[column] : '';
                    final colName = column < table.columns.length
                        ? table.columns[column]
                        : 'col_$column';
                    onCellTap!(index, column, currentVal, colName);
                  }
                : null,
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
