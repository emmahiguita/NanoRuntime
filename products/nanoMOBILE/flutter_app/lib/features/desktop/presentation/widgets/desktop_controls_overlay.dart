import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/features/desktop/presentation/widgets/desktop_stream_chrome.dart';

/// Floating aesthetic control overlay for Nano Linux Remote Desktop.
/// 
/// Complete responsive support for both Horizontal (Landscape) and Vertical (Portrait):
/// - Circular halo hamburger menu button at top-left (respecting notch in landscape).
/// - Floating translucent pill toolbar at top-center with 7 controls:
///   1. Drag / Tools grid (toggles bottom utility dock)
///   2. Minimize (_) -> PiP window
///   3. Maximize / Fullscreen ([ ]) -> Immersive full-screen edge-to-edge
///   4. Close (X) -> Exit session
///   5. Rotate -> Instant toggle between Horizontal & Vertical
///   6. Aspect ratio / Fit -> Fit / Fill (100% complete) / 1:1
///   7. Zoom in (+) -> Incremental zoom
/// - Retractable bottom dock for keyboard, mouse mode, commands, and apps.
class DesktopControlsOverlay extends StatefulWidget {
  final NanoColors colors;
  final String status;
  final bool connected;
  final bool busy;
  final DesktopPointerMode pointerMode;
  final DesktopWindowMode windowMode;
  final DesktopFitMode fitMode;
  final bool keyboardVisible;
  final double zoom;
  final bool isLandscape;
  final VoidCallback onBack;
  final VoidCallback onHelp;
  final VoidCallback onRefresh;
  final VoidCallback? onFullscreen;
  final VoidCallback? onRotate;
  final VoidCallback? onMinimize;
  final VoidCallback? onWindowModeToggle;
  final VoidCallback? onAspectModeToggle;
  final VoidCallback? onZoomIn;
  final VoidCallback onTouch;
  final VoidCallback? onPan;
  final VoidCallback onTrackpad;
  final VoidCallback onKeyboard;
  final VoidCallback onZoom;
  final VoidCallback? onCommands;
  final VoidCallback onApps;
  final VoidCallback onMore;
  final ValueChanged<String>? onLaunchApp;

  const DesktopControlsOverlay({
    super.key,
    required this.colors,
    required this.status,
    required this.connected,
    required this.busy,
    required this.pointerMode,
    this.windowMode = DesktopWindowMode.normal,
    this.fitMode = DesktopFitMode.fit,
    required this.keyboardVisible,
    required this.zoom,
    required this.isLandscape,
    required this.onBack,
    required this.onHelp,
    required this.onRefresh,
    this.onFullscreen,
    this.onRotate,
    this.onMinimize,
    this.onWindowModeToggle,
    this.onAspectModeToggle,
    this.onZoomIn,
    required this.onTouch,
    this.onPan,
    required this.onTrackpad,
    required this.onKeyboard,
    required this.onZoom,
    this.onCommands,
    required this.onApps,
    required this.onMore,
    this.onLaunchApp,
  });

  @override
  State<DesktopControlsOverlay> createState() => _DesktopControlsOverlayState();
}

class _DesktopControlsOverlayState extends State<DesktopControlsOverlay> {
  bool _chromeHidden = false;
  bool _bottomDockVisible = false;
  Timer? _autoHideTimer;

  @override
  void initState() {
    super.initState();
    _resetAutoHideTimer();
  }

