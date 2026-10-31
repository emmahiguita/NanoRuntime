// nano_nav_floating_window.dart — Menú flotante iOS Liquid Glass para Nano AI.
// QUÉ HACE: Despliega las 4 opciones canónicas + accesos directos únicos (Chat IA y Navegador).
// CÓMO FUNCIONA: Anclado debajo del botón búho con animación de escala/opacidad y bordes iOS (20dp).
// POR QUÉ: Elimina opciones duplicadas y cumple la estética iOS Liquid Glass (< 175 líneas).
library;

import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../router/app_router.dart';
import 'nano_destination.dart';
import 'nano_drawer_quick_tile.dart';
import 'nano_nav_floating_row.dart';
import 'nano_nav_floating_window_header.dart';

class NanoNavFloatingWindow extends StatefulWidget {
  const NanoNavFloatingWindow({
    super.key,
    required this.selected,
    required this.isRight,
    required this.onDestinationSelected,
    required this.onCloseMenu,
    required this.onRestoreBottom,
  });

  final NanoDestination selected;
  final bool isRight;
  final ValueChanged<NanoDestination> onDestinationSelected;
  final VoidCallback onCloseMenu;
  final VoidCallback onRestoreBottom;

  @override
  State<NanoNavFloatingWindow> createState() => _NanoNavFloatingWindowState();
}

class _NanoNavFloatingWindowState extends State<NanoNavFloatingWindow> {
  double _dragDy = 0.0;

  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() => _dragDy = (_dragDy + details.delta.dy).clamp(0.0, 200.0));
  }

  void _handlePanEnd(DragEndDetails details) {
    final vy = details.velocity.pixelsPerSecond.dy;
    if (_dragDy > 60 || vy > 200) {
      HapticFeedback.mediumImpact();
      widget.onRestoreBottom();
    } else {
      setState(() => _dragDy = 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final top = media.padding.top + 50.0 + (_dragDy * 0.2);
    const left = 14.0;

    final bgColors = isDark
        ? [
            theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
            theme.colorScheme.surface.withValues(alpha: 0.88),
          ]
        : [
            theme.colorScheme.surface.withValues(alpha: 0.94),
            theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.88),
          ];

    return Positioned(
      left: left,
      top: top,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 190),
        curve: Curves.easeOutCubic,
        builder: (context, animValue, childWidget) {
          return Opacity(
            opacity: animValue,
            child: Transform.scale(
              scale: 0.92 + (0.08 * animValue),
              alignment: Alignment.topLeft,
              child: childWidget,
            ),
          );
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: _handlePanUpdate,
          onPanEnd: _handlePanEnd,
          child: Container(
            width: 204,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: bgColors,
                    ),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.16)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 0.85,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      NanoNavFloatingWindowHeader(
                        onRestoreBottom: widget.onRestoreBottom,
                        onCloseMenu: widget.onCloseMenu,
                      ),
                      for (final dest in NanoDestination.values)
                        NanoNavFloatingRow(
                          destination: dest,
                          isSelected: widget.selected == dest,
                          onTap: () => widget.onDestinationSelected(dest),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                        child: Divider(
                          height: 1,
                          thickness: 0.6,
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                      NanoDrawerQuickTile(
                        icon: CupertinoIcons.sparkles,
                        iconColor: const Color(0xFF007AFF),
                        label: 'Chat IA',
                        isDark: isDark,
                        onTap: () {
                          widget.onCloseMenu();
                          AppRouter.router.push('/chat');
                        },
                      ),
                      NanoDrawerQuickTile(
                        icon: CupertinoIcons.compass_fill,
                        iconColor: const Color(0xFFFF9500),
                        label: 'Navegador Web',
                        isDark: isDark,
                        onTap: () {
                          widget.onCloseMenu();
                          AppRouter.router.push('/browser');
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
