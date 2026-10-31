part of 'nano_contact_picker_sheet.dart';

/// Encabezado y buscador contextual para NanoContactPickerSheet.
///
/// QUÉ HACE:
/// - Presenta la manija de arrastre, título, subtítulo del contenido y campo de búsqueda.
///
/// POR QUÉ:
/// - Mantiene el control de entrada aislado (< 95 líneas).
class _NanoContactPickerHeader extends StatelessWidget {
  final NanoSharePayload payload;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;

  const _NanoContactPickerHeader({
    required this.payload,
    required this.searchController,
    required this.searchQuery,
    required this.onQueryChanged,
    required this.onClearQuery,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = NanoThemeExtension.of(context).colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.18),
                child: const Icon(Icons.share_rounded, size: 16, color: Color(0xFF15803D)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Compartir desde Nano',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      payload.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: searchController,
            onChanged: onQueryChanged,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o número...',
              hintStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: onClearQuery,
                    )
                  : null,
              filled: true,
              fillColor: isDark ? const Color(0x301E293B) : const Color(0xFFF1F5F9),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
