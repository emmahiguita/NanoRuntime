import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../domain/browser_tab_model.dart';
import 'browser_display_mode.dart';
import 'browser_icon_button.dart';
import 'browser_view_mode_button.dart';
import 'browser_window_controls.dart';
import 'browser_window_omnibox.dart';

/// Navegación principal en una fila: salida, historial, dirección y vistas.
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

  /// En teléfonos oculta solo avanzar; nunca reduce el campo ni el área táctil.
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final showForward = constraints.maxWidth >= 430;
        final address = BrowserWindowOmnibox(
          url: activeTab.url,
          title: activeTab.title,
          siteColor: Theme.of(context).colorScheme.primary,
          isLandscape: constraints.maxWidth >= 600,
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
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Row(
            children: [
              if (onExit != null)
                BrowserIconButton(
                  icon: Icons.arrow_back_rounded,
                  label: 'Volver a Automatización',
                  onPressed: onExit,
                ),
              BrowserIconButton(
                icon: Icons.chevron_left_rounded,
                label: 'Página anterior',
                onPressed: activeTab.canGoBack ? onBack : null,
              ),
              if (showForward)
                BrowserIconButton(
                  icon: Icons.chevron_right_rounded,
                  label: 'Página siguiente',
                  onPressed: activeTab.canGoForward ? onForward : null,
                ),
              Expanded(child: address),
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
  );
}
