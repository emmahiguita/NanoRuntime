// QUÉ: tarjetas de indicadores y resúmenes numéricos de Data Studio.
// CÓMO: recibe estadísticas ya calculadas; no conoce tablas ni infraestructura.
// POR QUÉ: separa presentación repetible del flujo asíncrono del tablero.

import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import '../../domain/data_statistics.dart';

class DatabaseMetricCards extends StatelessWidget {
  final DataStatisticsSnapshot data;
  final NanoColors colors;
  const DatabaseMetricCards({
    super.key,
    required this.data,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      _card('FILAS', '${data.rows}', Icons.table_rows_rounded),
      _card('COLUMNAS', '${data.columns}', Icons.view_column_rounded),
      _card('VACÍOS', '${data.nullCells}', Icons.data_array_rounded),
      _card('MOTOR', data.engine.toUpperCase(), Icons.memory_rounded),
    ],
  );

  Widget _card(String label, String value, IconData icon) => Container(
    width: 150,
    padding: const EdgeInsets.all(14),
    decoration: statCardDecoration(colors),
    child: Row(
      children: [
        Icon(icon, color: colors.accent, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 1,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class DatabaseNumericCards extends StatelessWidget {
  final List<NumericColumnStatistics> values;
  final NanoColors colors;
  const DatabaseNumericCards({
    super.key,
    required this.values,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      for (final value in values.take(6))
        Container(
          width: 210,
          padding: const EdgeInsets.all(13),
          decoration: statCardDecoration(colors),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value.column,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Media ${_format(value.mean)}  ·  σ ${_format(value.standardDeviation)}',
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
              Text(
                'Min ${_format(value.min)}  ·  Max ${_format(value.max)}',
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
    ],
  );

  static String _format(double value) =>
      value.abs() >= 1000 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
}

BoxDecoration statCardDecoration(NanoColors colors) => BoxDecoration(
  color: colors.surface,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.45)),
);
