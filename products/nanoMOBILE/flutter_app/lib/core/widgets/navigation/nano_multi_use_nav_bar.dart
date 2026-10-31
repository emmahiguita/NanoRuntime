// nano_multi_use_nav_bar.dart — Panel de navegación inferior flotante Liquid Glass.
//
// QUÉ HACE:
// Integra la cápsula flotante de navegación (Inicio, Modelos, Terminal + FAB),
// el menú expandible del FAB y la barra de escritura con reconocimiento de accesos.
//
// CÓMO FUNCIONA:
// - Renderiza la barra de órdenes contextual (NanoCommandLauncher) o el editor extendido.
// - Renderiza la cápsula flotante inferior con los 3 accesos principales y el Nano FAB.
// - Abre NanoFabMenu directamente anclado sobre el FAB a la derecha sin solapamientos.
//
// POR QUÉ:
// Inyecta la lógica de órdenes y accesos manteniendo fidelidad iOS (< 185 líneas, SOLID).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'nano_command_launcher.dart';
import 'nano_destination.dart';
import 'nano_fab_menu.dart';
import 'nano_glyph.dart';
import 'nano_nav_bar_container.dart';
import 'nano_nav_destinations_dock.dart';
import 'nano_nav_mode_provider.dart';
import 'nano_nav_search_panel.dart';
import 'nano_universal_input.dart';

class NanoMultiUseNavBar extends ConsumerWidget {
  const NanoMultiUseNavBar({
    super.key,
    this.navigationVisible = true,
    this.dragOffset = Offset.zero,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onDragCancel,
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
    this.onConvertToDrawer,
  });

  final NanoDestination selected;
  final ValueChanged<NanoDestination> onDestinationSelected;
  final NanoUniversalInputConfig? inputConfig;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onVoice;
  final VoidCallback onToggleSearch;
  final VoidCallback? onConvertToDrawer;
  final String searchHint;
  final Brightness? brightness;
  final Offset dragOffset;
  final VoidCallback? onDragStart, onDragEnd;
  final VoidCallback? onDragCancel;
  final ValueChanged<DragUpdateDetails>? onDragUpdate;
  final bool navigationVisible;
  final bool searchExpanded, keyboardVisible, transparent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeBrightness = brightness ?? Theme.of(context).brightness;
    final navState = ref.watch(nanoNavModeProvider);
    final showFabMenu = navState.isFabMenuOpen && !keyboardVisible;
    final hasToolLauncher = inputConfig?.toolControls != null;

    final dock = NanoNavDestinationsDock(
      selected: selected,
      brightness: activeBrightness,
      compact: true,
      onSelect: onDestinationSelected,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final showNavigationCapsule = navigationVisible && !keyboardVisible;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 0. MENÚ EXPANDIBLE NANO FAB (anclado a la derecha directamente sobre el FAB)
            if (showFabMenu) ...[
              NanoFabMenu(brightness: activeBrightness),
              const SizedBox(height: 10),
            ],

            // 1. PANEL SUPERIOR: Barra de escritura inyectada con accesos y estado
            if (searchExpanded) ...[
              NanoNavBarContainer(
                brightness: activeBrightness,
                isListening: inputConfig?.isListening ?? false,
                isProcessing: inputConfig?.isGenerating ?? false,
                compact: true,
                transparent: transparent,
                showHandle: false,
                radius: 20,
                child: Row(
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
                  ],
                ),
              ),
              if (showNavigationCapsule) const SizedBox(height: 8),
            ] else if (hasToolLauncher) ...[
              NanoCommandLauncher(
                key: const ValueKey('command-launcher'),
                controls: inputConfig!.toolControls!,
                tool: inputConfig!.toolContext,
                maxWidth: constraints.maxWidth,
                brightness: activeBrightness,
                onWrite: onToggleSearch,
                onNavigate: onToggleSearch,
              ),
              if (showNavigationCapsule) const SizedBox(height: 8),
            ],

            // 2. PANEL INFERIOR: Navegación flotante Liquid Glass única
            if (showNavigationCapsule)
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (_) => onDragStart?.call(),
                onPanUpdate: onDragUpdate,
                onPanEnd: (_) => onDragEnd?.call(),
                onPanCancel: onDragCancel,
                child: Transform.translate(
                  offset: dragOffset,
                  child: NanoNavBarContainer(
                    brightness: activeBrightness,
                    isListening: false,
                    isProcessing: false,
                    compact: true,
                    transparent: transparent,
                    showHandle: false,
                    radius: 32,
                    child: dock,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _InputToggle extends StatelessWidget {
  const _InputToggle({required this.expanded, required this.onTap});
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    tooltip: expanded ? 'Cerrar escritura' : 'Escribir o buscar',
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    icon: NanoGlyph(
      type: expanded ? NanoGlyphType.chevronDown : NanoGlyphType.search,
      size: 20,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}
