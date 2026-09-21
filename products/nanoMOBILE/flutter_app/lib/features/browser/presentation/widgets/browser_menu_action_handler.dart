import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/browser/application/browser_history_notifier.dart';
import 'package:nanoai/features/browser/application/browser_pip_notifier.dart';
import 'package:nanoai/features/browser/application/browser_tab_notifier.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:nanoai/features/browser/infrastructure/browser_scripts.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_credentials_sheet.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_dialog_helper.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_history_bookmarks_dialog.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_owl_assistant_sheet.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_zoom_sheet.dart';

/// Despachador de acciones del menú de opciones del navegador.
/// 
/// - ¿Qué hace?: Ejecuta las operaciones seleccionadas por el usuario en `BrowserOptionsSheet`.
/// - ¿Cómo funciona?: Mapea la acción textual a llamadas directas sobre Riverpod, WebViews y diálogos.
/// - ¿Por qué?: Desacopla la lógica de ejecución del menú de la vista principal del navegador (SRP).
class BrowserMenuActionHandler {
  final BuildContext context;
  final WidgetRef ref;
  final BrowserTabModel tab;
  final InAppWebViewController? controller;
  final double currentZoom;
  final bool isDesktopMode;
  final bool isDarkModeWeb;
  final ValueChanged<String> onNavigate;
  final VoidCallback onToggleCarousel;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback onToggleDesktopMode;
  final VoidCallback onToggleDarkModeWeb;
  final VoidCallback onFindInPage;

  BrowserMenuActionHandler({
    required this.context,
    required this.ref,
    required this.tab,
    required this.controller,
    required this.currentZoom,
    required this.isDesktopMode,
    required this.isDarkModeWeb,
    required this.onNavigate,
    required this.onToggleCarousel,
    required this.onZoomChanged,
    required this.onToggleDesktopMode,
    required this.onToggleDarkModeWeb,
    required this.onFindInPage,
  });

  Future<void> handleAction(String action) async {
    switch (action) {
      case 'toggle_carousel':
        onToggleCarousel();
        break;
      case 'show_bookmarks':
        BrowserHistoryBookmarksDialog.show(context: context, initialTabIndex: 0, onSelectUrl: onNavigate);
        break;
      case 'show_history':
        BrowserHistoryBookmarksDialog.show(context: context, initialTabIndex: 1, onSelectUrl: onNavigate);
        break;
      case 'new_tab':
        ref.read(browserTabProvider.notifier).addTab();
        break;
      case 'show_zoom_sheet':
        BrowserZoomSheet.show(context: context, tab: tab, currentZoom: currentZoom, controller: controller, onZoomChanged: onZoomChanged);
        break;
      case 'toggle_desktop_mode':
        onToggleDesktopMode();
        break;
      case 'toggle_dark_web':
        onToggleDarkModeWeb();
        break;
      case 'toggle_bookmark':
        final wasBm = ref.read(browserHistoryProvider).isBookmarked(tab.url);
        ref.read(browserHistoryProvider.notifier).toggleBookmark(tab.url, tab.title);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(!wasBm ? 'Marcador guardado' : 'Marcador eliminado'), duration: const Duration(seconds: 2)));
        break;
      case 'find_in_page':
        onFindInPage();
        break;
      case 'pip_mode':
        final ok = await ref.read(browserPipProvider.notifier).activatePip(tabId: tab.id, url: tab.url, title: tab.title, controller: controller);
        if (!ok && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se detectó video HTML5 para PiP')));
        break;
      case 'share':
      case 'copy_url':
        await Clipboard.setData(ClipboardData(text: tab.url));
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(action == 'share' ? 'Enlace copiado para compartir' : 'URL copiada al portapapeles')));
        break;
      case 'show_ssl':
        BrowserDialogHelper.showSslDialog(context, tab);
        break;
      case 'show_credentials':
        final uri = Uri.tryParse(tab.url);
        final domain = uri != null && uri.host.isNotEmpty ? uri.host : null;
        BrowserCredentialsSheet.show(
          context: context,
          currentDomain: domain,
          onAutofill: (u, p) => controller?.evaluateJavascript(source: BrowserScripts.buildAutofillScript(u, p)),
        );
        break;
      case 'ask_owl':
        BrowserOwlAssistantSheet.show(context, tab: tab, controller: controller);
        break;
      case 'clear_cache':
        await InAppWebViewController.clearAllCache();
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Caché limpiada con éxito.')));
        break;
    }
  }
}
