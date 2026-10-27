import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/features/desktop/presentation/widgets/desktop_stream_chrome.dart';

/// Professional Frosted Glass Bottom Sheets for Nano Linux Remote Desktop.
class DesktopSheets {
  /// App Launcher Bottom Sheet
  static void showAppsSheet({
    required BuildContext context,
    required NanoColors colors,
    required Future<void> Function(String app) onLaunchApp,
    required VoidCallback onOpenHelp,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AppsSheetContent(
        colors: colors,
        onLaunchApp: onLaunchApp,
        onOpenHelp: onOpenHelp,
      ),
    );
  }

  /// Precision Zoom Controls Bottom Sheet
  static void showZoomSheet({
    required BuildContext context,
    required NanoColors colors,
    required double currentZoom,
    required ValueChanged<double> onZoomChanged,
    required VoidCallback onResetZoom,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ZoomSheetContent(
        colors: colors,
        currentZoom: currentZoom,
        onZoomChanged: onZoomChanged,
        onResetZoom: onResetZoom,
      ),
    );
  }

  /// Complete PC Keyboard Grid Bottom Sheet
  static void showPCKeysSheet({
    required BuildContext context,
    required NanoColors colors,
    required ValueChanged<int> onQuickKey,
    required ValueChanged<List<int>> onCombo,
    required bool ctrlSticky,
    required bool altSticky,
    required bool shiftSticky,
    required bool superSticky,
    required VoidCallback onToggleCtrl,
    required VoidCallback onToggleAlt,
    required VoidCallback onToggleShift,
    required VoidCallback onToggleSuper,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _PCKeysSheetContent(
        colors: colors,
        onQuickKey: onQuickKey,
        onCombo: onCombo,
        ctrlSticky: ctrlSticky,
        altSticky: altSticky,
        shiftSticky: shiftSticky,
        superSticky: superSticky,
        onToggleCtrl: onToggleCtrl,
        onToggleAlt: onToggleAlt,
        onToggleShift: onToggleShift,
        onToggleSuper: onToggleSuper,
      ),
    );
  }

  /// CyberTools & Organized Linux Commands Bottom Sheet
  static void showCommandsSheet({
    required BuildContext context,
    required NanoColors colors,
    required ValueChanged<String> onExecuteCommand,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _CommandsSheetContent(
        colors: colors,
        onExecuteCommand: onExecuteCommand,
      ),
    );
  }

  /// Advanced Desktop Settings & Tools Bottom Sheet
  static void showMoreSheet({
    required BuildContext context,
    required NanoColors colors,
    required String status,
    required bool connected,
    required int fbWidth,
    required int fbHeight,
    required VoidCallback onFullscreen,
    required VoidCallback onRotate,
    required VoidCallback onMinimize,
    required VoidCallback onReconnect,
    required VoidCallback onDisconnect,
    required VoidCallback onOpenHelp,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _MoreSheetContent(
        colors: colors,
        status: status,
        connected: connected,
        fbWidth: fbWidth,
        fbHeight: fbHeight,
        onFullscreen: onFullscreen,
        onRotate: onRotate,
        onMinimize: onMinimize,
        onReconnect: onReconnect,
        onDisconnect: onDisconnect,
        onOpenHelp: onOpenHelp,
      ),
    );
  }
}

