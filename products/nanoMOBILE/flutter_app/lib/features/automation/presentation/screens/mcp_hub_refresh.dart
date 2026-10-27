part of 'mcp_skills_hub_screen.dart';

/// Actualiza catálogo y registro una vez; nunca actualiza una pantalla desmontada.
extension _McpHubRefresh on _McpSkillsHubScreenState {
  Future<void> _refreshCatalog(BuildContext context) async {
    if (!mounted || _refreshingCatalog) return;
    _update(() => _refreshingCatalog = true);
    ref.invalidate(mcpAccessibilityStatusProvider);
    try {
      final snapshot = await ref
          .read(mcpConnectionRegistryProvider)
          .refreshTools();
      if (!mounted) return;
      await _loadJournal();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            snapshot.failures.isEmpty
                ? 'Catálogo consultado: ${snapshot.tools.length} herramientas.'
                : 'Catálogo parcial: ${snapshot.tools.length} herramientas; '
                      '${snapshot.failures.length} servidores con error.',
          ),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo actualizar el catálogo MCP.'),
          ),
        );
      }
    } finally {
      if (mounted) _update(() => _refreshingCatalog = false);
    }
  }
}
