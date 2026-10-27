import 'dart:convert';

import 'package:flutter/material.dart';

import '../../automation_visual_theme.dart';

part 'mcp_graph_node_details.dart';

/// Tipos de nodos representables en la topología de Nano AI.
enum McpGraphNodeType { core, mcp, tool, skill, platform }

/// Nodo inmutable en el grafo de capacidades.
class McpGraphNode {
  const McpGraphNode({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.offset,
    required this.icon,
    required this.statusColor,
    required this.metadata,
  });

  final String id;
  final String title;
  final String subtitle;
  final McpGraphNodeType type;
  final Offset offset;
  final IconData icon;
  final Color statusColor;
  final Map<String, dynamic> metadata;
}

/// Conexión orientada entre dos nodos del grafo.
class McpGraphEdge {
  const McpGraphEdge({
    required this.from,
    required this.to,
    required this.color,
  });

  final String from;
  final String to;
  final Color color;
}

/// Pintor reactivo de conexiones curvadas (Bézier cuadrático).
class McpGraphEdgePainter extends CustomPainter {
  McpGraphEdgePainter({required this.nodes, required this.edges});

  final List<McpGraphNode> nodes;
  final List<McpGraphEdge> edges;

  @override
  void paint(Canvas canvas, Size size) {
    final nodeMap = {for (final n in nodes) n.id: n};

    for (final edge in edges) {
      final fromNode = nodeMap[edge.from];
      final toNode = nodeMap[edge.to];
      if (fromNode == null || toNode == null) continue;

      final paint = Paint()
        ..color = edge.color.withValues(alpha: 0.45)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(fromNode.offset.dx, fromNode.offset.dy);

      final midX = (fromNode.offset.dx + toNode.offset.dx) / 2;
      final midY = (fromNode.offset.dy + toNode.offset.dy) / 2;
      path.quadraticBezierTo(midX, midY, toNode.offset.dx, toNode.offset.dy);

      canvas.drawPath(path, paint);

      final dotPaint = Paint()
        ..color = edge.color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(toNode.offset, 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant McpGraphEdgePainter oldDelegate) => true;
}

/// Widget representativo de cada nodo del grafo con efectos visuales.
class McpGraphNodeWidget extends StatelessWidget {
  const McpGraphNodeWidget({
    super.key,
    required this.node,
    required this.visual,
    required this.onTap,
  });

  final McpGraphNode node;
  final AutomationVisualPalette visual;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCore = node.type == McpGraphNodeType.core;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        width: isCore ? 144 : 132,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: visual.cardStart,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: node.statusColor.withValues(alpha: isCore ? 0.9 : 0.4),
            width: isCore ? 2 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: node.statusColor.withValues(alpha: isCore ? 0.25 : 0.12),
              blurRadius: isCore ? 14 : 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: node.statusColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(node.icon, size: 18, color: node.statusColor),
            ),
            const SizedBox(height: 6),
            Text(
              node.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: visual.text,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              node.subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: visual.textMuted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
