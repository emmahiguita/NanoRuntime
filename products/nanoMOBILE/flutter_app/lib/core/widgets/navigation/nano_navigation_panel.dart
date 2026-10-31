// nano_navigation_panel.dart — Máquina de estados del dock inferior y gestos.
// QUÉ HACE: Coordina la navegación inferior compacta y la delegación al Drawer global.
// CÓMO FUNCIONA: Escucha nanoNavModeProvider; gestiona dock, reservas y menú FAB.
// POR QUÉ: Satisface la especificación oficial y se conserva estrictamente < 185 líneas (SOLID).
library;

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'nano_bottom_dock_layer.dart';
import 'nano_destination.dart';
import 'nano_dock_viewport.dart';
import 'nano_nav_constants.dart';
import 'nano_nav_dock_mode.dart';
import 'nano_nav_mode_provider.dart';
import 'nano_universal_input.dart';

export 'nano_nav_constants.dart'
    show kNanoBarScrollReserve, kNanoBarScrollReserveLandscape;
export 'nano_nav_dock_mode.dart' show NanoNavDockMode;
export 'nano_nav_mode_provider.dart'
    show NanoNavModeNotifier, NanoNavPresentationMode, nanoNavModeProvider;
export 'nano_shell_bar_scope.dart' show NanoShellBarScope;

part 'nano_floating_navigation_frame.dart';

enum _NanoPanelMode { minimized, navigation, search }

class _NanoFloatingNavigationFrameState
    extends ConsumerState<NanoFloatingNavigationFrame> {
  _NanoPanelMode _panelMode = _NanoPanelMode.navigation;
  Timer? _idleTimer;
  bool _toolWasRunning = false;
  Offset _dragOffset = Offset.zero;
  Offset? _dragPosition;
  double _dockHeight = 0;

  void _reportDockHeight(double height) {
    if (!mounted || (height - _dockHeight).abs() < .5) return;
    setState(() => _dockHeight = height);
  }

  void _showNavigation({bool directSearch = false}) {
    _idleTimer?.cancel();
    setState(() {
      _panelMode = directSearch ? _NanoPanelMode.search : _NanoPanelMode.navigation;
      _dragOffset = Offset.zero;
    });
  }

  void _finishHorizontalDrag() {
    final offset = _dragOffset;
    final position = _dragPosition;
    final size = MediaQuery.sizeOf(context);
    final draggedRight = offset.dx > 40 || (position != null && position.dx >= size.width * 0.70);
    final draggedLeft = offset.dx < -40 || (position != null && position.dx <= size.width * 0.30);
    final draggedDown = offset.dy > 25;

    setState(() {
      _dragOffset = Offset.zero;
      _dragPosition = null;
    });

    if (draggedDown && _panelMode != _NanoPanelMode.minimized) {
      HapticFeedback.lightImpact();
      _idleTimer?.cancel();
      setState(() => _panelMode = _NanoPanelMode.minimized);
    } else if (draggedRight || draggedLeft) {
      HapticFeedback.mediumImpact();
      _idleTimer?.cancel();
      ref.read(nanoNavModeProvider.notifier).convertToDrawer(right: false);
    }
  }

  void _cancelHorizontalDrag() => setState(() {
    _dragOffset = Offset.zero;
    _dragPosition = null;
  });

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destination = NanoDestination.fromIndex(widget.selectedIndex);
    final media = MediaQuery.of(context);
    final landscape = media.orientation == Orientation.landscape;
    final keyboardVisible = media.viewInsets.bottom > 0;
    final targetSlot = widget.slotId ?? destination.name;
    final navState = ref.watch(nanoNavModeProvider);

    final inputConfig = ref.watch(
      nanoUniversalInputProvider.select(
        (_) => ref.read(nanoUniversalInputProvider.notifier).slotFor(targetSlot),
      ),
    );

    final toolRunning = inputConfig.toolContext != null && inputConfig.isGenerating;
    if (_toolWasRunning && !toolRunning && inputConfig.toolContext != null &&
        !keyboardVisible && _panelMode == _NanoPanelMode.search) {
      _panelMode = _NanoPanelMode.navigation;
    }
    _toolWasRunning = toolRunning;

    if (inputConfig.keepDockVisible && _panelMode != _NanoPanelMode.search) {
      _idleTimer?.cancel();
      _panelMode = _NanoPanelMode.search;
    }

    final hasSearchBar = _panelMode == _NanoPanelMode.search || inputConfig.toolControls != null;
    final isBottomBar = navState.isBottomBarMode;
    final baseReserve = !isBottomBar
        ? 0.0
        : (hasSearchBar
            ? (landscape ? kNanoBarScrollReserveLandscape : kNanoBarScrollReserve)
            : 58.0);
    final measuredReserve = !isBottomBar ? 0.0 : (_dockHeight + 22.0);
    final reserve = (widget.floatOverContent || !isBottomBar)
        ? 0.0
        : (measuredReserve > baseReserve ? measuredReserve : baseReserve) + media.padding.bottom;

    return Stack(
      fit: StackFit.expand,
      children: [
        NanoDockViewport(
          protectTop: widget.protectTop,
          fullBleed: widget.fullBleed,
          keyboardInset: media.viewInsets.bottom,
          reserve: reserve,
          child: widget.child,
        ),
        // Scrim modal para el menú FAB: aísla el menú y evita cualquier solapamiento
        if (navState.isFabMenuOpen)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => ref.read(nanoNavModeProvider.notifier).closeFabMenu(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: ColoredBox(
                  color: (Theme.of(context).brightness == Brightness.dark
                          ? Colors.black
                          : const Color(0xFF0F172A))
                      .withValues(alpha: 0.32),
                ),
              ),
            ),
          ),
        NanoBottomDockLayer(
          onHeight: _reportDockHeight,
          navigationVisible: navState.isBottomBarMode,
          keyboardVisible: keyboardVisible,
          landscape: landscape,
          media: media,
          minimized: _panelMode == _NanoPanelMode.minimized,
          searchExpanded: _panelMode == _NanoPanelMode.search,
          dragOffset: _dragOffset,
          destination: destination,
          inputConfig: inputConfig,
          transparent: widget.transparentDock,
          searchHint: widget.searchHint,
          onSearch: widget.onSearch,
          onVoice: widget.onVoice,
          onOpenInput: () => _showNavigation(directSearch: true),
          onShowNavigation: () => _showNavigation(),
          onConvertToDrawer: () => ref.read(nanoNavModeProvider.notifier).convertToDrawer(right: false),
          onToggleSearch: () {
            _idleTimer?.cancel();
            final closing = _panelMode == _NanoPanelMode.search;
            if (closing) FocusManager.instance.primaryFocus?.unfocus();
            setState(() => _panelMode = closing ? _NanoPanelMode.navigation : _NanoPanelMode.search);
          },
          onPointerDown: () => _idleTimer?.cancel(),
          onDragStart: () => _idleTimer?.cancel(),
          onDragUpdate: (event) => setState(() {
            final nextDx = (_dragOffset.dx + event.delta.dx).clamp(-160.0, 160.0);
            final nextDy = (_dragOffset.dy + event.delta.dy).clamp(0.0, 50.0);
            _dragOffset = Offset(nextDx, nextDy);
            final box = context.findRenderObject();
            _dragPosition = box is RenderBox ? box.globalToLocal(event.globalPosition) : null;
          }),
          onDragEnd: _finishHorizontalDrag,
          onDragCancel: _cancelHorizontalDrag,
          onDestinationSelected: (next) => widget.onDestinationSelected(next.index),
        ),
      ],
    );
  }
}
