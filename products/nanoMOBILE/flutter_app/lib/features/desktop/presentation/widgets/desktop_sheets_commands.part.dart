part of 'desktop_sheets.dart';

class _CommandsSheetContent extends StatefulWidget {
  final NanoColors colors;
  final ValueChanged<String> onExecuteCommand;

  const _CommandsSheetContent({
    required this.colors,
    required this.onExecuteCommand,
  });

  @override
  State<_CommandsSheetContent> createState() => _CommandsSheetContentState();
}

class _CommandsSheetContentState extends State<_CommandsSheetContent> {
  String _selectedCategory = 'Todos';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final categories = [
      'Todos',
      'Ciberseguridad',
      'Monitoreo',
      'Instalación',
      'Sistema',
    ];

    final filtered = _commands.where((c) {
      final matchesCat =
          _selectedCategory == 'Todos' || c.category == _selectedCategory;
      final q = _searchQuery.toLowerCase();
      final matchesSearch =
          q.isEmpty ||
          c.title.toLowerCase().contains(q) ||
          c.command.toLowerCase().contains(q) ||
          c.description.toLowerCase().contains(q);
      return matchesCat && matchesSearch;
    }).toList();

    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;
    final sheetHeight = size.height * (isLandscape ? 0.92 : 0.84);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: sheetHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _CommandsHeader(),
          _CommandsSearchBar(
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(
                      cat,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected ? Colors.black : Colors.white70,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF0EA5E9),
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    checkmarkColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No se encontraron comandos con ese criterio',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final item = filtered[i];
                      return _CommandCard(
                        item: item,
                        colors: widget.colors,
                        onExecute: () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(context);
                          widget.onExecuteCommand(item.command);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
