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
import 'package:nanoai/features/browser/presentation/widgets/browser_zoom_sheet.dart';

/// Despachador de acciones del menú de opciones del navegador con feedback flotante.
///
/// - QUÉ HACE: Ejecuta las operaciones seleccionadas con feedback visual inmediato (snackbars flotantes).
/// - CÓMO FUNCIONA: Mapea acciones a Riverpod, WebViews y portapapeles del sistema.
/// - POR QUÉ: Asegura que acciones como favoritos o copiar respondan 100% al usuario (<200 líneas).
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

  void _showFeedback(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xE60F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        duration: const Duration(milliseconds: 1800),
      ),
    );
  }

  Future<void> handleAction(String action) async {
    if (!context.mounted) return;
    try {
      await _executeAction(action);
    } catch (_) {
      _showFeedback('No se pudo completar la acción.');
    }
  }

  Future<void> _executeAction(String action) async {
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
        _showFeedback('Nueva pestaña abierta');
        break;
      case 'show_zoom_sheet':
        BrowserZoomSheet.show(
          context: context,
          tab: tab,
          currentZoom: currentZoom,
          controller: controller,
          onZoomChanged: onZoomChanged,
        );
        break;
      case 'toggle_desktop_mode':
        onToggleDesktopMode();
        _showFeedback(isDesktopMode ? 'Modo móvil activado' : 'Modo escritorio activado');
        break;
      case 'toggle_dark_web':
        onToggleDarkModeWeb();
        _showFeedback(isDarkModeWeb ? 'Modo oscuro web desactivado' : 'Modo oscuro web activado');
        break;
      case 'toggle_bookmark':
        final wasBm = ref.read(browserHistoryProvider).isBookmarked(tab.url);
        ref.read(browserHistoryProvider.notifier).toggleBookmark(tab.url, tab.title);
        _showFeedback(!wasBm ? '⭐ Marcador guardado en Favoritos' : 'Marcador eliminado');
        break;
      case 'find_in_page':
        onFindInPage();
        break;
      case 'pip_mode':
        final ok = await ref.read(browserPipProvider.notifier).activatePip(
          tabId: tab.id,
          url: tab.url,
          title: tab.title,
          controller: controller,
        );
        if (!ok && context.mounted) {
          _showFeedback('No se detectó video HTML5 en reproducción');
        }
        break;
      case 'share':
      case 'copy_url':
        await Clipboard.setData(ClipboardData(text: tab.url));
        _showFeedback('📋 Enlace copiado al portapapeles');
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
          onAutofill: (u, p) => controller?.evaluateJavascript(
            source: BrowserScripts.buildAutofillScript(u, p),
          ),
        );
        break;
      case 'clear_cache':
        await InAppWebViewController.clearAllCache();
        _showFeedback('Caché del navegador eliminada');
        break;
    }
  }
}
