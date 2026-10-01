// QUÉ: tablero profesional de estadísticas derivadas de la tabla visible.
// CÓMO: recibe DataStatisticsSnapshot ya resuelto (el padre manejó el Future).
//       Muestra KPIs, resumen numérico y dos gráficas adaptativas.
// POR QUÉ: ninguna cifra existe hasta haber sido calculada desde las filas actuales.
//
// CAMBIO: antes recibía Future<DataStatisticsSnapshot> y usaba FutureBuilder
// (duplicado con la resolución del padre). Ahora recibe snapshot ya resuelto → SRP limpio.

import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import '../../domain/data_statistics.dart';
import 'database_category_chart.dart';
import 'database_series_chart.dart';
import 'database_stat_cards.dart';

// Recibe snapshot nullable; null = tabla no seleccionada o análisis en curso
class DatabaseStatisticsPanel extends StatelessWidget {
  final DataStatisticsSnapshot? snapshot;
  final NanoColors colors;

  const DatabaseStatisticsPanel({
    super.key,
    required this.snapshot,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final data = snapshot;

    // Sin tabla → mensaje informativo, sin spinner innecesario
    if (data == null) {
      return Center(
        child: Text(
          'Importa o consulta una tabla para calcular estadísticas.',
          style: TextStyle(color: colors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      );
    }

    return _dashboard(data);
  }

  // Dashboard completo: métricas, resumen numérico y gráficas adaptativas
  Widget _dashboard(DataStatisticsSnapshot data) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tarjetas de métricas globales (filas, columnas, tipos, completitud)
        DatabaseMetricCards(data: data, colors: colors),

        // Resumen por columna numérica (min, max, media, stddev)
        if (data.numeric.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Resumen numérico', style: _titleStyle),
          const SizedBox(height: 10),
          DatabaseNumericCards(values: data.numeric, colors: colors),
        ],

        const SizedBox(height: 20),

        // Gráficas adaptativas: en ancho > 760 van lado a lado, sino apiladas
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = <Widget>[
              if (data.categories.isNotEmpty)
                _chartCard(
                  'Distribución · ${data.categoryColumn}',
                  AnimatedCategoryChart(values: data.categories, color: colors.accent),
                ),
              if (data.series.isNotEmpty)
                _chartCard(
                  'Serie real · ${data.seriesColumn}',
                  AnimatedSeriesChart(
                    values: data.series,
                    labels: data.seriesLabels,
                    color: colors.primary,
                  ),
                ),
            ];

            if (cards.isEmpty) {
              return const Text('No hay columnas suficientes para graficar.');
            }

            // Layout responsivo: horizontal en tablet, vertical en móvil
            return constraints.maxWidth > 760
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < cards.length; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: i == cards.length - 1 ? 0 : 12),
                            child: cards[i],
                          ),
                        ),
                    ],
                  )
                : Column(
                    children: [
                      for (final card in cards)
                        Padding(padding: const EdgeInsets.only(bottom: 12), child: card),
                    ],
                  );
          },
        ),
      ],
    ),
  );

  // Tarjeta contenedora de una gráfica con título
  Widget _chartCard(String title, Widget chart) => Container(
    padding: const EdgeInsets.all(14),
    decoration: statCardDecoration(colors),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _titleStyle),
        const SizedBox(height: 14),
        chart,
      ],
    ),
  );

  // Estilo de título consistente con el resto de tarjetas
  TextStyle get _titleStyle => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: colors.onSurface,
  );
}
