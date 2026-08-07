import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/design_tokens.dart';
import '../providers/app_providers.dart';

class ScaffoldShell extends ConsumerWidget {
  final StatefulNavigationShell shell;
  const ScaffoldShell({super.key, required this.shell});

  static const _tabs = [
    (icon: Icons.dashboard_outlined, sel: Icons.dashboard_rounded, label: 'Dashboard'),
    (icon: Icons.chat_outlined, sel: Icons.chat_rounded, label: 'Chat'),
    (icon: Icons.extension_outlined, sel: Icons.extension_rounded, label: 'Modelos'),
    (icon: Icons.terminal_outlined, sel: Icons.terminal_rounded, label: 'Terminal'),
    (icon: Icons.settings_outlined, sel: Icons.settings_rounded, label: 'Ajustes'),
  ];

  @override Widget build(BuildContext context, WidgetRef ref) {
    final colors = NanoThemeExtension.of(context).colors;
    final idx = shell.currentIndex;
    final isDark = colors is NanoDarkColors;
    final dash = ref.watch(dashboardProvider);
    // >600dp ~ landscape/tablet. Reutiliza el ancho extra del AppBar y drawer.
    final wide = MediaQuery.sizeOf(context).width > 600;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        titleSpacing: wide ? 8 : 16,
        leading: Builder(builder: (ctx) => IconButton(icon: Icon(Icons.menu_rounded, color: colors.onSurface, size: 22), onPressed: () => Scaffold.of(ctx).openDrawer())),
        title: Text(_tabs[idx].label, style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 18, color: colors.onSurface, letterSpacing: -0.3)),
        backgroundColor: colors.surface,
        elevation: 0,
        // En landscape el AppBar sobra ancho: mÃ¡rcanos las mÃ©tricas del
        // dispositivo aprovechando el espacio que en portrait no hay.
        actions: wide ? [
          if (dash.batteryPct >= 0) _appChip(Icons.battery_full, '${dash.batteryPct.toInt()}%', dash.batteryPct < 20 ? colors.warning : colors.success, colors),
          if (dash.tempC > 0) _appChip(Icons.thermostat, '${dash.tempC.toStringAsFixed(0)}Â°C', dash.tempC > 45 ? colors.error : colors.info, colors),
          if (dash.ramTotalGb > 0) _appChip(Icons.memory, '${dash.ramTotalGb.toStringAsFixed(1)} GB', colors.primary, colors),
          const SizedBox(width: 12),
        ] : null,
      ),
      drawer: Drawer(
        backgroundColor: colors.surface,
        width: wide ? 360 : 280,
        child: SafeArea(child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [colors.primaryContainer.withValues(alpha: isDark ? 0.4 : 0.15), colors.surface])),
            // Header: fila horizontal en landscape (logo izq., texto/chips der.)
            child: wide
? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  _logoMark(colors),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('NanoAI', style: TextStyle(fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.w800, color: colors.onSurface, letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    Text('Plataforma LLM Local', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: colors.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Row(children: [_chip('v2.0', colors.primary, colors), const SizedBox(width: 8), _chip('ARM64', colors.secondary, colors)]),
                  ])),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _logoMark(colors),
                  const SizedBox(height: 16),
                  Text('NanoAI', style: TextStyle(fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.w800, color: colors.onSurface, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text('Plataforma LLM Local', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: colors.onSurfaceVariant)),
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
            Text('Sistema', style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: colors.onSurfaceVariant, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            _info('RAM', dash.ramTotalGb > 0 ? '${dash.ramTotalGb.toStringAsFixed(2)} GB Â· ${dash.ramFreeGb.toStringAsFixed(2)} GB libre' : 'Desconocido', colors),
            _info('CPU', dash.cpuCores > 0 ? '${dash.cpuCores} cores' : 'Desconocido', colors),
            _info('Almacenamiento', dash.storageTotalGb > 0 ? '${dash.storageTotalGb.toStringAsFixed(0)} GB' : 'Desconocido', colors),
          ])),
        ])),
      ),
      body: shell,
    );
  }

  Widget _logoMark(NanoColors c) => Container(width: 56, height: 56, decoration: BoxDecoration(gradient: LinearGradient(colors: [c.primary, c.secondary]), borderRadius: NanoShapes.large, boxShadow: [BoxShadow(color: c.primary.withValues(alpha: 0.3), blurRadius: 12)]), child: const Icon(Icons.memory_rounded, color: Colors.white, size: 32));
  Widget _appChip(IconData i, String t, Color bg, NanoColors c) => Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: bg.withValues(alpha: 0.12), borderRadius: NanoShapes.full, border: Border.all(color: bg.withValues(alpha: 0.3))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(i, size: 14, color: bg), const SizedBox(width: 5), Text(t, style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: bg))]));

  Widget _chip(String l, Color c, NanoColors cols) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: c.withValues(alpha: 0.2))), child: Text(l, style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w600, color: c)));
  Widget _info(String l, String v, NanoColors c) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: c.onSurfaceVariant)), Text(v, style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w500, color: c.onSurface))]));
}

class _NavItem extends StatelessWidget {
  final IconData icon, selIcon; final String label; final bool selected; final NanoColors colors; final VoidCallback onTap;
  const _NavItem({required this.icon, required this.selIcon, required this.label, required this.selected, required this.colors, required this.onTap});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), child: Material(color: selected ? colors.primaryContainer.withValues(alpha: 0.2) : Colors.transparent, borderRadius: NanoShapes.medium, child: InkWell(onTap: onTap, borderRadius: NanoShapes.medium, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13), child: Row(children: [
    Icon(selected ? selIcon : icon, size: 20, color: selected ? colors.primary : colors.onSurfaceVariant),
    const SizedBox(width: 14),
    Expanded(child: Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? colors.primary : colors.onSurface))),
    if (selected) Container(width: 5, height: 5, decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle)),
  ])))));
}
