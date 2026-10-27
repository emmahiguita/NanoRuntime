part of 'mcp_graph_components.dart';

/// Ventana flotante de inspección detallada de un nodo del grafo sobre GlassSurface.
void showMcpNodeDetailsSheet({
  required BuildContext context,
  required McpGraphNode node,
  required AutomationVisualPalette visual,
  required void Function(McpGraphNode node) onTestTool,
}) {
  showNanoGlassWindow<void>(
    context: context,
    builder: (context) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: node.statusColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(node.icon, color: node.statusColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.title,
                        style: TextStyle(
                          color: visual.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        node.subtitle,
                        style: TextStyle(color: visual.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: node.statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: node.statusColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    node.type.name.toUpperCase(),
                    style: TextStyle(
                      color: node.statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Propiedades observadas',
              style: TextStyle(
                color: visual.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: visual.isDark
                    ? Colors.black.withValues(alpha: 0.28)
                    : Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: visual.cardBorder),
              ),
              child: SelectableText(
                const JsonEncoder.withIndent('  ').convert(node.metadata),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (node.type == McpGraphNodeType.tool ||
                node.type == McpGraphNodeType.mcp)
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: visual.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.info_outline_rounded, size: 20),
                  label: const Text(
                    'Ver herramienta y argumentos',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onTestTool(node);
                  },
                ),
              ),
          ],
        ),
      );
    },
  );
}
