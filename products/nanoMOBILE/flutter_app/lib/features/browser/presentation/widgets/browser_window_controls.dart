import 'package:flutter/material.dart';

/// Agrupa acciones secundarias de ventana sin llenar la barra de botones.
/// Cada opción conserva su callback existente; no hay entradas sin acción.
class BrowserWindowControls extends StatelessWidget {
  final VoidCallback? onOptions, onMinimize, onMaximize, onClose;
  final VoidCallback? onBack, onForward, onReload;
  final bool canGoBack, canGoForward, minimized, maximized;
  const BrowserWindowControls({
    super.key,
    this.onOptions,
    this.onMinimize,
    this.onMaximize,
    this.onClose,
    this.onBack,
    this.onForward,
    this.onReload,
    this.canGoBack = false,
    this.canGoForward = false,
    this.minimized = false,
    this.maximized = false,
  });

  /// Las acciones del historial aparecen deshabilitadas si no hay destino.
  @override
  Widget build(BuildContext context) {
    final actions = <String, (String, IconData, VoidCallback?)>{
      if (onOptions != null)
        'options': ('Opciones de página', Icons.tune_rounded, onOptions),
      if (onBack != null)
        'back': (
          'Página anterior',
          Icons.arrow_back_rounded,
          canGoBack ? onBack : null,
        ),
      if (onForward != null)
        'forward': (
          'Página siguiente',
          Icons.arrow_forward_rounded,
          canGoForward ? onForward : null,
        ),
      if (onReload != null)
        'reload': ('Recargar página', Icons.refresh_rounded, onReload),
      if (onMinimize != null)
        'minimize': (
          minimized ? 'Restaurar ventana' : 'Minimizar ventana',
          Icons.minimize_rounded,
          onMinimize,
        ),
      if (onMaximize != null)
        'maximize': (
          maximized ? 'Restaurar tamaño' : 'Ampliar ventana',
          Icons.open_in_full_rounded,
          onMaximize,
        ),
      if (onClose != null)
        'close': ('Cerrar pestaña', Icons.close_rounded, onClose),
    };
    return PopupMenuButton<String>(
      tooltip: 'Acciones del navegador',
      useRootNavigator: true,
      icon: const Icon(Icons.more_vert_rounded, size: 20),
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
      onSelected: (action) => actions[action]?.$3?.call(),
      itemBuilder: (_) => [
        for (final entry in actions.entries)
          PopupMenuItem(
            value: entry.key,
            enabled: entry.value.$3 != null,
            child: Row(
              children: [
                Icon(entry.value.$2, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(entry.value.$1)),
              ],
            ),
          ),
      ],
    );
  }
}