  @override
  void didUpdateWidget(DesktopControlsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.connected && !oldWidget.connected) {
      _resetAutoHideTimer();
    }
    if (widget.windowMode != oldWidget.windowMode) {
      if (widget.windowMode == DesktopWindowMode.expanded) {
        _resetAutoHideTimer();
      } else {
        _autoHideTimer?.cancel();
        _chromeHidden = false;
      }
    }
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    super.dispose();
  }

  void _resetAutoHideTimer() {
    _autoHideTimer?.cancel();
    if (!widget.connected) return;

    // Only auto-hide in expanded full-screen mode after 4 seconds of inactivity
    if (widget.windowMode == DesktopWindowMode.expanded &&
        !_bottomDockVisible &&
        !widget.keyboardVisible) {
      _autoHideTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && widget.connected && !_chromeHidden && !widget.keyboardVisible) {
          setState(() => _chromeHidden = true);
        }
      });
    }
  }

  void _showChrome() {
    setState(() => _chromeHidden = false);
    _resetAutoHideTimer();
  }

  void _toggleBottomDock() {
    HapticFeedback.lightImpact();
    setState(() {
      _bottomDockVisible = !_bottomDockVisible;
    });
    _resetAutoHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.colors.chromeActive;
    final padding = MediaQuery.paddingOf(context);
    final isLandscape = widget.isLandscape;
    final isExpanded = widget.windowMode == DesktopWindowMode.expanded;

    final topInset = isLandscape ? (padding.top > 0 ? padding.top : 8.0) : (padding.top + 8.0);
    final leftInset = padding.left > 0 ? (padding.left + 8.0) : 14.0;
    final bottomInset = padding.bottom;

    return Stack(
      fit: StackFit.loose,
      clipBehavior: Clip.none,
      children: [
        // ── 1 & 2. Responsive Top Controls Bar (Zero Overlap in Portrait & Landscape) ──
        AnimatedPositioned(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          top: _chromeHidden ? -100 : topInset,
          left: 0,
          right: 0,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isLandscape ? leftInset : 8.0,
            ),
            child: isLandscape
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _FloatingHaloHamburgerButton(
                          accent: accent,
                          compact: true,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            widget.onMore();
                          },
                        ),
                      ),
                      _FloatingPillToolbar(
                        colors: widget.colors,
                        isExpanded: isExpanded,
                        isLandscape: true,
                        fitMode: widget.fitMode,
                        dockOpen: _bottomDockVisible,
                        onToolsToggle: _toggleBottomDock,
                        onMinimize: () {
                          HapticFeedback.lightImpact();
                          widget.onMinimize?.call();
                        },
                        onFullscreen: () {
                          HapticFeedback.mediumImpact();
                          widget.onFullscreen?.call();
                        },
                        onClose: () {
                          HapticFeedback.lightImpact();
                          widget.onBack();
                        },
                        onRotate: () {
                          HapticFeedback.lightImpact();
                          if (widget.onRotate != null) {
                            widget.onRotate!();
                          } else if (widget.onWindowModeToggle != null) {
                            widget.onWindowModeToggle!();
                          }
                        },
                        onAspectModeToggle: () {
                          HapticFeedback.lightImpact();
                          widget.onAspectModeToggle?.call();
                        },
                        onZoomIn: () {
                          HapticFeedback.lightImpact();
                          if (widget.onZoomIn != null) {
                            widget.onZoomIn!();
                          } else {
                            widget.onZoom();
                          }
                        },
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _FloatingHaloHamburgerButton(
                        accent: accent,
                        compact: true,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onMore();
                        },
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: _FloatingPillToolbar(
                            colors: widget.colors,
                            isExpanded: isExpanded,
                            isLandscape: false,
                            fitMode: widget.fitMode,
                            dockOpen: _bottomDockVisible,
                            onToolsToggle: _toggleBottomDock,
                            onMinimize: () {
                              HapticFeedback.lightImpact();
                              widget.onMinimize?.call();
                            },
                            onFullscreen: () {
                              HapticFeedback.mediumImpact();
                              widget.onFullscreen?.call();
                            },
                            onClose: () {
                              HapticFeedback.lightImpact();
                              widget.onBack();
                            },
                            onRotate: () {
                              HapticFeedback.lightImpact();
                              if (widget.onRotate != null) {
                                widget.onRotate!();
                              } else if (widget.onWindowModeToggle != null) {
                                widget.onWindowModeToggle!();
                              }
                            },
                            onAspectModeToggle: () {
                              HapticFeedback.lightImpact();
                              widget.onAspectModeToggle?.call();
                            },
                            onZoomIn: () {
                              HapticFeedback.lightImpact();
                              if (widget.onZoomIn != null) {
                                widget.onZoomIn!();
                              } else {
                                widget.onZoom();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        // ── 3. Retractable Bottom Dock Bar (Tools & Keys) ────────────────────
        AnimatedPositioned(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          bottom: (!_bottomDockVisible || _chromeHidden || widget.keyboardVisible)
              ? -140
              : (bottomInset + 8.0),
          left: 0,
          right: 0,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isLandscape ? (padding.left + 24.0) : 10.0,
            ),
            child: DesktopStreamBottomBar(
              colors: widget.colors,
              pointerMode: widget.pointerMode,
              keyboardVisible: widget.keyboardVisible,
              zoom: widget.zoom,
              compact: isLandscape,
              floating: true,
              onTouch: () {
                _resetAutoHideTimer();
                widget.onTouch();
              },
              onPan: widget.onPan == null
                  ? null
                  : () {
                      _resetAutoHideTimer();
                      widget.onPan!();
                    },
              onTrackpad: () {
                _resetAutoHideTimer();
                widget.onTrackpad();
              },
              onKeyboard: () {
                _resetAutoHideTimer();
                widget.onKeyboard();
              },
              onZoom: () {
                _resetAutoHideTimer();
                widget.onZoom();
              },
              onCommands: widget.onCommands == null
                  ? null
                  : () {
                      _resetAutoHideTimer();
                      widget.onCommands!();
                    },
              onApps: () {
                _resetAutoHideTimer();
                widget.onApps();
              },
              onMore: () {
                _resetAutoHideTimer();
                widget.onMore();
              },
            ),
          ),
        ),

        // ── 4. Floating Trigger Pill when controls are hidden ───────────────
        if (_chromeHidden && widget.connected)
          Positioned(
            top: topInset,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showChrome();
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLandscape ? 12 : 14,
                    vertical: isLandscape ? 4 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.45),
                      width: 1.0,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black87,
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Controles',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: isLandscape ? 10.5 : 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 15,
                        color: accent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Circular Hamburger Button with layered glow ring as shown in user reference.
class _FloatingHaloHamburgerButton extends StatelessWidget {
  final Color accent;
  final bool compact;
  final VoidCallback onTap;

  const _FloatingHaloHamburgerButton({
    required this.accent,
    this.compact = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final outerSize = compact ? 38.0 : 44.0;
    final innerSize = compact ? 30.0 : 34.0;
    final iconSize = compact ? 17.0 : 19.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: outerSize,
        height: outerSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x66080C16),
          border: Border.all(
            color: const Color(0x4038BDF8),
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2E0EA5E9),
              blurRadius: 14,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.black54,
              blurRadius: 10,
            ),
          ],
        ),
        child: Center(
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: innerSize,
                height: innerSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xDE0E1424),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                    width: 0.8,
                  ),
                ),
                child: Icon(
                  Icons.menu_rounded,
                  color: Colors.white,
                  size: iconSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating Pill Toolbar containing the 7 icons from the reference image.
class _FloatingPillToolbar extends StatelessWidget {
  final NanoColors colors;
  final bool isExpanded;
  final bool isLandscape;
  final DesktopFitMode fitMode;
  final bool dockOpen;
  final VoidCallback onToolsToggle;
  final VoidCallback onMinimize;
  final VoidCallback onFullscreen;
  final VoidCallback onClose;
  final VoidCallback onRotate;
  final VoidCallback onAspectModeToggle;
  final VoidCallback onZoomIn;

  const _FloatingPillToolbar({
    required this.colors,
    required this.isExpanded,
    required this.isLandscape,
    required this.fitMode,
    required this.dockOpen,
    required this.onToolsToggle,
    required this.onMinimize,
    required this.onFullscreen,
    required this.onClose,
    required this.onRotate,
    required this.onAspectModeToggle,
    required this.onZoomIn,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = colors.chromeActive;
    const pillH = 38.0;
    const btnSz = 30.0;
    const iconSz = 17.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: pillH,
          padding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: const Color(0xE00A0F1D),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0x4D6366F1),
              width: 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black87,
                blurRadius: 18,
                offset: Offset(0, 4),
              ),
              BoxShadow(
                color: Color(0x266366F1),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Drag / Tools grid
              _PillIconBtn(
                icon: Icons.drag_indicator_rounded,
                tooltip: 'Herramientas y Teclas',
                selected: dockOpen,
                activeColor: activeColor,
                size: btnSz,
                iconSize: iconSz,
                onTap: onToolsToggle,
              ),
              const _PillDivider(height: 14),

              // 2. Minimize (_)
              _PillIconBtn(
                icon: Icons.remove_rounded,
                tooltip: 'Minimizar a PiP',
                activeColor: activeColor,
                size: btnSz,
                iconSize: iconSz,
                onTap: onMinimize,
              ),

              // 3. Fullscreen / Expand
              _PillIconBtn(
                icon: isExpanded
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded,
                tooltip: isExpanded ? 'Vista Normal' : 'Pantalla Completa',
                selected: isExpanded,
                activeColor: activeColor,
                size: btnSz,
                iconSize: iconSz,
                onTap: onFullscreen,
              ),

              // 4. Close (X)
              _PillIconBtn(
                icon: Icons.close_rounded,
                tooltip: 'Cerrar / Salir',
                activeColor: activeColor,
                size: btnSz,
                iconSize: iconSz,
                onTap: onClose,
              ),
              const _PillDivider(height: 14),

              // 5. Rotate Screen (Horizontal / Vertical)
              _PillIconBtn(
                icon: Icons.screen_rotation_rounded,
                tooltip: isLandscape
                    ? 'Cambiar a Vertical'
                    : 'Cambiar a Horizontal',
                selected: isLandscape,
                activeColor: activeColor,
                size: btnSz,
                iconSize: iconSz,
                onTap: onRotate,
              ),

              // 6. Aspect Ratio / Fit (Fit, Fill, 1:1)
              _PillIconBtn(
                icon: Icons.fit_screen_rounded,
                tooltip: fitMode == DesktopFitMode.fit
                    ? 'Ajuste: Proporcional'
                    : fitMode == DesktopFitMode.fill
                        ? 'Ajuste: Llenar Completo'
                        : 'Ajuste: 1:1 Nativo',
                selected: fitMode == DesktopFitMode.fill,
                activeColor: activeColor,
                size: btnSz,
                iconSize: iconSz,
                onTap: onAspectModeToggle,
              ),

              // 7. Zoom Plus (+)
              _PillIconBtn(
                icon: Icons.add_rounded,
                tooltip: 'Acercar Zoom',
                activeColor: activeColor,
                size: btnSz,
                iconSize: iconSz,
                onTap: onZoomIn,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillDivider extends StatelessWidget {
  final double height;
  const _PillDivider({this.height = 18});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      color: Colors.white.withValues(alpha: 0.16),
    );
  }
}

class _PillIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final Color activeColor;
  final double size;
  final double iconSize;
  final VoidCallback onTap;

  const _PillIconBtn({
    required this.icon,
    required this.tooltip,
    this.selected = false,
    required this.activeColor,
    this.size = 34,
    this.iconSize = 19,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: selected
                ? BoxDecoration(
                    color: activeColor.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: activeColor.withValues(alpha: 0.6),
                      width: 0.8,
                    ),
                  )
                : null,
            child: Icon(
              icon,
              size: iconSize,
              color: selected ? activeColor : Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ),
      ),
    );
  }
}
