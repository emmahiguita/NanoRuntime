import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../domain/browser_tab_model.dart';
import 'browser_display_mode.dart';
import 'browser_icon_button.dart';
import 'browser_view_mode_button.dart';
import 'browser_window_controls.dart';
import 'browser_window_omnibox.dart';

/// Barra superior estilo Safari iOS con omnibox ampliado y distribución optimizada.
///
/// - QUÉ HACE: Aloja navegación, omnibox espacioso, contador de pestañas y menú.
/// - CÓMO FUNCIONA: Asigna más del 70% del ancho al campo de dirección eliminando botones redundantes.
/// - POR QUÉ: Evita que el campo de URL se sienta encogido o solapado en teléfonos (<200 líneas).
class BrowserWindowTopBar extends StatelessWidget {
  final BrowserTabModel activeTab;
  final int tabCount;
  final BrowserDisplayMode displayMode;
  final InAppWebViewController? controller;
  final VoidCallback onBack, onForward, onReload, onOpenOptionsMenu;
  final VoidCallback? onExit, onMinimize, onMaximize, onClose;
  final ValueChanged<String> onNavigate;
  final ValueChanged<BrowserDisplayMode> onDisplayMode;

  const BrowserWindowTopBar({
    super.key,
    required this.activeTab,
    required this.tabCount,
    required this.displayMode,
    required this.controller,
    required this.onBack,
    required this.onForward,
    required this.onReload,
    required this.onOpenOptionsMenu,
    required this.onNavigate,
    required this.onDisplayMode,
    this.onExit,
    this.onMinimize,
    this.onMaximize,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xF00D131F) : const Color(0xF5F8FAFC),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
            width: 0.8,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 500;
            final showForward = isWide;
            final backAction = activeTab.canGoBack ? onBack : (onExit ?? onBack);

            final address = BrowserWindowOmnibox(
              url: activeTab.url,
              title: activeTab.title,
              siteColor: Theme.of(context).colorScheme.primary,
              isLandscape: isWide,
              isLoading: activeTab.isLoading,
              progress: activeTab.progress,
              onSubmitted: onNavigate,
              onReload: onReload,
              onStop: controller == null ? null : () => controller!.stopLoading(),
            );

            final controls = BrowserWindowControls(
              onOptions: onOpenOptionsMenu,
              onMinimize: onMinimize,
              onMaximize: onMaximize,
              onClose: onClose,
            );

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  BrowserIconButton(
                    icon: CupertinoIcons.chevron_left,
                    label: 'Atrás',
                    onPressed: backAction,
                  ),
                  if (showForward)
                    BrowserIconButton(
                      icon: CupertinoIcons.chevron_right,
                      label: 'Adelante',
                      onPressed: activeTab.canGoForward ? onForward : null,
                    ),
                  const SizedBox(width: 4),
                  Expanded(child: address),
                  const SizedBox(width: 4),
                  BrowserViewModeButton(
                    mode: displayMode,
                    tabCount: tabCount,
                    onSelected: onDisplayMode,
                  ),
                  controls,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
