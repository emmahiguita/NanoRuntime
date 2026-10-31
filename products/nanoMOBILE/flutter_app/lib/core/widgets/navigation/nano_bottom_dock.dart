// nano_bottom_dock.dart — Presentación animada del dock inferior.
// QUÉ HACE: Dibuja el panel de navegación inferior y el panel de escritura/búsqueda.
// CÓMO FUNCIONA: Recibe estado y callbacks; alinea el ancho de ambas cápsulas Liquid Glass.
// POR QUÉ: Mantiene siempre visible la navegación principal separada de la barra de escritura (< 165 líneas).
library;

import 'package:flutter/material.dart';
import 'nano_destination.dart';
import 'nano_multi_use_nav_bar.dart';
import 'nano_nav_mini_pill.dart';
import 'nano_universal_input.dart';

class NanoBottomDock extends StatelessWidget {
  const NanoBottomDock({
    super.key,
    this.navigationVisible = true,
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
    required this.onOpenInput,
    required this.onToggleSearch,
    required this.onDestinationSelected,
    required this.onPointerDown,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
    this.onSearch,
    this.onVoice,
    this.onConvertToDrawer,
  });

  final bool navigationVisible;
  final bool minimized, searchExpanded, landscape, keyboardVisible, transparent;
  final double screenWidth;
  final Offset dragOffset;
  final NanoDestination destination;
  final NanoUniversalInputConfig inputConfig;
  final String searchHint;
  final VoidCallback onShowNavigation, onToggleSearch, onPointerDown;
  final VoidCallback onOpenInput, onDragStart, onDragEnd, onDragCancel;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final ValueChanged<NanoDestination> onDestinationSelected;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onVoice, onConvertToDrawer;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    layoutBuilder: (current, previous) => Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        for (final child in previous)
          IgnorePointer(child: ExcludeSemantics(child: child)),
        if (current != null) current,
      ],
    ),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween(begin: 0.96, end: 1.0).animate(animation),
        child: child,
      ),
    ),
    child: (minimized && inputConfig.toolControls == null)
        ? NanoNavMiniPill(
            key: const ValueKey('minimized'),
            semanticLabel: 'Mostrar navegación',
            toolContext: inputConfig.toolContext,
            destination: destination,
            onExpand: onShowNavigation,
          )
        : _expandedDock(context),
  );

  Widget _expandedDock(BuildContext context) {
    final available = (screenWidth - (landscape ? 24 : 20)).clamp(
      0.0,
      double.infinity,
    );
    final desired = searchExpanded
        ? (landscape ? 700.0 : 480.0)
        : _navigationWidth(context);
    final width = desired.clamp(0.0, available).toDouble();
    return Listener(
      key: const ValueKey('expanded'),
      onPointerDown: (_) => onDragStart(),
      onPointerUp: (_) {
        if (!searchExpanded) onPointerDown();
      },
      onPointerCancel: (_) {
        if (!searchExpanded) onPointerDown();
      },
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        width: width,
        child: NanoMultiUseNavBar(
          dragOffset: dragOffset,
          onDragStart: onDragStart,
          onDragUpdate: onDragUpdate,
          onDragEnd: onDragEnd,
          onDragCancel: onDragCancel,
          navigationVisible: navigationVisible,
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
          onConvertToDrawer: onConvertToDrawer,
        ),
      ),
    );
  }

  /// Calcula dinámicamente el ancho óptimo para los 3 destinos y el Nano FAB.
  double _navigationWidth(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w600);
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    );
    double longest = 0;
    for (final label in ['Inicio', 'Modelos', 'Terminal']) {
      painter.text = TextSpan(text: label, style: style);
      painter.layout();
      if (painter.width > longest) longest = painter.width;
    }
    painter.dispose();
    return ((longest + 20) * 3 + 78).clamp(320.0, 430.0);
  }
}
