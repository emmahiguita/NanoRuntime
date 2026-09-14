import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';

enum DesktopPointerMode { touch, pan, trackpad }

/// Window mode for mobile remote Linux desktop view.
enum DesktopWindowMode { normal, expanded, minimized }

/// Aspect ratio / screen fit mode for remote Linux desktop canvas.
enum DesktopFitMode { fit, fill, native1to1 }

// ─── Palette Extension ───────────────────────────────────────────────────────
extension DesktopChromeExt on NanoColors {
  Color get chromeBase => background.withValues(alpha: 0.94);
  Color get chromeBorder => accent.withValues(alpha: 0.22);
  Color get chromeActive => accent; // #10B981 Cyber Emerald (dark)
}

// ─── Floating Header Widget ─────────────────────────────────────────────────

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
    this.onFullscreen,
    this.onRotate,
    this.onMinimize,
    this.compact = false,
    this.floating = true,
  });

  final NanoColors colors;
  final String status;
  final bool connected;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onHelp;
  final VoidCallback onRefresh;
  final VoidCallback? onFullscreen;
  final VoidCallback? onRotate;
  final VoidCallback? onMinimize;
  final bool compact;
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final h = compact ? 48.0 : 54.0;

    final decoration = BoxDecoration(
      color: Colors.black.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: colors.chromeActive.withValues(alpha: 0.22),
        width: 0.8,
      ),
      boxShadow: const [
        BoxShadow(
          color: Colors.black45,
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ],
    );

    final content = Container(
      height: h,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: decoration,
      child: Row(
        children: [
          _NavBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: 'Volver',
            colors: colors,
            onPressed: onBack,
          ),
          const SizedBox(width: 6),
          _StatusDot(connected: connected, busy: busy, colors: colors),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nano Linux Workspace',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.5,
                    height: 1.1,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  connected ? 'Local RFB • 60 FPS' : status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    color: connected ? colors.chromeActive : Colors.orangeAccent,
                  ),
                ),
              ],
            ),
          ),
          _NavBtn(
            icon: busy ? Icons.hourglass_top_rounded : Icons.refresh_rounded,
            tooltip: 'Reconectar',
            colors: colors,
            onPressed: busy ? null : onRefresh,
            loading: busy,
          ),
          if (onMinimize != null)
            _NavBtn(
              icon: Icons.picture_in_picture_alt_rounded,
              tooltip: 'Minimizar (PiP)',
              colors: colors,
              onPressed: onMinimize,
            ),
          if (onRotate != null)
            _NavBtn(
              icon: Icons.screen_rotation_rounded,
              tooltip: 'Girar pantalla',
              colors: colors,
              onPressed: onRotate,
            ),
          _NavBtn(
            icon: Icons.help_outline_rounded,
            tooltip: 'Ayuda',
            colors: colors,
            onPressed: onHelp,
          ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: content,
      ),
    );
  }
}

// ─── Floating Bottom Dock Widget ─────────────────────────────────────────────

class DesktopStreamBottomBar extends StatelessWidget {
  const DesktopStreamBottomBar({
    super.key,
    required this.colors,
    required this.pointerMode,
    required this.keyboardVisible,
    required this.zoom,
    required this.onTouch,
    this.onPan,
    required this.onTrackpad,
    required this.onKeyboard,
    required this.onZoom,
    this.onCommands,
    required this.onApps,
    required this.onMore,
    this.compact = false,
    this.floating = true,
  });

  final NanoColors colors;
  final DesktopPointerMode pointerMode;
  final bool keyboardVisible;
  final double zoom;
  final VoidCallback onTouch;
  final VoidCallback? onPan;
  final VoidCallback onTrackpad;
  final VoidCallback onKeyboard;
  final VoidCallback onZoom;
  final VoidCallback? onCommands;
  final VoidCallback onApps;
  final VoidCallback onMore;
  final bool compact;
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final barH = compact ? 42.0 : 48.0;
    final iconSz = compact ? 15.0 : 18.0;
    final labelSz = compact ? 9.0 : 10.0;

