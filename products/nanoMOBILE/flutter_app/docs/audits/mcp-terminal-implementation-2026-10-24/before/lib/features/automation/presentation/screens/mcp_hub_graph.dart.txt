part of 'mcp_skills_hub_screen.dart';

/// Presentación MCP: graph; no ejecuta herramientas.
extension _McpHubGraph on _McpSkillsHubScreenState {
  Widget _buildLiveGraphTab(AutomationVisualPalette visual) {
    final mcpRegistry = ref.watch(mcpConnectionRegistryProvider);

    final systemGraphAsync = ref.watch(systemGraphProvider);
    final deviceModel =
        systemGraphAsync.valueOrNull?.device.model ?? 'Android sin detectar';
    final appsCount = systemGraphAsync.valueOrNull?.apps.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        const canvasWidth = 1180.0;
        const centerOffset = Offset(400, 320);
        final nodes = _platformNodes(
          visual,
          centerOffset,
          deviceModel,
          appsCount,
        );
        final edges = [
          for (final node in nodes.skip(1))
            McpGraphEdge(from: 'core', to: node.id, color: node.statusColor),
        ];
        _appendServers(visual, nodes, edges);
        final canvasHeight = nodes.fold<double>(
          680,
          (height, node) =>
              height > node.offset.dy + 90 ? height : node.offset.dy + 90,
        );
        if (_graphTransform.value.isIdentity() && constraints.maxWidth > 0) {
          final scale = (constraints.maxWidth / canvasWidth).clamp(0.45, 0.95);
          final dx = (constraints.maxWidth - canvasWidth * scale) / 2;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _graphTransform.value = Matrix4.identity()
              ..setTranslationRaw(dx, 12, 0)
              ..multiply(Matrix4.diagonal3Values(scale, scale, 1));
          });
        }
        return Stack(
          children: [
            InteractiveViewer(
              constrained: false,
              transformationController: _graphTransform,
              boundaryMargin: const EdgeInsets.all(350),
              minScale: 0.45,
              maxScale: 2.5,
              child: SizedBox(
                width: canvasWidth,
                height: canvasHeight,
                child: Stack(
                  children: [
                    CustomPaint(
                      size: Size(canvasWidth, canvasHeight),
                      painter: McpGraphEdgePainter(nodes: nodes, edges: edges),
                    ),
                    for (final node in nodes)
                      Positioned(
                        left: node.offset.dx - 66,
                        top: node.offset.dy - 34,
                        child: McpGraphNodeWidget(
                          node: node,
                          visual: visual,
                          onTap: () => showMcpNodeDetailsSheet(
                            context: context,
                            node: node,
                            visual: visual,
                            onTestTool: (targetNode) => showMcpToolTestDialog(
                              context: context,
                              node: targetNode,
                              registry: mcpRegistry,
                              visual: visual,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Controles flotantes de zoom y centrado
            Positioned(right: 16, bottom: 16, child: _graphControls(visual)),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: TELEMETRÍA Y AUDITORÍA DE EJECUCIONES
  // ---------------------------------------------------------------------------
}
