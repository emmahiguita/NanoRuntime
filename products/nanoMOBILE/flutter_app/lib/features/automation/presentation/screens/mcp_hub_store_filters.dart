part of 'mcp_skills_hub_screen.dart';

/// Presentación MCP: store filters; no ejecuta herramientas.
extension _McpHubStoreFilters on _McpSkillsHubScreenState {
  Widget _buildStoreFilters(AutomationVisualPalette visual) => Column(
    children: [
      Container(
        decoration: BoxDecoration(
          color: visual.cardStart,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: visual.cardBorder),
        ),
        child: TextField(
          controller: _searchController,
          style: TextStyle(color: visual.text, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Buscar conectores incluidos en Nano...',
            hintStyle: TextStyle(color: visual.textMuted, fontSize: 13),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: visual.textMuted,
              size: 20,
            ),
            suffixIcon: _storeSearchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      _update(() => _storeSearchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          onChanged: (val) => _update(() => _storeSearchQuery = val),
        ),
      ),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final cat in McpStoreCategory.values.where(
              (category) =>
                  category == McpStoreCategory.all ||
                  McpStoreCatalog.defaultItems.any(
                    (item) => item.category == category,
                  ),
            ))
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: _selectedStoreCategory == cat,
                  label: Text(
                    switch (cat) {
                      McpStoreCategory.all => 'Todos',
                      McpStoreCategory.system => 'Sistema',
                      McpStoreCategory.developer => 'Desarrollo',
                      McpStoreCategory.search => 'Búsqueda Web',
                      McpStoreCategory.cloudAi => 'Cloud & IA',
                      McpStoreCategory.productivity => 'Productividad',
                    },
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _selectedStoreCategory == cat
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: _selectedStoreCategory == cat
                          ? Colors.white
                          : visual.text,
                    ),
                  ),
                  selectedColor: visual.accent,
                  backgroundColor: visual.cardStart,
                  side: BorderSide(
                    color: _selectedStoreCategory == cat
                        ? visual.accent
                        : visual.cardBorder,
                  ),
                  onSelected: (_) =>
                      _update(() => _selectedStoreCategory = cat),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
    ],
  );
}
