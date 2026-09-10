import 'package:flutter/material.dart';

import 'package:nanoai/core/theme/design_tokens.dart';

enum DesktopPointerMode { touch, trackpad }

/// Chrome móvil de la sesión Linux. Mantiene navegación, estado y acciones
/// fuera del framebuffer para que ningún control intercepte el escritorio.
class DesktopStreamHeader extends StatelessWidget {
  const DesktopStreamHeader({
    super.key,
    required this.colors,
    required this.status,
    required this.connected,
    required this.busy,
    required this.onBack,
    required this.onHelp,
    required this.onRefresh,
    required this.onFullscreen,
    this.compact = false,
  });

  final NanoColors colors;
  final String status;
  final bool connected;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onHelp;
  final VoidCallback onRefresh;
  final VoidCallback onFullscreen;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 56 : 68,
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: compact ? 2 : 7),
      decoration: const BoxDecoration(
        color: Color(0xFF06131F),
        border: Border(bottom: BorderSide(color: Color(0xFF17637A))),
      ),
      child: Row(
        children: [
          _HeaderButton(
            icon: Icons.arrow_back_rounded,
            label: 'Volver',
            onPressed: onBack,
          ),
          const SizedBox(width: 8),
          Icon(Icons.desktop_windows_rounded, color: colors.accent, size: 28),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nano Linux',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF2F8FC),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: connected
                            ? const Color(0xFF23D77A)
                            : busy
                            ? colors.accent
                            : const Color(0xFFFFB454),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        connected ? 'Conectado · local' : status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10.5,
                          height: 1,
                          fontWeight: FontWeight.w600,
                          color: connected
                              ? const Color(0xFF38E58A)
                              : const Color(0xFF9FB3C5),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _HeaderButton(
            icon: Icons.info_outline_rounded,
            label: 'Ayuda',
            onPressed: onHelp,
          ),
          _HeaderButton(
            icon: Icons.refresh_rounded,
            label: 'Reconectar',
            onPressed: busy ? null : onRefresh,
            loading: busy,
          ),
          _HeaderButton(
            icon: Icons.fullscreen_rounded,
            label: 'Pantalla completa',
            onPressed: onFullscreen,
          ),
        ],
      ),
    );
  }
}

class DesktopStreamBottomBar extends StatelessWidget {
  const DesktopStreamBottomBar({
    super.key,
    required this.colors,
    required this.pointerMode,
    required this.keyboardVisible,
    required this.zoom,
    required this.onTouch,
    required this.onTrackpad,
    required this.onKeyboard,
    required this.onZoom,
    required this.onApps,
    required this.onMore,
    this.compact = false,
  });

  final NanoColors colors;
  final DesktopPointerMode pointerMode;
  final bool keyboardVisible;
  final double zoom;
  final VoidCallback onTouch;
  final VoidCallback onTrackpad;
  final VoidCallback onKeyboard;
  final VoidCallback onZoom;
  final VoidCallback onApps;
  final VoidCallback onMore;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 68 : 82,
      padding: EdgeInsets.fromLTRB(6, compact ? 3 : 7, 6, compact ? 4 : 8),
      decoration: const BoxDecoration(
        color: Color(0xFF06131F),
        border: Border(top: BorderSide(color: Color(0xFF17637A))),
      ),
      child: Row(
        children: [
          _BottomAction(
            icon: Icons.touch_app_rounded,
            label: 'Táctil',
            selected: pointerMode == DesktopPointerMode.touch,
            accent: colors.accent,
            onTap: onTouch,
          ),
          _BottomAction(
            icon: Icons.mouse_rounded,
            label: 'Mouse',
            selected: pointerMode == DesktopPointerMode.trackpad,
            accent: colors.accent,
            onTap: onTrackpad,
          ),
          _BottomAction(
            icon: Icons.keyboard_rounded,
            label: 'Teclado',
            selected: keyboardVisible,
            accent: colors.accent,
            onTap: onKeyboard,
          ),
          _BottomAction(
            icon: Icons.zoom_in_map_rounded,
            label: zoom == 1 ? 'Zoom' : '${zoom.toStringAsFixed(1)}×',
            selected: zoom > 1,
            accent: colors.accent,
            onTap: onZoom,
          ),
          _BottomAction(
            icon: Icons.apps_rounded,
            label: 'Apps',
            accent: colors.accent,
            onTap: onApps,
          ),
          _BottomAction(
            icon: Icons.more_horiz_rounded,
            label: 'Más',
            accent: colors.accent,
            onTap: onMore,
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: IconButton(
        onPressed: onPressed,
        tooltip: label,
        icon: loading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF42D9FF),
                ),
              )
            : Icon(icon),
        color: const Color(0xFFB9EFFF),
        disabledColor: const Color(0xFF587080),
        iconSize: 25,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 44, height: 48),
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          child: Material(
            color: selected
                ? accent.withValues(alpha: 0.12)
                : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: selected ? accent : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 25,
                    color: selected ? accent : const Color(0xFFD5E2EA),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9.5,
                      height: 1,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected ? accent : const Color(0xFFBBCAD4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
