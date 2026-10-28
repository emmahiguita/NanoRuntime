// QUÉ: barra compacta con cuatro destinos y acceso real a la escritura.
// CÓMO: una sola fila por estado; el editor mantiene sus padres al abrir teclado.
// POR QUÉ: elimina la franja de tirador adicional y conserva el campo/foco existente.
import 'package:flutter/material.dart';
import 'nano_destination.dart';
import 'nano_glyph.dart';
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
      radius: 22,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inline =
              MediaQuery.orientationOf(context) == Orientation.landscape &&
              constraints.maxWidth >= 580 &&
              !keyboardVisible;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!searchExpanded)
                Row(
                  children: [
                    Expanded(child: dock),
                    if (constraints.maxWidth >= 244) ...[
                      const SizedBox(width: 4),
                      _InputToggle(expanded: false, onTap: onToggleSearch),
                    ],
                  ],
                ),
              if (!searchExpanded && constraints.maxWidth < 244)
                _InputToggle(expanded: false, onTap: onToggleSearch),
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
                    if (!keyboardVisible &&
                        inputConfig?.keepDockVisible != true)
                      _InputToggle(expanded: true, onTap: onToggleSearch),
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

/// Acceso a la entrada existente; no representa un quinto destino de navegación.
class _InputToggle extends StatelessWidget {
  const _InputToggle({required this.expanded, required this.onTap});
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    tooltip: expanded ? 'Volver a navegación' : 'Escribir o buscar',
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    icon: NanoGlyph(
      type: expanded ? NanoGlyphType.chevronDown : NanoGlyphType.search,
      size: 21,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}
