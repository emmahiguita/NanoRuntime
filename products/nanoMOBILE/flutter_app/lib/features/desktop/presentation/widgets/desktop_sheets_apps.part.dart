part of 'desktop_sheets.dart';

class _AppsSheetContent extends StatefulWidget {
  final NanoColors colors;
  final Future<void> Function(String app) onLaunchApp;
  final VoidCallback onOpenHelp;

  const _AppsSheetContent({
    required this.colors,
    required this.onLaunchApp,
    required this.onOpenHelp,
  });

  @override
  State<_AppsSheetContent> createState() => _AppsSheetContentState();
}

class _AppsSheetContentState extends State<_AppsSheetContent> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = '';

  final List<Map<String, dynamic>> _allApps = [
    {
      'name': 'Terminal',
      'cmd': 'lxterminal',
      'icon': Icons.terminal_rounded,
      'desc': 'Consola Bash / Zsh de Linux',
    },
    {
      'name': 'Archivos',
      'cmd': 'pcmanfm',
      'icon': Icons.folder_rounded,
      'desc': 'Explorador de archivos PCManFM',
    },
    {
      'name': 'Editor de Texto',
      'cmd': 'mousepad',
      'icon': Icons.edit_note_rounded,
      'desc': 'Editor gráfico Mousepad',
    },
    {
      'name': 'Navegador Web',
      'cmd': 'chromium-browser',
      'icon': Icons.public_rounded,
      'desc': 'Navegador Chromium / Firefox',
    },
    {
      'name': 'VS Code / Codium',
      'cmd': 'code-oss',
      'icon': Icons.code_rounded,
      'desc': 'Entorno IDE de desarrollo',
    },
    {
      'name': 'Monitor del Sistema',
      'cmd': 'lxtask',
      'icon': Icons.monitor_heart_rounded,
      'desc': 'Administrador de procesos Linux',
    },
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _allApps.where((app) {
      final query = _filter.toLowerCase().trim();
      if (query.isEmpty) return true;
      return (app['name'] as String).toLowerCase().contains(query) ||
          (app['cmd'] as String).toLowerCase().contains(query);
    }).toList();

    return _SheetContainer(
      colors: widget.colors,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHeader(
            title: 'Aplicaciones Linux',
            icon: Icons.apps_rounded,
            colors: widget.colors,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            onChanged: (val) => setState(() => _filter = val),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar aplicación Linux...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: widget.colors.chromeActive,
                size: 20,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: widget.colors.chromeActive),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final app = filtered[i];
              return _AppTile(
                name: app['name'] as String,
                cmd: app['cmd'] as String,
                desc: app['desc'] as String,
                icon: app['icon'] as IconData,
                colors: widget.colors,
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onLaunchApp(app['cmd'] as String);
                },
              );
            },
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.12)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.help_outline_rounded,
              color: widget.colors.chromeActive,
            ),
            title: const Text(
              'Guía de gestos y controles',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white54,
            ),
            onTap: () {
              Navigator.of(context).pop();
              widget.onOpenHelp();
            },
          ),
        ],
      ),
    );
  }
}
