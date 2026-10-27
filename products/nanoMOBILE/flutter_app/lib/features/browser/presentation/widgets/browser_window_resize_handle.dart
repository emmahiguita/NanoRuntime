import 'package:flutter/material.dart';

/// Redimensión de una ventana, aislada del contenido y de su sesión nativa.
class BrowserWindowResizeHandle extends StatelessWidget {
  final ValueChanged<Offset> onDelta;
  final ValueChanged<bool> onDragging;
  final VoidCallback onToggleSize;
  const BrowserWindowResizeHandle({
    super.key,
    required this.onDelta,
    required this.onDragging,
    required this.onToggleSize,
  });

  /// Mantiene el gesto original y explica su utilidad a lectores de pantalla.
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Arrastra para ajustar tamaño; toca dos veces para alternarlo',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: onToggleSize,
      onPanStart: (_) => onDragging(true),
      onPanEnd: (_) => onDragging(false),
      onPanCancel: () => onDragging(false),
      onPanUpdate: (details) => onDelta(details.delta),
      child: const SizedBox(
        height: 32,
        width: double.infinity,
        child: Icon(Icons.drag_handle_rounded, size: 20),
      ),
    ),
  );
}
