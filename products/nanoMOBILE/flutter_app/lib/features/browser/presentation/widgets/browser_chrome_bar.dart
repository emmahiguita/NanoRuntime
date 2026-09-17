import 'package:flutter/material.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';

/// Compact browser toolbar with an address-first visual hierarchy.
class BrowserChromeBar extends StatelessWidget {
  const BrowserChromeBar({
    super.key,
    required this.tab,
    required this.tabCount,
    required this.urlCtrl,
    required this.urlFocus,
    required this.isDark,
    required this.colors,
    required this.onGoBack,
    required this.onGoForward,
    required this.onReload,
    required this.onUrlSubmitted,
    required this.onSslTap,
    required this.onToggleTabBar,
    required this.onMenuAction,
    this.isEmbedded = false,
    this.isMinimized = false,
    this.showTabBar = false,
    this.isCarouselMode = false,
    this.onToggleCarousel,
    this.onToggleMinimize,
    this.onOpenFullscreen,
    this.onTogglePip,
    this.onZoomTap,
    this.onCycleWindowSize,
  });

  final BrowserTabModel tab;
  final int tabCount;
  final TextEditingController urlCtrl;
  final FocusNode urlFocus;
  final bool isDark;
  final dynamic colors;
  final bool isEmbedded;
  final bool isMinimized;
  final bool showTabBar;
  final bool isCarouselMode;
  final VoidCallback onGoBack;
  final VoidCallback onGoForward;
  final VoidCallback onReload;
  final ValueChanged<String> onUrlSubmitted;
  final VoidCallback onSslTap;
  final VoidCallback onToggleTabBar;
  final VoidCallback? onToggleCarousel;
  final VoidCallback? onToggleMinimize;
  final VoidCallback? onOpenFullscreen;
  final VoidCallback? onTogglePip;
  final VoidCallback? onZoomTap;
  final VoidCallback? onCycleWindowSize;
  final ValueChanged<String> onMenuAction;

  @override
  Widget build(BuildContext context) {
    final divider = isDark ? Colors.white10 : const Color(0xFFD9E1EB);
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1420) : const Color(0xFFF4F7FA),
        border: Border(bottom: BorderSide(color: divider)),
      ),
      child: Row(
        children: [
          _ToolbarButton(
            tooltip: 'Atrás',
            icon: Icons.arrow_back_rounded,
            enabled: tab.canGoBack,
            isDark: isDark,
            onPressed: onGoBack,
          ),
          if (tab.canGoForward)
            _ToolbarButton(
              tooltip: 'Adelante',
              icon: Icons.arrow_forward_rounded,
              enabled: true,
              isDark: isDark,
              onPressed: onGoForward,
            ),
          const SizedBox(width: 4),
          Expanded(
            child: _AddressBar(
              tab: tab,
              controller: urlCtrl,
              focusNode: urlFocus,
              isDark: isDark,
              onSubmit: onUrlSubmitted,
              onSslTap: onSslTap,
              onReload: onReload,
              onZoom: onZoomTap ?? () => onMenuAction('show_zoom_sheet'),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: 'Pestañas abiertas',
            child: InkWell(
              onTap: onToggleCarousel ?? onToggleTabBar,
              onLongPress: onToggleTabBar,
              borderRadius: BorderRadius.circular(9),
              child: _TabCounter(
                count: tabCount,
                active: isCarouselMode,
                isDark: isDark,
              ),
            ),
          ),
          if (onCycleWindowSize != null)
            _ToolbarButton(
              tooltip: 'Cambiar tamaño',
              icon: Icons.open_in_full_rounded,
              enabled: true,
              isDark: isDark,
              onPressed: onCycleWindowSize!,
            ),
          _BrowserMenu(
            isEmbedded: isEmbedded,
            isMinimized: isMinimized,
            showTabBar: showTabBar,
            isDark: isDark,
            onSelected: onMenuAction,
          ),
        ],
      ),
    );
  }
}

class _AddressBar extends StatefulWidget {
  const _AddressBar({
    required this.tab,
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.onSubmit,
    required this.onSslTap,
    required this.onReload,
    required this.onZoom,
  });

  final BrowserTabModel tab;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final ValueChanged<String> onSubmit;
  final VoidCallback onSslTap;
  final VoidCallback onReload;
  final VoidCallback onZoom;

  @override
  State<_AddressBar> createState() => _AddressBarState();
}

