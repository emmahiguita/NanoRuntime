part of 'mcp_skills_hub_screen.dart';

/// Presentación MCP: journal; no ejecuta herramientas.
extension _McpHubJournal on _McpSkillsHubScreenState {
  Widget _buildTelemetryTab(AutomationVisualPalette visual) {
    final filtered = _journalEntries.where((e) {
      if (_logFilter == 'mcp') return e.actionSignature.contains('mcp');
      if (_logFilter == 'skills') return e.semanticAction.isNotEmpty;
      if (_logFilter == 'failed') {
        return e.status == ExecutionJournalStatus.failed ||
            e.status == ExecutionJournalStatus.cancelled;
      }
      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            _journalCapturedAt == null
                ? "Registro aún no consultado"
                : "Instantánea: ${_journalCapturedAt!.toLocal()} · actualización manual",
            style: TextStyle(color: visual.textMuted, fontSize: 11),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in [
                        ('all', 'Todos'),
                        ('mcp', 'MCP'),
                        ('skills', 'Skills'),
                        ('failed', 'Fallos'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            selected: _logFilter == f.$1,
                            label: Text(
                              f.$2,
                              style: const TextStyle(fontSize: 12),
                            ),
                            selectedColor: visual.accent.withValues(alpha: 0.2),
                            checkmarkColor: visual.accent,
                            onSelected: (_) => _update(() => _logFilter = f.$1),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: _refreshingLogs
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                color: visual.textMuted,
                onPressed: _refreshingLogs ? null : _loadJournal,
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No hay registros de telemetría disponibles.',
                    style: TextStyle(color: visual.textMuted, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => McpTelemetryLogCard(
                    entry: filtered[index],
                    visual: visual,
                  ),
                ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: TIENDA DE MCPS & INYECCIÓN EN CALIENTE
}
