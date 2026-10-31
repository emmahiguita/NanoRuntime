import 'package:flutter/material.dart';
import '../../../core/widgets/nano_anchored_popover.dart';
import '../../../core/widgets/navigation/nano_input_tool_logo.dart';
import 'nano_assistant_tools.dart';

/// Selector anclado de las cinco rutas existentes. Evita opciones cortadas y
/// mantiene una única apertura; cancelar conserva contexto y borrador.
class NanoAssistantToolSelector extends StatefulWidget {
  const NanoAssistantToolSelector({
    super.key,
    required this.activeTool,
    required this.onSelected,
    this.enabled = true,
    this.onOptions,
  });
  final String activeTool;
  final ValueChanged<String> onSelected;
  final bool enabled;
  final ValueChanged<BuildContext>? onOptions;
  @override
  State<NanoAssistantToolSelector> createState() => _ToolSelectorState();
}

class _ToolSelectorState extends State<NanoAssistantToolSelector> {
  bool _opening = false;

  /// El presentador compartido posee posición, cristal y movimiento reducido.
  Future<void> _open(BuildContext anchor) async {
    if (_opening || !widget.enabled) return;
    _opening = true;
    try {
      final choice = await showNanoAnchoredPopover<String>(
        anchorContext: anchor,
        label: 'Funciones de Búho AI',
        maxWidth: 280,
        builder: (menu) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final tool in NanoAssistantTool.all)
                ListTile(
                  minTileHeight: 48,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  leading: _ToolIcon(tool: tool),
                  title: Text(tool.label),
                  selected: widget.activeTool == tool.key,
                  selectedColor: Theme.of(menu).colorScheme.onSurface,
                  selectedTileColor: Theme.of(
                    menu,
                  ).colorScheme.primary.withValues(alpha: .10),
                  trailing: widget.activeTool == tool.key
                      ? const Icon(Icons.check_rounded, size: 18)
                      : null,
                  onTap: () => Navigator.of(menu).pop(tool.key),
                ),
            ],
          ),
        ),
      );
      if (mounted && widget.enabled && choice != null) {
        widget.onSelected(choice);
      }
    } finally {
      _opening = false;
    }
  }

  /// La píldora no añade otro desenfoque al cristal del panel.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tool = NanoAssistantTool.fromKey(widget.activeTool);
    return Builder(
      builder: (anchor) => Material(
        color: colors.surface.withValues(alpha: .34),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: colors.outlineVariant.withValues(alpha: .55)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.enabled ? () => _open(anchor) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                if (tool.key == 'WhatsApp' && widget.onOptions != null)
                  IconButton(
                    tooltip: 'Funciones de WhatsApp',
                    onPressed: widget.enabled
                        ? () => widget.onOptions!(anchor)
                        : null,
                    icon: _ToolIcon(tool: tool),
                  )
                else
                  _ToolIcon(tool: tool),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tool.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.expand_more_rounded,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// WhatsApp conserva su icono Nano; las otras funciones usan símbolos distintos.
class _ToolIcon extends StatelessWidget {
  const _ToolIcon({required this.tool});
  final NanoAssistantTool tool;
  @override
  Widget build(BuildContext context) => tool.key == 'WhatsApp'
      ? const NanoInputToolLogo(
          asset: 'assets/automation/whatsapp_personal_icon.png',
          size: 24,
        )
      : Icon(
          tool.icon,
          size: 22,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
}
