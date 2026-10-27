// QUÉ: dibuja ejes, área, línea y marcador de una serie estadística.
// CÓMO: recibe valores ya calculados y los proyecta sobre el Canvas.
// POR QUÉ: separa renderizado de interacción y mantiene ambos archivos pequeños.

import 'dart:math' as math;

import 'package:flutter/material.dart';

final class SeriesChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color color;
  final Color gridColor;
  final double progress;
  final int? selected;

  const SeriesChartPainter({
    required this.values,
    required this.labels,
    required this.color,
    required this.gridColor,
    required this.progress,
    required this.selected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 50.0, top = 16.0, right = 12.0, bottom = 30.0;
    final plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final minimum = values.reduce(math.min), maximum = values.reduce(math.max);
    final range = maximum == minimum ? 1.0 : maximum - minimum;
    final grid = Paint()..color = gridColor.withValues(alpha: 0.16);

    // Dibuja cinco referencias verticales con su valor real interpolado.
    for (var tick = 0; tick <= 4; tick++) {
      final y = plot.top + plot.height * tick / 4;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      _text(
        canvas,
        (maximum - range * tick / 4).toStringAsFixed(0),
        Offset(0, y - 6),
        44,
      );
    }

    final points = <Offset>[
      for (var index = 0; index < values.length; index++)
        Offset(
          values.length == 1
              ? plot.center.dx
              : plot.left + plot.width * index / (values.length - 1),
          plot.bottom -
              ((values[index] - minimum) / range * plot.height) * progress,
        ),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    // Rellena el área bajo la curva para mejorar lectura sin inventar valores.
    final fill = Path.from(path)
      ..lineTo(points.last.dx, plot.bottom)
      ..lineTo(points.first.dx, plot.bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          colors: [
            color.withValues(alpha: 0.28),
            color.withValues(alpha: 0.02),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(plot),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final marker = selected;
    if (marker != null && marker < points.length) {
      canvas.drawCircle(points[marker], 6, Paint()..color = color);
      canvas.drawCircle(points[marker], 3, Paint()..color = Colors.white);
    }
    for (final index in {0, values.length ~/ 2, values.length - 1}) {
      final label = index < labels.length ? labels[index] : '${index + 1}';
      _text(canvas, label, Offset(points[index].dx - 28, plot.bottom + 8), 56);
    }
  }

  void _text(Canvas canvas, String value, Offset offset, double width) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(color: gridColor, fontSize: 9),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant SeriesChartPainter old) =>
      old.progress != progress ||
      old.values != values ||
      old.selected != selected;
}
