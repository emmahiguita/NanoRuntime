import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Acciones secundarias de ventana compactas sin sobrecargar la barra.
///
/// - QUÉ HACE: Despliega el menú emergente de opciones secundarias con ancho controlado.
/// - CÓMO FUNCIONA: Usa un botón PopupMenu de 34x34 con icono de 18px.
/// - POR QUÉ: Optimiza el espacio disponible para el campo de dirección web (<200 líneas).
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final actions = <String, (String, IconData, VoidCallback?)>{
      if (onOptions != null)
        'options': ('Opciones de página', CupertinoIcons.slider_horizontal_3, onOptions),
      if (onBack != null)
        'back': ('Página anterior', CupertinoIcons.arrow_left, canGoBack ? onBack : null),
      if (onForward != null)
        'forward': ('Página siguiente', CupertinoIcons.arrow_right, canGoForward ? onForward : null),
      if (onReload != null)
        'reload': ('Recargar página', CupertinoIcons.arrow_clockwise, onReload),
      if (onMinimize != null)
        'minimize': (minimized ? 'Restaurar ventana' : 'Minimizar ventana', CupertinoIcons.minus, onMinimize),
      if (onMaximize != null)
        'maximize': (maximized ? 'Restaurar tamaño' : 'Ampliar ventana', CupertinoIcons.arrow_up_left_arrow_down_right, onMaximize),
      if (onClose != null)
        'close': ('Cerrar pestaña', CupertinoIcons.xmark, onClose),
    };

    return SizedBox(
      width: 34,
      height: 34,
      child: PopupMenuButton<String>(
        tooltip: 'Acciones del navegador',
        useRootNavigator: true,
        padding: EdgeInsets.zero,
        icon: Icon(CupertinoIcons.ellipsis_vertical, size: 17, color: isDark ? Colors.white70 : Colors.black87),
        constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
        onSelected: (action) => actions[action]?.$3?.call(),
        itemBuilder: (_) => [
          for (final entry in actions.entries)
            PopupMenuItem(
              value: entry.key,
              enabled: entry.value.$3 != null,
              child: Row(
                children: [
                  Icon(entry.value.$2, size: 17),
                  const SizedBox(width: 10),
                  Expanded(child: Text(entry.value.$1, style: const TextStyle(fontSize: 13.5))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
