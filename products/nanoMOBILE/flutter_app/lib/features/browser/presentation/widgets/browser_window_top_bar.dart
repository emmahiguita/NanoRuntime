// QUÉ: Barra superior estilo Safari iOS para el navegador web de Nano AI.
// CÓMO: Incluye Omnibox central, navegación atrás/adelante, selector de modo y botón de opciones iOS directo.
// POR QUÉ: Evita menús intermedios duplicados y respeta el espacio del botón Drawer superior (< 140 líneas).

import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/navigation/nano_nav_mode_provider.dart';
import '../../domain/browser_tab_model.dart';
import 'browser_display_mode.dart';
import 'browser_icon_button.dart';
import 'browser_view_mode_button.dart';
import 'browser_window_omnibox.dart';

class BrowserWindowTopBar extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final isDrawerMode = ref.watch(
      nanoNavModeProvider.select((s) => s.isDrawerMode),
    );

    final bg = isDark
        ? theme.colorScheme.surface.withValues(alpha: 0.90)
        : theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.92);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.35);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            border: Border(bottom: BorderSide(color: border, width: 0.7)),
          ),
          child: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 520 || isLandscape;
                final showForward = isWide || activeTab.canGoForward;
                final backAction =
                    activeTab.canGoBack ? onBack : (onExit ?? onBack);

                final address = BrowserWindowOmnibox(
                  url: activeTab.url,
                  title: activeTab.title,
                  siteColor: theme.colorScheme.primary,
                  isLandscape: isWide,
                  isLoading: activeTab.isLoading,
                  progress: activeTab.progress,
                  onSubmitted: onNavigate,
                  onReload: onReload,
                  onStop: controller == null
                      ? null
                      : () => controller!.stopLoading(),
                );

                return Padding(
                  padding: EdgeInsets.only(
                    // En modo Drawer superior izquierdo deja 88dp libres para la píldora del búho.
                    left: isDrawerMode ? 88 : 6,
                    right: 6,
                    top: isLandscape ? 2 : 5,
                    bottom: isLandscape ? 2 : 5,
                  ),
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
                      // Abre directamente el menú limpio iOS sin PopupMenu intermedio duplicado.
                      BrowserIconButton(
                        icon: CupertinoIcons.ellipsis_circle,
                        label: 'Opciones del navegador',
                        onPressed: onOpenOptionsMenu,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
