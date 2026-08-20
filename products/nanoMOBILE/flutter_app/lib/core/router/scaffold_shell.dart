import 'dart:ui';

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
      icon: Icons.computer_outlined,
      sel: Icons.computer_rounded,
      label: 'Linux',
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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final isDark = colors is NanoDarkColors;

    return PopScope(
      canPop: idx == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && idx != 0) {
          shell.goBranch(0);
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
              titleSpacing: 16,
              leadingWidth: 0,
              leading: const SizedBox.shrink(),
              title: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (rect) {
                        return LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          stops: const [0.0, 0.65, 0.85, 1.0],
                          colors: [
                            colors.textPrimary,
                            colors.textPrimary,
                            colors.accentCyan,
                            colors.accentLavender,
                          ],
                        ).createShader(rect);
                      },
                      child: const Text(
                        'NanoAI',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    for (var i = 0; i < _tabs.length; i++) ...[
                      _navChip(
                        label: _tabs[i].label,
                        icon: _tabs[i].icon,
                        selectedIcon: _tabs[i].sel,
                        selected: i == idx,
                        colors: colors,
                        iconOnly: !wide,
                        onTap: () =>
                            shell.goBranch(i, initialLocation: i == idx),
                      ),
                      if (i != _tabs.length - 1) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: reduceMotion ? 0.0 : 16.0,
                    sigmaY: reduceMotion ? 0.0 : 16.0,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.backgroundPrimary.withValues(alpha: 0.82)
                          : colors.surface.withValues(alpha: 0.86),
                      border: Border(
                        bottom: BorderSide(
                          color: colors.borderSecondaryColor.withValues(
                            alpha: isDark ? 0.15 : 0.35,
                          ),
                          width: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
      ),
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
    final isDark = colors is NanoDarkColors;
    final bgGradient = selected
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    colors.primary.withValues(alpha: 0.95),
                    colors.accentMint.withValues(alpha: 0.85),
                  ]
                : [
                    colors.primary,
                    colors.accentSky,
                  ],
          )
        : null;

    final borderGradient = selected
        ? NanoBorders.metallicRim(colors, accent: colors.primary)
        : LinearGradient(
            colors: [
              colors.borderSecondaryColor.withValues(alpha: isDark ? 0.12 : 0.25),
              colors.borderSecondaryColor.withValues(alpha: isDark ? 0.06 : 0.10),
            ],
          );

    final fg = selected
        ? (isDark ? const Color(0xFF000000) : Colors.white)
        : colors.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        borderRadius: NanoShapes.full,
        boxShadow: selected
            ? [
                BoxShadow(
                  color: colors.primary.withValues(alpha: isDark ? 0.35 : 0.20),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Container(
        padding: const EdgeInsets.all(1.0),
        decoration: BoxDecoration(
          borderRadius: NanoShapes.full,
          gradient: borderGradient,
        ),
        child: Material(
          color: selected ? Colors.transparent : (isDark ? colors.surfaceVariant.withValues(alpha: 0.4) : colors.surfaceVariant.withValues(alpha: 0.6)),
          borderRadius: NanoShapes.full,
          child: InkWell(
            onTap: onTap,
            borderRadius: NanoShapes.full,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: NanoShapes.full,
                gradient: bgGradient,
              ),
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
