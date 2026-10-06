// QUÉ: conecta la hoja de opciones con las acciones reales del navegador.
// CÓMO: crea el despachador con la pestaña, WebView y estado visual activos.
// POR QUÉ: el coordinador de ventanas no debe construir menús ni diálogos.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/browser_history_notifier.dart';
import '../../application/browser_webview_registry.dart';
import '../../domain/browser_tab_model.dart';
import 'browser_menu_action_handler.dart';
import 'browser_options_sheet.dart';

abstract final class BrowserOptionsLauncher {
  static Future<void> show({
    required BuildContext context,
    required WidgetRef ref,
    required BrowserTabModel tab,
    required bool isDesktopMode,
    required bool isDarkModeWeb,
    required ValueChanged<String> onNavigate,
    required VoidCallback onToggleCarousel,
    required ValueChanged<double> onZoomChanged,
    required VoidCallback onToggleDesktopMode,
    required VoidCallback onToggleDarkModeWeb,
    required VoidCallback onFindInPage,
  }) {
    final controller = ref
        .read(browserWebViewRegistryProvider)
        .controllerFor(tab.id);
    final handler = BrowserMenuActionHandler(
      context: context,
      ref: ref,
      tab: tab,
      controller: controller,
      currentZoom: tab.zoomLevel,
      isDesktopMode: isDesktopMode,
      isDarkModeWeb: isDarkModeWeb,
      onNavigate: onNavigate,
      onToggleCarousel: onToggleCarousel,
      onZoomChanged: onZoomChanged,
      onToggleDesktopMode: onToggleDesktopMode,
      onToggleDarkModeWeb: onToggleDarkModeWeb,
      onFindInPage: onFindInPage,
    );
    return BrowserOptionsSheet.show(
      context: context,
      tab: tab,
      isBookmarked: ref.read(browserHistoryProvider).isBookmarked(tab.url),
      isDesktopMode: isDesktopMode,
      isDarkModeWeb: isDarkModeWeb,
      onAction: handler.handleAction,
    );
  }
}