    final decoration = BoxDecoration(
      color: Colors.black.withValues(alpha: 0.70),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: colors.chromeActive.withValues(alpha: 0.25),
        width: 0.8,
      ),
      boxShadow: const [
        BoxShadow(
          color: Colors.black54,
          blurRadius: 18,
          offset: Offset(0, 4),
        ),
      ],
    );

    final content = Container(
      height: barH,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: decoration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _BottomPill(
            icon: Icons.touch_app_rounded,
            label: 'Touch',
            selected: pointerMode == DesktopPointerMode.touch,
            accent: colors.chromeActive,
            colors: colors,
            iconSize: iconSz,
            labelSize: labelSz,
            onTap: onTouch,
          ),
          if (onPan != null)
            _BottomPill(
              icon: Icons.pan_tool_rounded,
              label: 'Mover',
              selected: pointerMode == DesktopPointerMode.pan,
              accent: colors.chromeActive,
              colors: colors,
              iconSize: iconSz,
              labelSize: labelSz,
              onTap: onPan!,
            ),
          _BottomPill(
            icon: Icons.mouse_rounded,
            label: 'Mouse',
            selected: pointerMode == DesktopPointerMode.trackpad,
            accent: colors.chromeActive,
            colors: colors,
            iconSize: iconSz,
            labelSize: labelSz,
            onTap: onTrackpad,
          ),
          _BottomPill(
            icon: Icons.keyboard_rounded,
            label: 'Keyboard',
            selected: keyboardVisible,
            accent: colors.chromeActive,
            colors: colors,
            iconSize: iconSz,
            labelSize: labelSz,
            onTap: onKeyboard,
          ),
          if (onCommands != null)
            _BottomPill(
              icon: Icons.bolt_rounded,
              label: 'Comandos',
              selected: false,
              accent: colors.chromeActive,
              colors: colors,
              iconSize: iconSz,
              labelSize: labelSz,
              onTap: onCommands!,
            ),
          _BottomPill(
            icon: zoom > 1.0 ? Icons.zoom_out_map_rounded : Icons.zoom_in_rounded,
            label: 'Zoom',
            selected: zoom > 1.0,
            accent: colors.chromeActive,
            colors: colors,
            iconSize: iconSz,
            labelSize: labelSz,
            onTap: onZoom,
          ),
          _BottomPill(
            icon: Icons.apps_rounded,
            label: 'Apps',
            selected: false,
            accent: colors.chromeActive,
            colors: colors,
            iconSize: iconSz,
            labelSize: labelSz,
            onTap: onApps,
          ),
          _BottomPill(
            icon: Icons.more_horiz_rounded,
            label: 'More',
            selected: false,
            accent: colors.chromeActive,
            colors: colors,
            iconSize: iconSz,
            labelSize: labelSz,
            onTap: onMore,
          ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: content,
      ),
    );
  }
}

// ─── Private Components ──────────────────────────────────────────────────────

class _StatusDot extends StatelessWidget {
  const _StatusDot({
    required this.connected,
    required this.busy,
    required this.colors,
  });

  final bool connected;
  final bool busy;
  final NanoColors colors;

  @override
  Widget build(BuildContext context) {
    final dotColor = connected
        ? colors.chromeActive
        : busy
            ? Colors.lightBlueAccent
            : Colors.orangeAccent;

    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: dotColor.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(color: dotColor.withValues(alpha: 0.45), width: 1),
      ),
      child: Center(
        child: Icon(Icons.desktop_windows_rounded, size: 14, color: dotColor),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({
    required this.icon,
    required this.tooltip,
    required this.colors,
    required this.onPressed,
    this.loading = false,
  });

  final IconData icon;
  final String tooltip;
  final NanoColors colors;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final iconColor = Colors.white.withValues(alpha: onPressed == null ? 0.3 : 0.9);

    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          splashColor: colors.chromeActive.withValues(alpha: 0.2),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: loading
                  ? SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(colors.chromeActive),
                      ),
                    )
                  : Icon(icon, size: 18, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomPill extends StatelessWidget {
  const _BottomPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accent,
    required this.colors,
    required this.iconSize,
    required this.labelSize,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color accent;
  final NanoColors colors;
  final double iconSize;
  final double labelSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unselectedFg = Colors.white.withValues(alpha: 0.70);
    final unselectedBg = Colors.white.withValues(alpha: 0.06);
    final unselectedBorder = Colors.white.withValues(alpha: 0.12);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: selected ? accent.withValues(alpha: 0.24) : unselectedBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? accent.withValues(alpha: 0.8) : unselectedBorder,
                  width: 0.9,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: iconSize,
                      color: selected ? accent : unselectedFg,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: labelSize,
                        height: 1,
                        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                        color: selected ? accent : unselectedFg,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
