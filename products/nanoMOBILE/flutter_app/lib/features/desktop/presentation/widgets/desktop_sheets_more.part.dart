part of 'desktop_sheets.dart';

class _MoreSheetContent extends StatelessWidget {
  final NanoColors colors;
  final String status;
  final bool connected;
  final int fbWidth;
  final int fbHeight;
  final VoidCallback onFullscreen;
  final VoidCallback onRotate;
  final VoidCallback onMinimize;
  final VoidCallback onReconnect;
  final VoidCallback onDisconnect;
  final VoidCallback onOpenHelp;

  const _MoreSheetContent({
    required this.colors,
    required this.status,
    required this.connected,
    required this.fbWidth,
    required this.fbHeight,
    required this.onFullscreen,
    required this.onRotate,
    required this.onMinimize,
    required this.onReconnect,
    required this.onDisconnect,
    required this.onOpenHelp,
  });

  @override
  Widget build(BuildContext context) {
    return _SheetContainer(
      colors: colors,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHeader(
            title: 'Sesión & Ajustes',
            icon: Icons.tune_rounded,
            colors: colors,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: connected ? colors.chromeActive : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        connected ? 'Escritorio Conectado' : status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'Resolución RFB: ${fbWidth}x$fbHeight',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _actionTile(
            icon: Icons.open_in_full_rounded,
            title: 'Pantalla Inmersiva Fullscreen',
            onTap: () {
              Navigator.of(context).pop();
              onFullscreen();
            },
          ),
          _actionTile(
            icon: Icons.screen_rotation_rounded,
            title: 'Girar Orientación (Moonlight)',
            onTap: () {
              Navigator.of(context).pop();
              onRotate();
            },
          ),
          _actionTile(
            icon: Icons.picture_in_picture_alt_rounded,
            title: 'Minimizar Sesión (Modo PiP)',
            onTap: () {
              Navigator.of(context).pop();
              onMinimize();
            },
          ),
          _actionTile(
            icon: Icons.refresh_rounded,
            title: 'Reconectar Servidor VNC',
            onTap: () {
              Navigator.of(context).pop();
              onReconnect();
            },
          ),
          _actionTile(
            icon: Icons.help_outline_rounded,
            title: 'Guía de Gestos',
            onTap: () {
              Navigator.of(context).pop();
              onOpenHelp();
            },
          ),
          Divider(color: Colors.white.withValues(alpha: 0.12)),
          _actionTile(
            icon: Icons.power_settings_new_rounded,
            title: 'Desconectar Sesión',
            color: Colors.redAccent,
            onTap: () {
              Navigator.of(context).pop();
              onDisconnect();
            },
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: color.withValues(alpha: 0.5),
      ),
      onTap: onTap,
    );
  }
}
