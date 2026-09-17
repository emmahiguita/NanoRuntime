/// Calculador adaptativo de trayectorias gestuales — Nano Mobile Engine
///
/// Responsabilidad Única (SRP):
/// Calcula coordenadas de inicio y fin para desplazamientos (swipe)
/// basándose en el contenedor desplazable o dimensiones reales de la ventana,
/// evitando coordenadas absolutas fijas que fallan en diferentes densidades y orientaciones.
library;

import '../perception/nano_snapshot.dart';

final class SwipeCoordinates {
  const SwipeCoordinates({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
  });

  final int startX;
  final int startY;
  final int endX;
  final int endY;
}

abstract final class AdaptiveSwipeCalculator {
  /// Calcula la trayectoria gestual adaptada a la geometría observada.
  static SwipeCoordinates calculate({
    required String direction,
    required NanoSnapshot snapshot,
  }) {
    // 1. Buscar un contenedor desplazable visible (ListView, ScrollView, RecyclerView)
    final scrollables = snapshot.visibleNodes
        .where((n) => n.scrollable)
        .toList();

    final NanoBounds targetArea;
    if (scrollables.isNotEmpty) {
      targetArea = scrollables.first.bounds;
    } else if (snapshot.nodes.isNotEmpty) {
      // 2. Usar la geometría realmente observada; nunca asumir 1080x2400.
      final candidates = snapshot.visibleNodes.isNotEmpty
          ? snapshot.visibleNodes
          : snapshot.nodes;
      var minL = candidates.first.bounds.left;
      var minT = candidates.first.bounds.top;
      var maxR = candidates.first.bounds.right;
      var maxB = candidates.first.bounds.bottom;
      for (final node in candidates.skip(1)) {
        if (node.bounds.left < minL) minL = node.bounds.left;
        if (node.bounds.top < minT) minT = node.bounds.top;
        if (node.bounds.right > maxR) maxR = node.bounds.right;
        if (node.bounds.bottom > maxB) maxB = node.bounds.bottom;
      }
      targetArea = NanoBounds(
        left: minL,
        top: minT,
        right: maxR > minL ? maxR : minL + 1,
        bottom: maxB > minT ? maxB : minT + 1,
      );
    } else {
      throw StateError('No hay geometría observable para calcular el swipe.');
    }

    final cx = targetArea.centerX;
    final cy = targetArea.centerY;
    final h = targetArea.height;
    final w = targetArea.width;

    // Aplicar márgenes de seguridad para evitar barras del sistema o navegación gestual
    switch (direction.toLowerCase()) {
      case 'down':
        return SwipeCoordinates(
          startX: cx,
          startY: (targetArea.top + (h * 0.25)).toInt(),
          endX: cx,
          endY: (targetArea.top + (h * 0.75)).toInt(),
        );
      case 'left':
        return SwipeCoordinates(
          startX: (targetArea.left + (w * 0.80)).toInt(),
          startY: cy,
          endX: (targetArea.left + (w * 0.20)).toInt(),
          endY: cy,
        );
      case 'right':
        return SwipeCoordinates(
          startX: (targetArea.left + (w * 0.20)).toInt(),
          startY: cy,
          endX: (targetArea.left + (w * 0.80)).toInt(),
          endY: cy,
        );
      case 'up':
      default:
        return SwipeCoordinates(
          startX: cx,
          startY: (targetArea.top + (h * 0.75)).toInt(),
          endX: cx,
          endY: (targetArea.top + (h * 0.25)).toInt(),
        );
    }
  }
}
