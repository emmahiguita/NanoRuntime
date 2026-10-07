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
      radius: 18,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final landscape =
              MediaQuery.orientationOf(context) == Orientation.landscape;
          final inline =
              landscape && constraints.maxWidth >= 580 && !keyboardVisible;
          // Si la barra está expandida en modo escritura (searchExpanded),
          // los destinos SOLO se muestran si hay espacio horizontal suficiente (inline).
          // En modo vertical convencional jamás se apilan debajo del input para evitar
          // superposiciones visuales grotescas.
          final showDestinations = inline || !searchExpanded;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mantener este lugar en el árbol evita remounts al ocultar el tirador.
              SizedBox(
                height: (keyboardVisible && searchExpanded) || (inputConfig?.keepDockVisible == true && searchExpanded) ? 0 : 28,
                child: (keyboardVisible && searchExpanded) || (inputConfig?.keepDockVisible == true && searchExpanded)
                    ? null
                    : _SearchHandle(
                        expanded: searchExpanded,
                        onTap: onToggleSearch,
                      ),
              ),
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
              if (!inline && showDestinations) dock,
            ],
          );
        },
      ),
    );
  }
}

/// QUÉ HACE: Tirador táctil ergonómico para expandir o contraer la entrada de comandos.
/// CÓMO FUNCIONA: Ofrece un área táctil mínima accesible de 48px con tirador visual sobrio.
/// POR QUÉ: Los estándares móviles de accesibilidad exigen mínimo 48x48 para evitar fallos de toque.
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
        child: SizedBox(
          width: double.infinity,
          height: 28,
          child: Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
