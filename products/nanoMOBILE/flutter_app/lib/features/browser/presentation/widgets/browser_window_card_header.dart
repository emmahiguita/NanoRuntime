import 'package:flutter/material.dart';
import 'browser_window_url_editor.dart';

/// Cabecera de tarjeta: identidad, edición de dirección y un menú de acciones.
class BrowserWindowCardHeader extends StatelessWidget {
  final String title, url;
  final Widget controls;
  final ValueChanged<String>? onNavigate;
  final int? dragIndex;
  final bool maximized;
  const BrowserWindowCardHeader({
    super.key,
    required this.title,
    required this.url,
    required this.controls,
    this.onNavigate,
    this.dragIndex,
    this.maximized = false,
  });

  /// El asa explícita conserva reordenación sin capturar gestos de la página web.
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: Row(
      children: [
        if (dragIndex != null && !maximized)
          ReorderableDragStartListener(
            index: dragIndex!,
            child: Semantics(
              label: 'Arrastra para reordenar pestaña',
              child: const SizedBox(
                width: 32,
                height: 48,
                child: Icon(Icons.drag_indicator_rounded, size: 20),
              ),
            ),
          ),
        Expanded(
          child: onNavigate == null
              ? Text(title, maxLines: 2, overflow: TextOverflow.ellipsis)
              : BrowserWindowUrlEditor(
                  title: title,
                  url: url,
                  siteColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  onSubmitted: onNavigate!,
                ),
        ),
        controls,
      ],
    ),
  );
}
