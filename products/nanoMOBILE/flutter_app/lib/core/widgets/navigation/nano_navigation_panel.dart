// nano_navigation_panel.dart — Máquina de estados del dock flotante.
// QUÉ HACE: Alterna entre tres puntos, cuatro destinos y escritura contextual.
// CÓMO FUNCIONA: Colapsa tras inactividad y adapta ancho/altura al teclado.
// POR QUÉ: El dock no reserva pantalla cuando el usuario no lo está usando.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'nano_bottom_dock.dart';
import 'nano_keyboard_dock_gate.dart';
import 'nano_dock_viewport.dart';
import 'nano_destination.dart';
import 'nano_nav_constants.dart';
import 'nano_nav_dock_mode.dart';
import 'nano_side_dock_rail.dart';
import 'nano_universal_input.dart';
export 'nano_nav_constants.dart'
    show kNanoBarScrollReserve, kNanoBarScrollReserveLandscape;
export 'nano_nav_dock_mode.dart' show NanoNavDockMode;
export 'nano_shell_bar_scope.dart' show NanoShellBarScope;

part 'nano_floating_navigation_frame.dart';

enum _NanoPanelMode { minimized, navigation, search }

class _NanoFloatingNavigationFrameState
    extends ConsumerState<NanoFloatingNavigationFrame> {
  late NanoNavDockMode _dockMode = widget.allowSideDock
      ? widget.initialDockMode
      : NanoNavDockMode.bottom;
  _NanoPanelMode _panelMode = _NanoPanelMode.minimized;
  Timer? _idleTimer;
  Offset _dragOffset = Offset.zero;
  // Abre la barra. Si la pantalla activa requiere entrada constante (ej. Terminal),
  // se expande directamente a modo escritura ('search') para programar al instante.
  void _showNavigation({bool directSearch = false}) {
    _idleTimer?.cancel();
    setState(() {
      _dockMode = NanoNavDockMode.bottom;
      _panelMode = directSearch ? _NanoPanelMode.search : _NanoPanelMode.navigation;
    });
    if (!directSearch) _armIdleCollapse();
  }

  void _armIdleCollapse() {
    _idleTimer?.cancel();
    // Tocar el editor también dispara PointerDown: no debe armar cierre mientras
    // se escribe o se espera un resultado. Sólo navegación tiene reposo automático.
    if (_panelMode == _NanoPanelMode.search) return;
    _idleTimer = Timer(kNanoDockIdleCollapseDelay, _collapse);
  }

  // Reduce al 100%: deja únicamente la píldora compartida de tres puntos.
  void _collapse({bool dismissKeyboard = false}) {
    _idleTimer?.cancel();
    if (!mounted) return;
    // El reposo del dock no debe cancelar un campo de búsqueda de otro módulo.
    if (dismissKeyboard) FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _panelMode = _NanoPanelMode.minimized;
      _dragOffset = Offset.zero;
    });
  }

  void _toggleSearch() {
    _idleTimer?.cancel();
    final closing = _panelMode == _NanoPanelMode.search;
    if (closing) FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _panelMode = closing ? _NanoPanelMode.navigation : _NanoPanelMode.search;
    });
    if (closing) _armIdleCollapse();
  }

  // Un arrastre válido envía la píldora al lateral; uno corto reinicia reposo.
  void _finishHorizontalDrag() {
    final side = _dragOffset.dx.abs() > 50;
    setState(() {
      if (_dragOffset.dx < -50) _dockMode = NanoNavDockMode.leftCollapsed;
      if (_dragOffset.dx > 50) _dockMode = NanoNavDockMode.rightCollapsed;
      if (side) _panelMode = _NanoPanelMode.minimized;
      _dragOffset = Offset.zero;
    });
    if (side) {
      HapticFeedback.mediumImpact();
      _idleTimer?.cancel();
    } else {
      _armIdleCollapse();
    }
  }

  @override
  void dispose() {
    // Impide que el callback de reposo sobreviva al árbol de navegación.
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
    final inputConfig = ref.watch(
      nanoUniversalInputProvider.select(
        (_) =>
            ref.read(nanoUniversalInputProvider.notifier).slotFor(targetSlot),
      ),
    );

    // AUTO-ADAPTACIÓN: si la pantalla activa solicita entrada constante (Terminal, etc.)
    // y el panel estaba minimizado, se promueve de inmediato a modo comando/escritura ('search').
    if (inputConfig.keepDockVisible && _panelMode == _NanoPanelMode.minimized) {
      _idleTimer?.cancel();
      _panelMode = _NanoPanelMode.search;
    }

    final side = widget.allowSideDock && _dockMode != NanoNavDockMode.bottom;
    final reserve = side || widget.floatOverContent
        ? 0.0
        : (_panelMode == _NanoPanelMode.minimized
              ? 44.0
              : landscape
              ? kNanoBarScrollReserveLandscape
              : kNanoBarScrollReserve);

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
        if (!side)
          Positioned(
            left: 0,
            right: 0,
            bottom: keyboardVisible
                ? media.viewInsets.bottom + 3
                : media.padding.bottom + (landscape ? 4 : 7),
            child: Center(
              child: NanoKeyboardDockGate(
                child: NanoBottomDock(
                  minimized: _panelMode == _NanoPanelMode.minimized,
                  searchExpanded: _panelMode == _NanoPanelMode.search,
                  landscape: landscape,
                  keyboardVisible: keyboardVisible,
                  screenWidth: media.size.width,
                  dragOffset: _dragOffset,
                  destination: destination,
                  inputConfig: inputConfig,
                  transparent: widget.transparentDock,
                  searchHint: widget.searchHint,
                  onSearch: widget.onSearch,
                  onVoice: widget.onVoice,
                  onShowNavigation: () => _showNavigation(
                    directSearch: inputConfig.keepDockVisible,
                  ),
                  onToggleSearch: _toggleSearch,
                  onPointerDown: _armIdleCollapse,
                  onDragStart: () => _idleTimer?.cancel(),
                  onDragUpdate: (event) =>
                      setState(() => _dragOffset += event.delta),
                  onDragEnd: _finishHorizontalDrag,
                  onDestinationSelected: (next) {
                    widget.onDestinationSelected(next.index);
                    _collapse(dismissKeyboard: true);
                  },
                ),
              ),
            ),
          ),
        if (side)
          NanoSideDockRail(
            isLeft: _dockMode == NanoNavDockMode.leftCollapsed,
            top: media.size.height * 0.42,
            onExpandBottom: _showNavigation,
          ),
      ],
    );
  }
}
