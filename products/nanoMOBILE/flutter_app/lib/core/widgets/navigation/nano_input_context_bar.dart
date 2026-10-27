import 'package:flutter/material.dart';
import 'nano_input_tool_controls.dart';
import 'nano_input_tool_context.dart';
import 'nano_input_tool_header.dart';

/// Contexto de la orden; el logo del menú vive una sola vez dentro del campo.
/// El historial tiene su propio acceso fuera de la barra de escritura.
class NanoInputContextBar extends StatelessWidget {
  const NanoInputContextBar({super.key, this.tool, this.controls});
  final NanoInputToolContext? tool;
  final NanoInputToolControls? controls;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (controls?.attachmentName case final name?) _attachment(context, name),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: tool != null
                ? NanoInputToolHeader(tool: tool!, showLogo: controls == null)
                : const SizedBox.shrink(),
          ),
        ],
      ),
      if (controls?.notice case final notice?)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: controls?.onConfigure,
            icon: const Icon(Icons.accessibility_new_rounded, size: 18),
            label: Text(notice, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ),
    ],
  );

  /// El adjunto pertenece al editor, no a WhatsApp. Muestra solo su nombre y
  /// permite quitarlo antes de ejecutar; nunca expone rutas privadas en pantalla.
  Widget _attachment(BuildContext context, String name) => Row(
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Icon(Icons.attach_file_rounded, size: 18),
      ),
      Expanded(
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      IconButton(
        tooltip: 'Quitar adjunto',
        onPressed: controls?.onRemoveAttachment,
        icon: const Icon(Icons.close_rounded, size: 18),
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      ),
    ],
  );
}
