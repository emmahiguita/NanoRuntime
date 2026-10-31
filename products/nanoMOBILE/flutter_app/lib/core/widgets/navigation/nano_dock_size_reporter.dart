import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Informa la altura real del dock para reservar contenido sin solaparlo.
class NanoDockSizeReporter extends SingleChildRenderObjectWidget {
  const NanoDockSizeReporter({
    super.key,
    required this.onHeight,
    required super.child,
  });
  final ValueChanged<double> onHeight;

  /// Conserva el mismo subárbol del editor durante cambios de presentación.
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _DockSizeRender(onHeight);

  /// Actualiza el destino del informe sin reconstruir controladores o foco.
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _DockSizeRender renderObject,
  ) {
    renderObject.onHeight = onHeight;
  }
}

class _DockSizeRender extends RenderProxyBox {
  _DockSizeRender(this.onHeight);
  ValueChanged<double> onHeight;
  double? _reported;

  /// Entrega una sola actualización por cambio, después de terminar el layout.
  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _reported) return;
    _reported = height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached && _reported == height) onHeight(height);
    });
  }
}
