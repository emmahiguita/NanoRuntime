part of 'mcp_skills_hub_screen.dart';

/// Presentación MCP: graph controls; no ejecuta herramientas.
extension _McpHubGraphControls on _McpSkillsHubScreenState {
  Widget _graphControls(AutomationVisualPalette visual) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: visual.cardStart.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: visual.cardBorder),
      boxShadow: [
        BoxShadow(
          color: visual.shadow,
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.zoom_in_rounded, size: 18),
          color: visual.text,
          visualDensity: VisualDensity.compact,
          onPressed: () {
            final val = Matrix4.copy(_graphTransform.value);
            val.scaleByDouble(1.2, 1.2, 1.0, 1.0);
            _graphTransform.value = val;
          },
        ),
        IconButton(
          icon: const Icon(Icons.zoom_out_rounded, size: 18),
          color: visual.text,
          visualDensity: VisualDensity.compact,
          onPressed: () {
            final val = Matrix4.copy(_graphTransform.value);
            val.scaleByDouble(0.8, 0.8, 1.0, 1.0);
            _graphTransform.value = val;
          },
        ),
        IconButton(
          icon: const Icon(Icons.center_focus_strong_rounded, size: 18),
          color: visual.accent,
          visualDensity: VisualDensity.compact,
          onPressed: () => _graphTransform.value = Matrix4.identity(),
        ),
      ],
    ),
  );
}
