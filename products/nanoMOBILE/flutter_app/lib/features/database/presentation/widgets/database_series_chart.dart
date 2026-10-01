// QUÉ: gráfica de serie interactiva con ejes, escala, relleno y detalle por punto.
// CÓMO: transforma valores reales al área de dibujo y selecciona el punto tocado.
// POR QUÉ: permite leer tendencias y cifras exactas en pantallas pequeñas.

import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'database_series_painter.dart';

class AnimatedSeriesChart extends StatefulWidget {
  final List<double> values;
  final List<String> labels;
  final Color color;

  const AnimatedSeriesChart({
    super.key,
    required this.values,
    required this.labels,
    required this.color,
  });

  @override
  State<AnimatedSeriesChart> createState() => _AnimatedSeriesChartState();
}

class _AnimatedSeriesChartState extends State<AnimatedSeriesChart> {
  int? _selected;

  @override
  void didUpdateWidget(covariant AnimatedSeriesChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.values, widget.values)) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.values.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => setState(() {
          _selected = _pointIndex(
            details.localPosition.dx,
            constraints.maxWidth,
          );
        }),
        child: Semantics(
          label:
              'Serie ${widget.values.length} puntos. Toca para ver un valor.',
          child: Stack(
            children: [
              TweenAnimationBuilder<double>(
                // Reinicia la transición cuando llega una serie calculada nueva.
                key: ValueKey(widget.values),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 850),
                curve: Curves.easeOutQuart,
                builder: (_, progress, __) => CustomPaint(
                  painter: SeriesChartPainter(
                    values: widget.values,
                    labels: widget.labels,
                    color: widget.color,
                    gridColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    progress: progress,
                    selected: _selected,
                  ),
                  size: Size(constraints.maxWidth, 230),
                ),
              ),
              if (_selected case final index?)
                Positioned(
                  top: 6,
                  right: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.color.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      child: Text(
                        '${_label(index)} · ${widget.values[index].toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  int _pointIndex(double dx, double width) {
    const left = 50.0, right = 12.0;
    final usable = math.max(1.0, width - left - right);
    final ratio = ((dx - left) / usable).clamp(0.0, 1.0);
    return (ratio * (widget.values.length - 1)).round();
  }

  String _label(int index) => index < widget.labels.length
      ? widget.labels[index]
      : 'Punto ${index + 1}';
}
