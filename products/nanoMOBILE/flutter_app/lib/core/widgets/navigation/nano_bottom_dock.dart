// nano_bottom_dock.dart — Presentación animada del dock inferior.
// QUÉ HACE: dibuja el destino reducido o la superficie compacta según el estado.
// CÓMO FUNCIONA: Recibe estado y callbacks; no conserva recursos ni timers.
// POR QUÉ: La máquina de ciclo de vida queda separada del layout Material 3.
library;

import 'package:flutter/material.dart';

import 'nano_destination.dart';
import 'nano_multi_use_nav_bar.dart';
import 'nano_nav_mini_pill.dart';
import 'nano_command_launcher.dart';
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
    required this.onOpenInput,
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
  final VoidCallback onOpenInput;
  final VoidCallback onDragStart, onDragEnd;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final ValueChanged<NanoDestination> onDestinationSelected;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onVoice;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    // La tarjeta saliente solo se desvanece: no conserva acciones ni semántica.
    // Evita que un destino anterior siga siendo pulsable durante la transición.
    layoutBuilder: (current, previous) => Stack(
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
    child: minimized
        ? inputConfig.toolControls != null
              ? NanoCommandLauncher(
                  key: const ValueKey('command-launcher'),
                  controls: inputConfig.toolControls!,
                  tool: inputConfig.toolContext,
                  maxWidth: screenWidth - 20,
                  onWrite: onOpenInput,
                  onNavigate: onShowNavigation,
                )
              : NanoNavMiniPill(
                  key: const ValueKey('minimized'),
                  semanticLabel: 'Mostrar navegación',
                  toolContext: inputConfig.toolContext,
                  destination: destination,
                  onExpand: onShowNavigation,
                )
        : _expandedDock(context),
  );

  // El modo expandido mantiene arrastre y búsqueda fuera del estado visual.
  Widget _expandedDock(BuildContext context) {
    // Nunca excede el espacio real de un panel estrecho o pantalla dividida.
    final available = (screenWidth - (landscape ? 24 : 20)).clamp(
      0.0,
      double.infinity,
    );
    // El ancho se calcula con la escala de texto real: los cuatro nombres
    // conservan espacio antes de que el dock llegue al límite de la pantalla.
    final desired = searchExpanded
        ? (landscape ? 700.0 : 480.0)
        : _navigationWidth(context);
    final width = desired.clamp(0.0, available).toDouble();
    return Listener(
      key: const ValueKey('expanded'),
      // Mientras se mantiene el dedo, el temporizador no puede retirar controles.
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

  /// Usa las mismas métricas de las etiquetas, sin tamaños fijos que recorten
  /// «Modelos» o «Terminal». El límite final siempre es el espacio disponible.
  double _navigationWidth(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w700);
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    );
    double longest = 0;
    for (final label in ['Inicio', 'Modelos', 'Terminal', 'Ajustes']) {
      painter.text = TextSpan(text: label, style: style);
      painter.layout();
      if (painter.width > longest) longest = painter.width;
    }
    painter.dispose();
    return ((longest + 12) * 4 + 62).clamp(312.0, 420.0);
  }
}
