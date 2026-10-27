part of 'browser_credentials_sheet.dart';

class _CredentialsSearchBar extends StatelessWidget {
  final ThemeData theme;
  final bool isDark;
  final TextEditingController searchCtrl;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _CredentialsSearchBar({
    required this.theme,
    required this.isDark,
    required this.searchCtrl,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(
            alpha: isDark ? 0.35 : 0.55,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Icon(
              Icons.search_rounded,
              color: theme.colorScheme.onSurfaceVariant,
              size: 16,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: searchCtrl,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 12,
                ),
                decoration: InputDecoration(
                  hintText: 'Buscar por sitio o usuario...',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: onChanged,
              ),
            ),
            if (query.isNotEmpty)
              IconButton(
                icon: Icon(
                  Icons.clear_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 15,
                ),
                onPressed: onClear,
              ),
          ],
        ),
      ),
    );
  }
}
