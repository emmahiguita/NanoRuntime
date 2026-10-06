// nano_bottom_dock.dart — Presentación animada del dock inferior.
// QUÉ HACE: Dibuja tres puntos o la superficie completa según el estado.
// CÓMO FUNCIONA: Recibe estado y callbacks; no conserva recursos ni timers.
// POR QUÉ: La máquina de ciclo de vida queda separada del layout Material 3.
library;

import 'package:flutter/material.dart';

import 'nano_destination.dart';
import 'nano_multi_use_nav_bar.dart';
import 'nano_nav_mini_pill.dart';
import 'nano_universal_input.dart';

class NanoBottomDock extends StatelessWidget {
  const NanoBottomDock({
    super.key,
    required this.minimized,
    required this.searchExpanded,
    required this.landscape,
    required this.keyboardVisible,
    required this.screenWidth,
    required this.dragOffset,
    required this.destination,
    required this.inputConfig,
    required this.transparent,
    required this.searchHint,
    required this.onShowNavigation,
    required this.onToggleSearch,
    required this.onDestinationSelected,
    required this.onPointerDown,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    this.onSearch,
    this.onVoice,
  });

  final bool minimized, searchExpanded, landscape, keyboardVisible;
  final bool transparent;
  final double screenWidth;
  final Offset dragOffset;
  final NanoDestination destination;
  final NanoUniversalInputConfig inputConfig;
  final String searchHint;
  final VoidCallback onShowNavigation, onToggleSearch, onPointerDown;
  final VoidCallback onDragStart, onDragEnd;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final ValueChanged<NanoDestination> onDestinationSelected;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onVoice;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 260),
    switchInCurve: Curves.easeOutBack,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween(begin: 0.82, end: 1.0).animate(animation),
        child: child,
      ),
    ),
    child: minimized
        ? NanoNavMiniPill(
            key: const ValueKey('minimized'),
            semanticLabel: 'Mostrar navegación',
            onExpand: onShowNavigation,
          )
        : _expandedDock(),
  );

  // El modo expandido mantiene arrastre y búsqueda fuera del estado visual.
  Widget _expandedDock() {
    // Nunca excede el espacio real de un panel estrecho o pantalla dividida.
    final available = (screenWidth - (landscape ? 24 : 20)).clamp(
      0.0,
      double.infinity,
    );
    final desired = searchExpanded
        ? (landscape ? 700.0 : 480.0)
        : (landscape ? 224.0 : 248.0);
    final width = desired.clamp(0.0, available).toDouble();
    return Listener(
      key: const ValueKey('expanded'),
      onPointerDown: (_) {
        if (!searchExpanded) onPointerDown();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        width: width,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: searchExpanded ? null : (_) => onDragStart(),
          onHorizontalDragUpdate: searchExpanded ? null : onDragUpdate,
          onHorizontalDragEnd: searchExpanded ? null : (_) => onDragEnd(),
          child: Transform.translate(
            offset: Offset(dragOffset.dx.clamp(-68.0, 68.0), 0),
            child: NanoMultiUseNavBar(
              selected: destination,
              searchExpanded: searchExpanded,
              keyboardVisible: keyboardVisible,
              onToggleSearch: onToggleSearch,
              transparent: transparent,
              inputConfig: inputConfig,
              searchHint: searchHint,
              onSearch: onSearch,
              onVoice: onVoice,
              onDestinationSelected: onDestinationSelected,
            ),
          ),
        ),
      ),
    );
  }
}
