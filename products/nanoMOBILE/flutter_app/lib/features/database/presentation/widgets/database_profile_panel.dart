// QUÉ: muestra calidad y completitud por columna de la tabla activa.
// CÓMO: consume DataStatisticsSnapshot ya resuelto (sin FutureBuilder).
//       El padre (_DatabaseWorkspaceTabsState) controla la concurrencia con tokens.
// POR QUÉ: SRP — este widget solo dibuja; la resolución async es responsabilidad del padre.
//
// CAMBIO: de Future<DataStatisticsSnapshot>? a DataStatisticsSnapshot? → sin FutureBuilder,
// sin riesgo de setState sobre widget desmontado.

import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import '../../domain/data_statistics.dart';
import 'database_stat_cards.dart';

// snapshot = null → sin tabla o análisis en progreso (el padre muestra spinner global)
class DatabaseProfilePanel extends StatelessWidget {
  final DataStatisticsSnapshot? snapshot;
  final NanoColors colors;

  const DatabaseProfilePanel({
    super.key,
    required this.snapshot,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final data = snapshot;

    // Sin datos → mensaje simple; el spinner lo maneja el padre con el token
    if (data == null) {
      return Center(
        child: Text(
          'Conecta una tabla para perfilarla.',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
      );
    }

    // Lista de tarjetas: resumen global + una tarjeta por columna
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _summary(data),
        const SizedBox(height: 14),
        for (final column in data.quality) ...[
          _columnCard(column, data.rows),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  // Tarjeta de resumen global: completitud y celdas vacías totales
  Widget _summary(DataStatisticsSnapshot data) => Container(
    padding: const EdgeInsets.all(16),
    decoration: statCardDecoration(colors),
    child: Row(
      children: [
        Icon(Icons.verified_outlined, color: colors.accent, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Completitud general',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                '${(data.completeness * 100).toStringAsFixed(1)}% · '
                '${data.nullCells} celdas vacías',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // Tarjeta por columna: tipo detectado, barra de completitud y conteo de nulos
  Widget _columnCard(ColumnQuality column, int rows) => Container(
    padding: const EdgeInsets.all(14),
    decoration: statCardDecoration(colors),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Nombre de la columna a la izquierda
            Expanded(
              child: Text(
                column.column,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            // Tipo detectado a la derecha (TEXT, INTEGER, REAL…)
            Text(
              column.detectedType,
              style: TextStyle(fontSize: 11, color: colors.accent),
            ),
          ],
        ),
        const SizedBox(height: 9),
        // Barra de progreso: qué porcentaje de filas tiene valor en esta columna
        LinearProgressIndicator(
          value: column.completeness,
          minHeight: 7,
          borderRadius: BorderRadius.circular(8),
          color: colors.primary,
          backgroundColor: colors.surfaceVariant,
        ),
        const SizedBox(height: 6),
        Text(
          '${column.populated} de $rows valores · ${column.missing} vacíos',
          style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
        ),
      ],
    ),
  );
}
