// QUÉ: estado reducido visible e identificable de la navegación.
// CÓMO: muestra destino, nombre y apertura en una píldora de altura mínima 36 px.
// POR QUÉ: tres puntos aislados no explicaban cómo recuperar los destinos.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../glass_surface.dart';
import 'nano_destination.dart';
import 'nano_input_tool_context.dart';
import 'nano_input_tool_logo.dart';
import 'nano_destination_icon.dart';
import 'nano_glyph.dart';

class NanoNavMiniPill extends StatelessWidget {
  const NanoNavMiniPill({
    super.key,
    required this.onExpand,
    this.destination = NanoDestination.automation,
    this.semanticLabel = 'Mostrar navegación',
    this.toolContext,
  });
  final VoidCallback onExpand;
  final NanoDestination destination;
  final String semanticLabel;
  final NanoInputToolContext? toolContext;

  final VoidCallback onExpand;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tool = toolContext;
    final label = tool == null
        ? (destination == NanoDestination.automation
              ? 'Inicio'
              : destination.label)
        : '${tool.name} · ${tool.status}';
    return Semantics(
      button: true,
      label: tool == null
          ? '$semanticLabel. Sección actual: $label'
          : 'Mostrar tarea. ${tool.description}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onExpand();
        },
        child: Padding(
          // El fondo es pequeño, pero toda la franja táctil conserva 48 px.
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: GlassSurface(
            interactive: false,
            radius: 999,
            opacity: .90,
            intensity: .38,
            padding: EdgeInsets.zero,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 5,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (tool == null)
                      NanoDestinationIcon(destination: destination, size: 20)
                    else
                      NanoInputToolLogo(asset: tool.asset, size: 20),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    NanoGlyph(
                      type: NanoGlyphType.chevronUp,
                      size: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
