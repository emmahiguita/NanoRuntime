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
          // QUÉ: Franja táctil con píldora translúcida reducida.
          // CÓMO: Usa GlassSurface con intensity baja (0.05) y borde fino de 0.75px.
          // POR QUÉ: Elimina el halo blanco grueso al colapsar la barra de navegación.
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: GlassSurface(
            interactive: false,
            radius: 999,
            opacity: .88,
            intensity: .05,
            borderWidth: 0.75,
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
