import 'package:flutter/widgets.dart';

/// AutomationLayout (UI-REV-13 / LANDSCAPE-01) — ancho de contenido adaptativo:
/// distingue teléfonos apaisados (altura < 560dp) de tablets y pantallas de escritorio.
/// En teléfonos apaisados, mantiene 720dp (o 2 columnas equilibradas) para evitar
/// que componentes individuales se estiren desproporcionadamente a 1080px.
abstract final class AutomationLayout {
  /// Teléfono rotado horizontalmente (pantalla ancha pero altura restringida).
  static bool isCompactLandscape(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width > size.height && size.height < 560;
  }

  /// Ancho máximo de contenido:
  /// - Tablets grandes / desktop (ancho >= 960 y alto >= 560): 1080
  /// - Teléfonos apaisados y modo portrait estándar: 720
  static double contentMaxWidth(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width >= 960 && size.height >= 560) return 1080;
    return 720;
  }
}

