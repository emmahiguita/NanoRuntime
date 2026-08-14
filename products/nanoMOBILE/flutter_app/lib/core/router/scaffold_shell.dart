import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/design_tokens.dart';
import '../providers/app_providers.dart';

class ScaffoldShell extends ConsumerWidget {
  final StatefulNavigationShell shell;
  const ScaffoldShell({super.key, required this.shell});

  static const _tabs = [
    (
      icon: Icons.dashboard_outlined,
      sel: Icons.dashboard_rounded,
      label: 'Inicio',
    ),
    (icon: Icons.chat_outlined, sel: Icons.chat_rounded, label: 'Chat'),
    (
      icon: Icons.extension_outlined,
      sel: Icons.extension_rounded,
      label: 'Modelos',
    ),
    (
      icon: Icons.terminal_outlined,
      sel: Icons.terminal_rounded,
      label: 'Terminal',
    ),
    (
      icon: Icons.settings_outlined,
      sel: Icons.settings_rounded,
      label: 'Ajustes',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NanoThemeExtension.of(context).colors;
    final idx = shell.currentIndex;
    final dash = ref.watch(dashboardProvider);
    final wide = MediaQuery.sizeOf(context).width > 600;
    // Dashboard (index 0) completamente limpio: sin AppBar ni nav inferior
    // (diseño de referencia 2026-08-13). La navegación vuelve en las demás
    // pestañas; desde Inicio se sale por los cards Terminal/Chat/Modelos.
    final isHome = shell.currentIndex == 0;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: isHome
          ? null
          : AppBar(
              titleSpacing: 16,
              leadingWidth: 0,
              leading: const SizedBox.shrink(),
              title: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _tabs[idx].label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: colors.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 14),
                    for (var i = 0; i < _tabs.length; i++) ...[
                      _navChip(
                        label: _tabs[i].label,
                        icon: _tabs[i].icon,
                        selectedIcon: _tabs[i].sel,
                        selected: i == idx,
                        colors: colors,
                        // Teléfono (≤600dp): solo icono — con etiqueta la
                        // fila desborda y "Ajustes" queda cortada del borde.
                        iconOnly: !wide,
                        onTap: () =>
                            shell.goBranch(i, initialLocation: i == idx),
                      ),
                      if (i != _tabs.length - 1) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              backgroundColor: colors.surface,
              elevation: 0,
              actions: [
                IconButton(
                  tooltip: 'Escritorio Linux',
                  icon: Icon(
                    Icons.desktop_windows_rounded,
                    color: colors.onSurface,
                    size: 21,
                  ),
                  onPressed: () => context.push('/desktop'),
                ),
                if (wide && dash.batteryPct >= 0)
                  _appChip(
                    Icons.battery_full,
                    '${dash.batteryPct.toInt()}%',
                    dash.batteryPct < 20 ? colors.warning : colors.success,
                    colors,
                  ),
                if (wide && dash.tempC > 0)
                  _appChip(
                    Icons.thermostat,
                    '${dash.tempC.toStringAsFixed(0)} C',
                    dash.tempC > 45 ? colors.error : colors.info,
                    colors,
                  ),
                if (wide && dash.ramTotalGb > 0)
                  _appChip(
                    Icons.memory,
                    '${dash.ramTotalGb.toStringAsFixed(1)} GB',
                    colors.primary,
                    colors,
                  ),
                const SizedBox(width: 8),
              ],
            ),
      body: shell,
    );
  }

  Widget _navChip({
    required String label,
    required IconData icon,
    required IconData selectedIcon,
    required bool selected,
    required NanoColors colors,
    required VoidCallback onTap,
    bool iconOnly = false,
  }) {
    final bg = selected ? colors.primary : colors.surfaceVariant;
    final fg = selected ? Colors.white : colors.onSurface;
    return Material(
      color: bg.withValues(alpha: selected ? 1 : 0.16),
      borderRadius: NanoShapes.full,
      child: InkWell(
        onTap: onTap,
        borderRadius: NanoShapes.full,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: iconOnly ? 12 : 10,
            vertical: 7,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? selectedIcon : icon, size: 15, color: fg),
              if (!iconOnly) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _appChip(IconData i, String t, Color bg, NanoColors c) => Container(
    margin: const EdgeInsets.only(left: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: bg.withValues(alpha: 0.12),
      borderRadius: NanoShapes.full,
      border: Border.all(color: bg.withValues(alpha: 0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(i, size: 14, color: bg),
        const SizedBox(width: 5),
        Text(
          t,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: bg,
          ),
        ),
      ],
    ),
  );
}
