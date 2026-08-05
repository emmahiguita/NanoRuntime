import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/design_tokens.dart';

class ScaffoldShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const ScaffoldShell({super.key, required this.shell});

  static const _tabs = [
    (icon: Icons.dashboard_outlined, sel: Icons.dashboard_rounded, label: 'Dashboard'),
    (icon: Icons.chat_outlined, sel: Icons.chat_rounded, label: 'Chat'),
    (icon: Icons.extension_outlined, sel: Icons.extension_rounded, label: 'Modelos'),
    (icon: Icons.terminal_outlined, sel: Icons.terminal_rounded, label: 'Terminal'),
    (icon: Icons.settings_outlined, sel: Icons.settings_rounded, label: 'Ajustes'),
  ];

  @override Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final idx = shell.currentIndex;
    final isDark = colors is NanoDarkColors;

    return Scaffold(
      appBar: AppBar(
        leading: Builder(builder: (ctx) => IconButton(icon: Icon(Icons.menu_rounded, color: colors.onSurface, size: 22), onPressed: () => Scaffold.of(ctx).openDrawer())),
        title: Text(_tabs[idx].label, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18, color: colors.onSurface, letterSpacing: -0.3)),
        backgroundColor: colors.surface,
        elevation: 0,
      ),
      drawer: Drawer(
        backgroundColor: colors.surface,
        width: 280,
        child: SafeArea(child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [colors.primaryContainer.withValues(alpha: isDark ? 0.4 : 0.15), colors.surface])),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 56, height: 56, decoration: BoxDecoration(gradient: LinearGradient(colors: [colors.primary, colors.secondary]), borderRadius: NanoShapes.large, boxShadow: [BoxShadow(color: colors.primary.withValues(alpha: 0.3), blurRadius: 12)]), child: const Icon(Icons.memory_rounded, color: Colors.white, size: 32)),
              const SizedBox(height: 16),
              Text('NanoAI', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: colors.onSurface, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text('Plataforma LLM Local', style: GoogleFonts.inter(fontSize: 12, color: colors.onSurfaceVariant)),
              const SizedBox(height: 8),
              Row(children: [_chip('v2.0', colors.primary, colors), const SizedBox(width: 8), _chip('ARM64', colors.secondary, colors)]),
            ]),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _tabs.length; i++)
            _NavItem(icon: _tabs[i].icon, selIcon: _tabs[i].sel, label: _tabs[i].label, selected: i == idx, colors: colors, onTap: () { shell.goBranch(i, initialLocation: i == idx); Navigator.of(context).pop(); }),
          const Spacer(),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Sistema', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: colors.onSurfaceVariant, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            _info('Snapdragon 778G', '8 cores', colors), _info('3.72 GB RAM', '2.80 GB libre', colors), _info('NanoPlatform', 'CLI v2.0', colors),
          ])),
        ])),
      ),
      body: shell,
    );
  }

  Widget _chip(String l, Color c, NanoColors cols) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: c.withValues(alpha: 0.2))), child: Text(l, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: c)));
  Widget _info(String l, String v, NanoColors c) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: GoogleFonts.inter(fontSize: 11, color: c.onSurfaceVariant)), Text(v, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: c.onSurface))]));
}

class _NavItem extends StatelessWidget {
  final IconData icon, selIcon; final String label; final bool selected; final NanoColors colors; final VoidCallback onTap;
  const _NavItem({required this.icon, required this.selIcon, required this.label, required this.selected, required this.colors, required this.onTap});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), child: Material(color: selected ? colors.primaryContainer.withValues(alpha: 0.2) : Colors.transparent, borderRadius: NanoShapes.medium, child: InkWell(onTap: onTap, borderRadius: NanoShapes.medium, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13), child: Row(children: [
    Icon(selected ? selIcon : icon, size: 20, color: selected ? colors.primary : colors.onSurfaceVariant),
    const SizedBox(width: 14),
    Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? colors.primary : colors.onSurface))),
    if (selected) Container(width: 5, height: 5, decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle)),
  ])))));
}
