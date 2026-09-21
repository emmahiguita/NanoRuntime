import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import '../../domain/data_models.dart' as dm;

/// Visualizador modular de cuadrícula de datos con soporte bidireccional y sin desbordamientos
class DatabaseDataGrid extends StatelessWidget {
  final dm.DataTable? table;
  final NanoColors colors;

  const DatabaseDataGrid({
    super.key,
    required this.table,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final currentTable = table;

    if (currentTable == null || currentTable.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.table_chart_outlined,
              size: 48,
              color: colors.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No hay registros para mostrar',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Ejecute una consulta o conecte una hoja de cálculo',
              style: TextStyle(
                color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          physics: const BouncingScrollPhysics(),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTableTheme(
                data: DataTableThemeData(
                  headingRowColor: WidgetStateProperty.all(
                    colors.surfaceVariant.withValues(alpha: 0.5),
                  ),
                  dataRowColor: WidgetStateProperty.resolveWith<Color>((states) {
                    return colors.surface;
                  }),
                  headingTextStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                  dataTextStyle: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 11.5,
                    color: colors.onSurface,
                  ),
                  horizontalMargin: 12,
                  columnSpacing: 20,
                  dividerThickness: 0.5,
                ),
                child: DataTable(
                  columns: currentTable.columns.map((col) {
                    return DataColumn(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(col),
                          const SizedBox(width: 4),
                          Text(
                            currentTable.columnTypes[col]?.name.toUpperCase() ?? '',
                            style: TextStyle(
                              fontSize: 9,
                              color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  rows: [
                    for (int r = 0; r < currentTable.rows.length; r++)
                      DataRow(
                        color: WidgetStateProperty.resolveWith<Color?>((states) {
                          return r.isEven
                              ? colors.surface
                              : colors.surfaceVariant.withValues(alpha: 0.15);
                        }),
                        cells: [
                          for (int c = 0; c < currentTable.columns.length; c++)
                            DataCell(
                              Text(
                                c < currentTable.rows[r].length
                                    ? (currentTable.rows[r][c]?.toString() ?? '-')
                                    : '-',
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
