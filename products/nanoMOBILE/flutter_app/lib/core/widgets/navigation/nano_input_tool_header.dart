import 'package:flutter/material.dart';
import '../nano_anchored_popover.dart';
import 'nano_input_tool_context.dart';
import 'nano_input_tool_logo.dart';

/// Resume el estado en una línea. El detalle completo conserva destinatario y
/// evidencia factual, pero solo ocupa espacio cuando el usuario lo solicita.
class NanoInputToolHeader extends StatelessWidget {
  const NanoInputToolHeader({
    super.key,
    required this.tool,
    this.showLogo = true,
  });
  final NanoInputToolContext tool;
  final bool showLogo;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showNanoAnchoredPopover<void>(
          anchorContext: context,
          label: 'Detalle de la acción',
          builder: (_) => SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Text(tool.description),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              if (showLogo) ...[
                NanoInputToolLogo(asset: tool.asset, size: 22),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  [
                    tool.status,
                    if (tool.target.isNotEmpty) tool.target,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