class _AddressBarState extends State<_AddressBar> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant _AddressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_refresh);
      widget.focusNode.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final focused = widget.focusNode.hasFocus;
    final foreground = widget.isDark ? Colors.white : const Color(0xFF172033);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      height: 40,
      padding: const EdgeInsets.only(left: 10, right: 5),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF111C2A) : Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: focused
              ? const Color(0xFF3B82F6)
              : (widget.isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
          width: focused ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          InkResponse(
            onTap: widget.onSslTap,
            radius: 16,
            child: Icon(
              widget.tab.isSecure
                  ? Icons.lock_rounded
                  : Icons.lock_open_rounded,
              size: 14,
              color: widget.tab.isSecure
                  ? const Color(0xFF22C55E)
                  : const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: focused
                ? TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.go,
                    maxLines: 1,
                    onSubmitted: widget.onSubmit,
                    onTapOutside: (_) => widget.focusNode.unfocus(),
                    style: TextStyle(
                      color: foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    cursorColor: const Color(0xFF3B82F6),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      hintText: 'Buscar o escribir dirección',
                    ),
                  )
                : InkWell(
                    onTap: () {
                      widget.focusNode.requestFocus();
                      widget.controller.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: widget.controller.text.length,
                      );
                    },
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.tab.displayHost,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
          ),
          InkResponse(
            onTap: widget.onZoom,
            radius: 18,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
              child: Text(
                'aA',
                style: TextStyle(
                  color: foreground.withValues(alpha: 0.68),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          InkResponse(
            onTap: widget.onReload,
            radius: 18,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                widget.tab.isLoading
                    ? Icons.close_rounded
                    : Icons.refresh_rounded,
                size: 17,
                color: foreground.withValues(alpha: 0.64),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.isDark,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;
  final bool isDark;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: 19),
      color: isDark ? Colors.white70 : const Color(0xFF475569),
      disabledColor: isDark ? Colors.white24 : const Color(0xFFB8C2D0),
    );
  }
}

class _TabCounter extends StatelessWidget {
  const _TabCounter({
    required this.count,
    required this.active,
    required this.isDark,
  });

  final int count;
  final bool active;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? accent.withValues(alpha: 0.16) : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: active
              ? accent
              : (isDark ? Colors.white38 : const Color(0xFF64748B)),
        ),
      ),
      child: active
          ? Icon(Icons.view_carousel_outlined, size: 17, color: accent)
          : Text(
              '$count',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF334155),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

class _BrowserMenu extends StatelessWidget {
  const _BrowserMenu({
    required this.isEmbedded,
    required this.isMinimized,
    required this.showTabBar,
    required this.isDark,
    required this.onSelected,
  });

  final bool isEmbedded;
  final bool isMinimized;
  final bool showTabBar;
  final bool isDark;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Más opciones',
      onSelected: onSelected,
      constraints: const BoxConstraints(minWidth: 230, maxWidth: 270),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      icon: Icon(
        Icons.more_vert_rounded,
        color: isDark ? Colors.white70 : const Color(0xFF475569),
      ),
      itemBuilder: (_) => [
        _MenuItem(
          value: 'new_tab',
          icon: Icons.add_box_outlined,
          label: 'Nueva pestaña',
        ),
        _MenuItem(
          value: 'toggle_tabs',
          icon: Icons.tab_rounded,
          label: showTabBar ? 'Ocultar pestañas' : 'Mostrar pestañas',
        ),
        _MenuItem(
          value: 'toggle_carousel',
          icon: Icons.view_carousel_outlined,
          label: 'Vista 3D de pestañas',
        ),
        _MenuItem(
          value: 'find_in_page',
          icon: Icons.find_in_page_outlined,
          label: 'Buscar en la página',
        ),
        if (isEmbedded)
          _MenuItem(
            value: 'fullscreen',
            icon: Icons.open_in_full_rounded,
            label: 'Pantalla completa',
          ),
        _MenuItem(
          value: 'pip_mode',
          icon: Icons.picture_in_picture_alt_outlined,
          label: 'Reproductor flotante',
        ),
        if (isEmbedded)
          _MenuItem(
            value: 'toggle_minimize',
            icon: isMinimized
                ? Icons.unfold_more_rounded
                : Icons.unfold_less_rounded,
            label: isMinimized ? 'Expandir navegador' : 'Minimizar navegador',
          ),
        const PopupMenuDivider(),
        _MenuItem(
          value: 'open_options_sheet',
          icon: Icons.tune_rounded,
          label: 'Todas las opciones',
        ),
      ],
    );
  }
}

class _MenuItem extends PopupMenuItem<String> {
  _MenuItem({
    required String value,
    required IconData icon,
    required String label,
  }) : super(
         value: value,
         height: 44,
         child: Row(
           children: [
             Icon(icon, size: 18),
             const SizedBox(width: 12),
             Text(label, style: const TextStyle(fontSize: 13)),
           ],
         ),
       );
}
