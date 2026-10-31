// QUÉ: Barra superior estilo Safari iOS para el navegador web de Nano AI.
// CÓMO: Incluye Omnibox responsivo con expansión al 100% en edición, soporte HTTP/HTTPS y controles iOS.
// POR QUÉ: Evita malformaciones de ancho, recortes toscos y maximiza el espacio útil de la barra (< 180 líneas).

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

class BrowserWindowTopBar extends ConsumerStatefulWidget {
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
  ConsumerState<BrowserWindowTopBar> createState() => _BrowserWindowTopBarState();
}

class _BrowserWindowTopBarState extends ConsumerState<BrowserWindowTopBar> {
  bool _isEditingAddress = false;

  @override
  Widget build(BuildContext context) {
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
                final showForward = isWide || widget.activeTab.canGoForward;
                final backAction = widget.activeTab.canGoBack
                    ? widget.onBack
                    : (widget.onExit ?? widget.onBack);

                final address = BrowserWindowOmnibox(
                  url: widget.activeTab.url,
                  title: widget.activeTab.title,
                  siteColor: theme.colorScheme.primary,
                  isLandscape: isWide,
                  isLoading: widget.activeTab.isLoading,
                  progress: widget.activeTab.progress,
                  onSubmitted: widget.onNavigate,
                  onReload: widget.onReload,
                  onEditingChanged: (editing) {
                    if (mounted && _isEditingAddress != editing) {
                      setState(() => _isEditingAddress = editing);
                    }
                  },
                  onStop: widget.controller == null
                      ? null
                      : () => widget.controller!.stopLoading(),
                );

                return Padding(
                  padding: EdgeInsets.only(
                    left: (_isEditingAddress || !isDrawerMode) ? 8 : 62,
                    right: 8,
                    top: isLandscape ? 2 : 5,
                    bottom: isLandscape ? 2 : 5,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isEditingAddress
                        ? _buildEditingRow(address, isDark)
                        : _buildNormalRow(
                            address: address,
                            backAction: backAction,
                            showForward: showForward,
                          ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Fila en modo edición: Omnibox expandido al 100% de ancho con botón nativo 'Cancelar'.
  Widget _buildEditingRow(Widget address, bool isDark) {
    final activeColor =
        isDark ? const Color(0xFF38BDF8) : const Color(0xFF007AFF);

    return Row(
      key: const ValueKey('editing_address_row'),
      children: [
        Expanded(child: address),
        CupertinoButton(
          padding: const EdgeInsets.only(left: 10, right: 4),
          minimumSize: const Size(44, 34),
          onPressed: () {
            FocusScope.of(context).unfocus();
            setState(() => _isEditingAddress = false);
          },
          child: Text(
            'Cancelar',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: activeColor,
            ),
          ),
        ),
      ],
    );
  }

  /// Fila de navegación normal con Omnibox centralizado y botones directos iOS.
  Widget _buildNormalRow({
    required Widget address,
    required VoidCallback backAction,
    required bool showForward,
  }) {
    return Row(
      key: const ValueKey('normal_address_row'),
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
            onPressed: widget.activeTab.canGoForward ? widget.onForward : null,
          ),
        const SizedBox(width: 4),
        Expanded(child: address),
        const SizedBox(width: 4),
        BrowserViewModeButton(
          mode: widget.displayMode,
          tabCount: widget.tabCount,
          onSelected: widget.onDisplayMode,
        ),
        BrowserIconButton(
          icon: CupertinoIcons.ellipsis_circle,
          label: 'Opciones del navegador',
          onPressed: widget.onOpenOptionsMenu,
        ),
      ],
    );
  }
}
