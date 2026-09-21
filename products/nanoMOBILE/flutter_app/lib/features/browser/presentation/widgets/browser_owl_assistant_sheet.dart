import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../domain/browser_tab_model.dart';
import 'nano_floating_owl_hub_sheet.dart';

/// QUÉ HACE:
/// Facade unificado para invocar el asistente de Búho IA desde el navegador.
///
/// CÓMO FUNCIONA:
/// Delega la presentación en [NanoFloatingOwlHubSheet.show], pasando la pestaña
/// web y el controlador de WebView activos para contextualizar la sesión.
///
/// POR QUÉ:
/// Elimina la duplicación de hojas modales (DRY / Single Responsibility),
/// unificando la experiencia del Asistente Búho en una sola arquitectura limpia.
class BrowserOwlAssistantSheet {
  const BrowserOwlAssistantSheet._();

  /// Muestra la hoja del Búho IA contextualizada con la página web activa.
  static void show(
    BuildContext context, {
    BrowserTabModel? tab,
    InAppWebViewController? controller,
  }) {
    NanoFloatingOwlHubSheet.show(
      context,
      tab: tab,
      controller: controller,
    );
  }
}
