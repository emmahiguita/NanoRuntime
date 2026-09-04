import 'package:flutter/widgets.dart';

/// AutomationLayout (UI-REV-13) — ancho de contenido adaptativo por
/// orientación: horizontal respira (1080), vertical conserva el ancho Dev
/// (720). Un solo punto de verdad para los screens del módulo — cada pantalla
/// lo consulta en vez de repetir el número.
abstract final class AutomationLayout {
  static double contentMaxWidth(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width > size.height ? 1080 : 720;
  }
}