// ─── 1. Apps Sheet Content ───────────────────────────────────────────────────

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
          _SheetHeader(title: 'Aplicaciones Linux', icon: Icons.apps_rounded, colors: widget.colors),
          const SizedBox(height: 12),
          // Search input
          TextField(
            controller: _searchCtrl,
            onChanged: (val) => setState(() => _filter = val),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar aplicación Linux...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
              prefixIcon: Icon(Icons.search_rounded, color: widget.colors.chromeActive, size: 20),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
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
            leading: Icon(Icons.help_outline_rounded, color: widget.colors.chromeActive),
            title: const Text('Guía de gestos y controles', style: TextStyle(color: Colors.white, fontSize: 14)),
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
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

// ─── 2. Zoom Sheet Content ───────────────────────────────────────────────────

class _ZoomSheetContent extends StatefulWidget {
  final NanoColors colors;
  final double currentZoom;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback onResetZoom;

  const _ZoomSheetContent({
    required this.colors,
    required this.currentZoom,
    required this.onZoomChanged,
    required this.onResetZoom,
  });

  @override
  State<_ZoomSheetContent> createState() => _ZoomSheetContentState();
}

class _ZoomSheetContentState extends State<_ZoomSheetContent> {
  late double _zoom;

  @override
  void initState() {
    super.initState();
    _zoom = widget.currentZoom;
  }

  @override
  Widget build(BuildContext context) {
    return _SheetContainer(
      colors: widget.colors,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHeader(
            title: 'Zoom del Escritorio',
            icon: Icons.zoom_in_map_rounded,
            colors: widget.colors,
            trailing: Text(
              '${(_zoom * 100).round()}%',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: widget.colors.chromeActive,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: widget.colors.chromeActive,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
              thumbColor: widget.colors.chromeActive,
              overlayColor: widget.colors.chromeActive.withValues(alpha: 0.20),
            ),
            child: Slider(
              value: _zoom.clamp(0.10, 5.00),
              min: 0.10,
              max: 5.00,
              divisions: 49,
              onChanged: (val) {
                setState(() => _zoom = val);
                widget.onZoomChanged(val);
              },
            ),
          ),
          const SizedBox(height: 12),
          // Presets
          Row(
            children: [
              _presetChip('10% Mín', 0.10),
              _presetChip('50%', 0.50),
              _presetChip('100%', 1.0),
              _presetChip('200%', 2.0),
              _presetChip('500%', 5.0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _presetChip(String label, double targetZoom) {
    final isSelected = (_zoom - targetZoom).abs() < 0.05;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: OutlinedButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() => _zoom = targetZoom);
            widget.onZoomChanged(targetZoom);
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 10),
            side: BorderSide(
              color: isSelected ? widget.colors.chromeActive : Colors.white.withValues(alpha: 0.15),
              width: isSelected ? 1.4 : 0.8,
            ),
            backgroundColor: isSelected ? widget.colors.chromeActive.withValues(alpha: 0.18) : Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? widget.colors.chromeActive : Colors.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 3. PC Keys Sheet Content ────────────────────────────────────────────────

class _PCKeysSheetContent extends StatelessWidget {
  final NanoColors colors;
  final ValueChanged<int> onQuickKey;
  final ValueChanged<List<int>> onCombo;
  final bool ctrlSticky;
  final bool altSticky;
  final bool shiftSticky;
  final bool superSticky;
  final VoidCallback onToggleCtrl;
  final VoidCallback onToggleAlt;
  final VoidCallback onToggleShift;
  final VoidCallback onToggleSuper;

  const _PCKeysSheetContent({
    required this.colors,
    required this.onQuickKey,
    required this.onCombo,
    required this.ctrlSticky,
    required this.altSticky,
    required this.shiftSticky,
    required this.superSticky,
    required this.onToggleCtrl,
    required this.onToggleAlt,
    required this.onToggleShift,
    required this.onToggleSuper,
  });

  @override
  Widget build(BuildContext context) {
    return _SheetContainer(
      colors: colors,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHeader(title: 'Teclas PC & Atajos', icon: Icons.keyboard_rounded, colors: colors),
          const SizedBox(height: 14),

          // Modificadores Sticky
          const Text('Modificadores (Sticky)', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              _modBtn('Ctrl', ctrlSticky, onToggleCtrl, colors),
              _modBtn('Alt', altSticky, onToggleAlt, colors),
              _modBtn('Shift', shiftSticky, onToggleShift, colors),
              _modBtn('Super / Win', superSticky, onToggleSuper, colors),
            ],
          ),
          const SizedBox(height: 16),

          // Navegación
          const Text('Navegación & Edición', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _keyBtn('Esc', () => onQuickKey(0xFF1B)),
              _keyBtn('Tab', () => onQuickKey(0xFF09)),
              _keyBtn('Return', () => onQuickKey(0xFF0D)),
              _keyBtn('Space', () => onQuickKey(0x20)),
              _keyBtn('Delete', () => onQuickKey(0xFFFF)),
              _keyBtn('Home', () => onQuickKey(0xFF50)),
              _keyBtn('End', () => onQuickKey(0xFF57)),
              _keyBtn('PgUp', () => onQuickKey(0xFF55)),
              _keyBtn('PgDn', () => onQuickKey(0xFF56)),
            ],
          ),
          const SizedBox(height: 16),

          // Atajos de Sistema
          const Text('Atajos Frecuentes', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _comboBtn('Ctrl+C', () => onCombo([0xFFE3, 0x63])),
              _comboBtn('Ctrl+V', () => onCombo([0xFFE3, 0x76])),
              _comboBtn('Ctrl+X', () => onCombo([0xFFE3, 0x78])),
              _comboBtn('Ctrl+Z', () => onCombo([0xFFE3, 0x7A])),
              _comboBtn('Alt+Tab', () => onCombo([0xFFE9, 0xFF09])),
              _comboBtn('Ctrl+Alt+T (Terminal)', () => onCombo([0xFFE3, 0xFFE9, 0x74])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modBtn(String label, bool active, VoidCallback onTap, NanoColors colors) {
    final accent = colors.chromeActive;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? accent.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? accent : Colors.white.withValues(alpha: 0.14),
                width: active ? 1.4 : 0.8,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: active ? accent : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _keyBtn(String label, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _comboBtn(String label, VoidCallback onTap) {
    return FilledButton.tonal(
      onPressed: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.14),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}

// ─── 4. More / Settings Sheet Content ────────────────────────────────────────

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
          _SheetHeader(title: 'Sesión & Ajustes', icon: Icons.tune_rounded, colors: colors),
          const SizedBox(height: 14),

          // Connection status card
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
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        'Resolución RFB: ${fbWidth}x$fbHeight',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Actions List
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
      title: Text(title, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.5)),
      onTap: onTap,
    );
  }
}

// ─── Shared UI Helpers ────────────────────────────────────────────────────────

class _SheetContainer extends StatelessWidget {
  final NanoColors colors;
  final Widget child;

  const _SheetContainer({required this.colors, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E17),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: colors.chromeActive.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 30,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final NanoColors colors;
  final Widget? trailing;

  const _SheetHeader({
    required this.title,
    required this.icon,
    required this.colors,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(icon, color: colors.chromeActive, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ],
    );
  }
}

class _AppTile extends StatelessWidget {
  final String name;
  final String cmd;
  final String desc;
  final IconData icon;
  final NanoColors colors;
  final VoidCallback onTap;

  const _AppTile({
    required this.name,
    required this.cmd,
    required this.desc,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.chromeActive.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: colors.chromeActive, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Organized CyberTools & Linux Commands Bottom Sheet ──────────────────────

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

  static const List<_CommandItem> _commands = [
    // 🛡️ Ciberseguridad & Kali
    _CommandItem(
      title: 'Escaneo de Puertos y Servicios',
      category: 'Ciberseguridad',
      command: 'nmap -sV -F 127.0.0.1',
      description: 'Audita y detecta qué servicios y versiones están escuchando en la red local mediante un escaneo rápido con Nmap.',
      icon: Icons.shield_rounded,
    ),
    _CommandItem(
      title: 'Captura de Paquetes en Vivo',
      category: 'Ciberseguridad',
      command: 'tcpdump -i any -c 10',
      description: 'Captura e inspecciona en tiempo real los primeros 10 paquetes de tráfico de red en todas las interfaces activas.',
      icon: Icons.network_check_rounded,
    ),
    _CommandItem(
      title: 'Auditoría de Puertos y Procesos',
      category: 'Ciberseguridad',
      command: 'netstat -tulpn',
      description: 'Muestra todas las conexiones de red abiertas, sockets TCP/UDP y los nombres/PIDs de procesos asociados.',
      icon: Icons.lan_rounded,
    ),
    _CommandItem(
      title: 'Consulta WHOIS e IP Pública',
      category: 'Ciberseguridad',
      command: 'whois 8.8.8.8',
      description: 'Obtiene información de propiedad, ASN, proveedor de servicios y rango asignado para una dirección IP o dominio.',
      icon: Icons.travel_explore_rounded,
    ),
    _CommandItem(
      title: 'Monitoreo de Interfaces Tshark',
      category: 'Ciberseguridad',
      command: 'tshark -D',
      description: 'Muestra todas las interfaces de red disponibles para análisis de tráfico profundo con Wireshark/Tshark.',
      icon: Icons.manage_search_rounded,
    ),
    _CommandItem(
      title: 'Rastreo de Ruta ICMP',
      category: 'Ciberseguridad',
      command: 'traceroute 1.1.1.1',
      description: 'Mapea la ruta completa de saltos de red y evalúa latencias en cada router hasta la IP destino.',
      icon: Icons.alt_route_rounded,
    ),
    _CommandItem(
      title: 'Prueba de Conectividad Latencia',
      category: 'Ciberseguridad',
      command: 'ping -c 4 1.1.1.1',
      description: 'Envía 4 paquetes ICMP de prueba a Cloudflare DNS para verificar conectividad y medir tiempos de respuesta en milisegundos.',
      icon: Icons.speed_rounded,
    ),
    _CommandItem(
      title: 'Ayuda de Hydra (Brute-force)',
      category: 'Ciberseguridad',
      command: 'hydra -h',
      description: 'Muestra las opciones de configuración y uso de la herramienta de pruebas de autenticación y auditoría de claves Hydra.',
      icon: Icons.lock_open_rounded,
    ),
    _CommandItem(
      title: 'Ayuda de Sqlmap (Inyección SQL)',
      category: 'Ciberseguridad',
      command: 'sqlmap -h',
      description: 'Muestra el menú de comandos de Sqlmap para detección y verificación de vulnerabilidades de inyección SQL en aplicaciones.',
      icon: Icons.bug_report_rounded,
    ),

    // 📊 Monitoreo & Diagnóstico
    _CommandItem(
      title: 'Monitor Interactivo Htop',
      category: 'Monitoreo',
      command: 'htop',
      description: 'Despliega la consola gráfica interactiva en tiempo real para visualizar uso de CPU, RAM, Swap y administrar procesos.',
      icon: Icons.bar_chart_rounded,
    ),
    _CommandItem(
      title: 'Diagnóstico Nano Linux',
      category: 'Monitoreo',
      command: 'nano-info',
      description: 'Muestra el reporte oficial de arquitectura, versión de kernel, hilos de CPU, RAM libre y estado de la sesión Nano Linux.',
      icon: Icons.laptop_chromebook_rounded,
    ),
    _CommandItem(
      title: 'Uso de Memoria RAM',
      category: 'Monitoreo',
      command: 'free -h',
      description: 'Presenta el resumen legible en MB/GB de memoria RAM total, usada, libre, compartida, buffers y memoria disponible.',
      icon: Icons.memory_rounded,
    ),
    _CommandItem(
      title: 'Almacenamiento en Disco',
      category: 'Monitoreo',
      command: 'df -h',
      description: 'Calcula el espacio utilizado y disponible en todos los sistemas de archivos montados en Nano Linux.',
      icon: Icons.storage_rounded,
    ),
    _CommandItem(
      title: 'Top Procesos por CPU',
      category: 'Monitoreo',
      command: 'ps aux --sort=-%cpu | head -n 10',
      description: 'Filtra y muestra los 10 procesos con mayor consumo de recursos de procesamiento en el sistema.',
      icon: Icons.developer_board_rounded,
    ),
    _CommandItem(
      title: 'Top Procesos por RAM',
      category: 'Monitoreo',
      command: 'ps aux --sort=-%mem | head -n 10',
      description: 'Filtra y lista los 10 procesos que están consumiendo mayor cantidad de memoria RAM.',
      icon: Icons.pie_chart_rounded,
    ),
    _CommandItem(
      title: 'Tiempo de Actividad y Carga',
      category: 'Monitoreo',
      command: 'uptime',
      description: 'Informa el tiempo exacto que lleva encendida la sesión Linux y los promedios de carga a 1, 5 y 15 minutos.',
      icon: Icons.timer_rounded,
    ),

    // 📦 Instalar Herramientas Kali / Pentest
    _CommandItem(
      title: 'Instalar Suite Red (Nmap & Tcpdump)',
      category: 'Instalación',
      command: 'pkg install -y nmap tshark tcpdump netcat-openbsd',
      description: 'Instala en Nano Linux el conjunto esencial de herramientas para análisis de paquetes, trazado de rutas y auditoría de puertos.',
      icon: Icons.download_for_offline_rounded,
    ),
    _CommandItem(
      title: 'Instalar Entorno Dev (Python & Git)',
      category: 'Instalación',
      command: 'pkg install -y python python-pip git wget curl',
      description: 'Instala Python 3, el gestor de paquetes pip, Git para clonar repositorios y utilidades de descarga HTTP/FTP.',
      icon: Icons.code_rounded,
    ),
    _CommandItem(
      title: 'Instalar Suite Auditing (Hydra & Sqlmap)',
      category: 'Instalación',
      command: 'pkg install -y hydra sqlmap nikto aria2',
      description: 'Instala utilidades de verificación de seguridad web, análisis de vulnerabilidades y descargas multihilo aceleradas.',
      icon: Icons.security_rounded,
    ),
    _CommandItem(
      title: 'Instalar Utilidades (Htop & Neofetch)',
      category: 'Instalación',
      command: 'pkg install -y htop neofetch procps tree',
      description: 'Instala monitores de sistema mejorados, visualizador de árbol de carpetas y comandos de resumen del sistema.',
      icon: Icons.widgets_rounded,
    ),

    // ⚙️ Sistema & Red
    _CommandItem(
      title: 'Listar Archivos Ocultos',
      category: 'Sistema',
      command: 'ls -la ~',
      description: 'Muestra todos los archivos y carpetas del usuario incluyendo archivos de configuración ocultos (.bashrc, .config).',
      icon: Icons.folder_zip_rounded,
    ),
    _CommandItem(
      title: 'Directorio Actual (PWD)',
      category: 'Sistema',
      command: 'pwd',
      description: 'Imprime la ruta de trabajo actual en la estructura de archivos de Linux.',
      icon: Icons.folder_open_rounded,
    ),
    _CommandItem(
      title: 'Información de Distribución OS',
      category: 'Sistema',
      command: 'cat /etc/os-release',
      description: 'Muestra el nombre, versión, ID y soporte de la distribución Linux en ejecución.',
      icon: Icons.info_rounded,
    ),
    _CommandItem(
      title: 'Interfaces de Red IP (ip a)',
      category: 'Sistema',
      command: 'ip a',
      description: 'Muestra la lista de interfaces de red activas, dirección MAC y direcciones IPv4/IPv6 asignadas.',
      icon: Icons.wifi_tethering_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final categories = ['Todos', 'Ciberseguridad', 'Monitoreo', 'Instalación', 'Sistema'];

    final filtered = _commands.where((c) {
      final matchesCat = _selectedCategory == 'Todos' || c.category == _selectedCategory;
      final q = _searchQuery.toLowerCase();
      final matchesSearch = q.isEmpty ||
          c.title.toLowerCase().contains(q) ||
          c.command.toLowerCase().contains(q) ||
          c.description.toLowerCase().contains(q);
      return matchesCat && matchesSearch;
    }).toList();

    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;
    final sheetHeight = size.height * (isLandscape ? 0.92 : 0.84);

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Color(0xFF0D111A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF0EA5E9), width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 30,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4.5,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: Color(0xFF0EA5E9), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Comandos & Ciberseguridad',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Comandos Kali Linux y herramientas de diagnóstico con ejecución en 1 tap',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Inter'),
              decoration: InputDecoration(
                hintText: 'Buscar comando, nmap, htop, red, ip...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12.5),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF0EA5E9), size: 18),
                isDense: true,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF0EA5E9)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Category Chips
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
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.black : Colors.white70,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF0EA5E9),
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    checkmarkColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Commands List
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No se encontraron comandos con ese criterio',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

class _CommandItem {
  final String title;
  final String category;
  final String command;
  final String description;
  final IconData icon;

  const _CommandItem({
    required this.title,
    required this.category,
    required this.command,
    required this.description,
    required this.icon,
  });
}

class _CommandCard extends StatelessWidget {
  final _CommandItem item;
  final NanoColors colors;
  final VoidCallback onExecute;

  const _CommandCard({
    required this.item,
    required this.colors,
    required this.onExecute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(item.icon, size: 18, color: const Color(0xFF0EA5E9)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.category,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0EA5E9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Code Badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.3)),
            ),
            child: SelectableText(
              item.command,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                color: Color(0xFF38BDF8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            item.description,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),

          // Action Button
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: onExecute,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 16),
              label: const Text(
                'Ejecutar ▶',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
