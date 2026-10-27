import 'package:flutter/material.dart';
import 'browser_display_mode.dart';
import 'browser_icon_button.dart';
import 'browser_view_mode_button.dart';

/// Acciones globales de las ventanas; conserva las tres vistas existentes.
class BrowserWindowStackBar extends StatelessWidget {
  final int tabCount;
  final bool allMinimized;
  final VoidCallback onToggleAllMinimized, onAddTab, onOpenCarousel;
  final VoidCallback onOpenFocused, onOpenOptions;
  final VoidCallback? onExit;
  const BrowserWindowStackBar({
    super.key,
    required this.tabCount,
    required this.allMinimized,
    required this.onToggleAllMinimized,
    required this.onAddTab,
    required this.onOpenCarousel,
    required this.onOpenFocused,
    required this.onOpenOptions,
    this.onExit,
  });

  /// El título puede truncar, pero los botones nunca se reducen a 22 píxeles.
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: Row(
      children: [
        if (onExit != null)
          BrowserIconButton(
            icon: Icons.arrow_back_rounded,
            label: 'Volver a Automatización',
            onPressed: onExit,
          ),
        BrowserIconButton(
          icon: allMinimized
              ? Icons.unfold_more_rounded
              : Icons.unfold_less_rounded,
          label: allMinimized ? 'Restaurar ventanas' : 'Minimizar ventanas',
          onPressed: onToggleAllMinimized,
        ),
        Expanded(
          child: Text(
            '$tabCount pestañas',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        BrowserIconButton(
          icon: Icons.add_rounded,
          label: 'Nueva pestaña',
          onPressed: onAddTab,
        ),
        BrowserViewModeButton(
          mode: BrowserDisplayMode.verticalStack,
          tabCount: tabCount,
          onSelected: (mode) {
            if (mode == BrowserDisplayMode.focused) onOpenFocused();
            if (mode == BrowserDisplayMode.carousel3D) onOpenCarousel();
          },
        ),
        BrowserIconButton(
          icon: Icons.tune_rounded,
          label: 'Opciones de página',
          onPressed: onOpenOptions,
        ),
      ],
    ),
  );
}

/// Regreso desde una ventana ampliada sin duplicar todos sus controles.
class BrowserWindowMaximizedBar extends StatelessWidget {
  final VoidCallback onBackToStack, onOpenOptions;
  final VoidCallback? onExit;
  const BrowserWindowMaximizedBar({
    super.key,
    required this.onBackToStack,
    required this.onOpenOptions,
    this.onExit,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (onExit != null)
        BrowserIconButton(
          icon: Icons.arrow_back_rounded,
          label: 'Volver a Automatización',
          onPressed: onExit,
        ),
      TextButton.icon(
        onPressed: onBackToStack,
        icon: const Icon(Icons.arrow_back_rounded, size: 20),
        label: const Text('Pestañas'),
      ),
      const Spacer(),
      BrowserIconButton(
        icon: Icons.tune_rounded,
        label: 'Opciones de página',
        onPressed: onOpenOptions,
      ),
    ],
  );
}
