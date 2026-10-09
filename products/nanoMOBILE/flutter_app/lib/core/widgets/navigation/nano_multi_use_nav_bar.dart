// QUÉ: navegación y entrada contextual sin perder texto al abrir el teclado.
// CÓMO: el campo conserva siempre Column → Row → Expanded como padres.
// POR QUÉ: cambiar sus padres recreaba el estado y desconectaba el teclado.
library;

import 'package:flutter/material.dart';
import 'nano_destination.dart';
import 'nano_nav_bar_container.dart';
import 'nano_nav_destinations_dock.dart';
import 'nano_nav_search_panel.dart';
import 'nano_universal_input.dart';

class NanoMultiUseNavBar extends StatelessWidget {
  const NanoMultiUseNavBar({
    super.key,
    required this.selected,
    required this.onDestinationSelected,
    required this.searchExpanded,
    required this.keyboardVisible,
    required this.onToggleSearch,
    this.inputConfig,
    this.onSearch,
    this.onVoice,
    this.searchHint = NanoUniversalInputConfig.defaultHint,
    this.brightness,
    this.transparent = false,
  });
  final NanoDestination selected;
  final ValueChanged<NanoDestination> onDestinationSelected;
  final NanoUniversalInputConfig? inputConfig;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onVoice;
  final VoidCallback onToggleSearch;
  final String searchHint;
  final Brightness? brightness;
  final bool searchExpanded, keyboardVisible, transparent;

  /// Cambia solo el espacio de los destinos: no mueve ni sustituye el editor.
  @override
  Widget build(BuildContext context) {
    final activeBrightness = brightness ?? Theme.of(context).brightness;
    final dock = NanoNavDestinationsDock(
      selected: selected,
      brightness: activeBrightness,
      compact: true,
      onSelect: onDestinationSelected,
    );
    return NanoNavBarContainer(
      brightness: activeBrightness,
      isListening: inputConfig?.isListening ?? false,
      isProcessing: inputConfig?.isGenerating ?? false,
      compact: true,
      transparent: transparent,
      showHandle: false,
      radius: 26,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final landscape =
              MediaQuery.orientationOf(context) == Orientation.landscape;
          final inline =
              landscape && constraints.maxWidth >= 580 && !keyboardVisible;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!searchExpanded)
                SizedBox(
                  height: 52,
                  child: Stack(
                    children: [
                      Positioned.fill(top: 4, child: dock),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _SearchHandle(
                          expanded: false,
                          onTap: onToggleSearch,
                        ),
                      ),
                    ],
                  ),
                ),
              if (searchExpanded &&
                  !keyboardVisible &&
                  inputConfig?.keepDockVisible != true)
                _SearchHandle(expanded: true, onTap: onToggleSearch),
              if (searchExpanded)
                Row(
                  key: const ValueKey('contextual-editor'),
                  children: [
                    Expanded(
                      child: NanoNavSearchPanel(
                        brightness: activeBrightness,
                        compact: true,
                        inputConfig: inputConfig,
                        onSearch: onSearch,
                        onVoice: onVoice,
                        searchHint: searchHint,
                      ),
                    ),
                    if (inline) ...[
                      const SizedBox(width: 8),
                      SizedBox(width: 208, child: dock),
                    ],
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

/// QUÉ HACE: Tirador táctil ergonómico para expandir o contraer la entrada de comandos.
/// CÓMO FUNCIONA: Toda la franja superior abre la escritura; la marca visible es mínima.
/// POR QUÉ: Conserva el acceso al panel sin aumentar la altura visual del dock.
class _SearchHandle extends StatelessWidget {
  const _SearchHandle({required this.expanded, required this.onTap});
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    expanded: expanded,
    label: expanded ? 'Ocultar escritura' : 'Mostrar escritura',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: const SizedBox(
          width: double.infinity,
          height: 22,
          child: Center(child: _GlassHandle()),
        ),
      ),
    ),
  );
}

class _GlassHandle extends StatelessWidget {
  const _GlassHandle();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 32,
      height: 3,
      decoration: BoxDecoration(
        color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: dark ? 0.06 : 0.46),
            blurRadius: 2,
            offset: const Offset(0, -1),
          ),
        ],
      ),
    );
  }
}
