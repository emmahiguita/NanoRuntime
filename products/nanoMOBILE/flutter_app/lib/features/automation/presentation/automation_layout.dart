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
  /// En móvil (vertical y horizontal) aprovecha el 100% del ancho horizontal fluido.
  /// Solo en pantallas ultra-anchas (desktop/monitores >= 1200) aplica contención.
  static double contentMaxWidth(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width >= 1200) return 1080;
    return double.infinity;
  }
}

