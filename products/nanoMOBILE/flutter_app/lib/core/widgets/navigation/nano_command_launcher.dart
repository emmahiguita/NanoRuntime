import 'package:flutter/material.dart';
import '../glass_surface.dart';
import 'nano_input_tool_controls.dart';
import 'nano_input_tool_context.dart';

/// Reposo del MISMO editor: acceso visible al editor y al menú de herramientas.
/// No monta otro TextField ni crea animaciones continuas o suscripciones.
class NanoCommandLauncher extends StatelessWidget {
  const NanoCommandLauncher({
    super.key,
    required this.controls,
    required this.onWrite,
    required this.onNavigate,
    required this.maxWidth,
    this.tool,
  });
  final NanoInputToolControls controls;
  final NanoInputToolContext? tool;
  final VoidCallback onWrite, onNavigate;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth.clamp(0, 480)),
    child: GlassSurface(
      radius: 22,
      interactive: false,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Builder(
            builder: (anchor) => IconButton(
              tooltip: 'Adjuntos y complementos',
              onPressed: () => (controls.onAdd ?? controls.onOptions)(anchor),
              icon: const Icon(Icons.add_rounded),
            ),
          ),
          if (controls.selected) NanoInputToolButton(controls: controls),
          Expanded(
            child: TextButton(
              onPressed: onWrite,
              child: Text(
                tool?.status ?? 'Escribir una orden…',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Mostrar navegación',
            onPressed: onNavigate,
            icon: const Icon(Icons.apps_rounded, size: 20),
          ),
        ],
      ),
    ),
  );
}
