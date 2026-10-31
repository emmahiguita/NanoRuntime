// nano_bottom_dock_layer.dart — Posicionamiento de la barra de navegación flotante.
// QUÉ HACE: Sitúa la barra flotante centrada a 14dp sobre el área segura inferior.
// CÓMO FUNCIONA: Aloja Positioned + NanoKeyboardDockGate y delega la renderización a NanoBottomDock.
// POR QUÉ: Permite que la barra flote visiblemente sobre el contenido (< 110 líneas).
library;

import 'package:flutter/material.dart';
import 'nano_bottom_dock.dart';
import 'nano_destination.dart';
import 'nano_keyboard_dock_gate.dart';
import 'nano_universal_input.dart';
import 'nano_dock_size_reporter.dart';

class NanoBottomDockLayer extends StatelessWidget {
  const NanoBottomDockLayer({
    super.key,
    required this.navigationVisible,
    required this.onHeight,
    required this.keyboardVisible,
    required this.landscape,
    required this.media,
    required this.minimized,
    required this.searchExpanded,
    required this.dragOffset,
    required this.destination,
    required this.inputConfig,
    required this.transparent,
    required this.searchHint,
    required this.onSearch,
    required this.onVoice,
    required this.onOpenInput,
    required this.onShowNavigation,
    required this.onConvertToDrawer,
    required this.onToggleSearch,
    required this.onPointerDown,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
    required this.onDestinationSelected,
  });

  final bool navigationVisible;
  final ValueChanged<double> onHeight;
  final bool keyboardVisible, landscape, minimized, searchExpanded, transparent;
  final MediaQueryData media;
  final Offset dragOffset;
  final NanoDestination destination;
  final NanoUniversalInputConfig inputConfig;
  final String searchHint;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onVoice;
  final VoidCallback onOpenInput, onShowNavigation, onConvertToDrawer;
  final VoidCallback onToggleSearch, onPointerDown, onDragStart, onDragEnd;
  final VoidCallback onDragCancel;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final ValueChanged<NanoDestination> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: keyboardVisible
          ? media.viewInsets.bottom + 8
          : media.padding.bottom + 16,
      child: Center(
        child: NanoKeyboardDockGate(
          child: NanoDockSizeReporter(
            onHeight: onHeight,
            child: NanoBottomDock(
              navigationVisible: navigationVisible,
              minimized: minimized,
              searchExpanded: searchExpanded,
              landscape: landscape,
              keyboardVisible: keyboardVisible,
              screenWidth: media.size.width,
              dragOffset: dragOffset,
              destination: destination,
              inputConfig: inputConfig,
              transparent: transparent,
              searchHint: searchHint,
              onSearch: onSearch,
              onVoice: onVoice,
              onOpenInput: onOpenInput,
              onShowNavigation: onShowNavigation,
              onConvertToDrawer: onConvertToDrawer,
              onToggleSearch: onToggleSearch,
              onPointerDown: onPointerDown,
              onDragStart: onDragStart,
              onDragUpdate: onDragUpdate,
              onDragEnd: onDragEnd,
              onDragCancel: onDragCancel,
              onDestinationSelected: onDestinationSelected,
            ),
          ),
        ),
      ),
    );
  }
}
