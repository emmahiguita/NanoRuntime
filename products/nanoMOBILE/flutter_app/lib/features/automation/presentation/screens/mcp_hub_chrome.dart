part of 'mcp_skills_hub_screen.dart';

/// Presentación MCP: chrome; no ejecuta herramientas.
extension _McpHubChrome on _McpSkillsHubScreenState {
  Widget _buildHeader(BuildContext context, AutomationVisualPalette visual) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Semantics(
            label: 'Regresar',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 24),
              color: visual.text,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Conexiones y herramientas',
                  style: TextStyle(
                    color: visual.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  'MCP y Linux · capacidades observadas',
                  style: TextStyle(color: visual.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Semantics(
            label: 'Refrescar Catálogo & Tools',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              color: visual.accent,
              onPressed: _refreshingCatalog
                  ? null
                  : () => _refreshCatalog(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(AutomationVisualPalette visual) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: visual.cardStart,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: visual.cardBorder),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: visual.accent.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: visual.accent.withValues(alpha: 0.6)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: visual.accent,
        unselectedLabelColor: visual.textMuted,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        tabs: const [
          Tab(
            icon: Icon(Icons.account_tree_outlined, size: 18),
            text: 'Herramientas',
          ),
          Tab(icon: Icon(Icons.analytics_outlined, size: 18), text: 'Registro'),
          Tab(
            icon: Icon(Icons.extension_outlined, size: 18),
            text: 'Conexiones',
          ),
        ],
      ),
    );
  }

  /// Alterna lectura agrupada y topología; ambas usan la misma instantánea.
  Widget _buildCapabilitiesTab(AutomationVisualPalette visual) => Column(
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => _update(() => _showGraph = !_showGraph),
          icon: Icon(
            _showGraph ? Icons.view_list_rounded : Icons.account_tree_outlined,
          ),
          label: Text(_showGraph ? 'Ver lista' : 'Ver grafo'),
        ),
      ),
      Expanded(
        child: _showGraph
            ? _buildLiveGraphTab(visual)
            : McpToolsBrowser(
                registry: ref.watch(mcpConnectionRegistryProvider),
              ),
      ),
    ],
  );

  // ---------------------------------------------------------------------------
  // TAB 1: GRAFO VIVO INTERACTIVO (Detección de Servidores y Herramientas Reales)
}
