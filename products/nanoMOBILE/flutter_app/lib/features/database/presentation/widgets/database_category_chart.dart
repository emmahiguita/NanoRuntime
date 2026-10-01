// QUÉ: gráfica horizontal de distribución categórica con valores y porcentajes.
// CÓMO: anima anchos proporcionales calculados desde frecuencias reales.
// POR QUÉ: etiquetas legibles y tooltips hacen la gráfica útil en móvil.

import 'package:flutter/material.dart';
import '../../domain/data_statistics.dart';

class AnimatedCategoryChart extends StatelessWidget {
  final List<CategoryFrequency> values;
  final Color color;

  const AnimatedCategoryChart({
    super.key,
    required this.values,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final maximum = values.fold<int>(
      0,
      (max, item) => item.count > max ? item.count : max,
    );
    final total = values.fold<int>(0, (sum, item) => sum + item.count);
    return TweenAnimationBuilder<double>(
      // Una lista nueva representa estadísticas nuevas y reinicia la animación.
      key: ValueKey(values),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) => Semantics(
        label: values.map((item) => '${item.label}: ${item.count}').join(', '),
        child: Column(
          children: [
            for (final item in values)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _bar(context, item, maximum, total, progress),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bar(
    BuildContext context,
    CategoryFrequency item,
    int maximum,
    int total,
    double progress,
  ) {
    final percentage = total == 0 ? 0.0 : item.count / total;
    return Tooltip(
      message:
          '${item.label}: ${item.count} (${(percentage * 100).toStringAsFixed(1)}%)',
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final factor = maximum == 0 ? 0.0 : item.count / maximum;
                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 24,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    Container(
                      width: constraints.maxWidth * factor * progress,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '${item.count} · ${(percentage * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
