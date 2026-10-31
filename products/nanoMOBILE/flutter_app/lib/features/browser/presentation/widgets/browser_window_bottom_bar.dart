// QUÉ: Barra de herramientas inferior estilo iOS Safari para Nano Browser.
// CÓMO: Incluye controles de historial, hub de pantallas Nano, escala/escritorio, pestañas y menú.
// POR QUÉ: Permite navegación ergonómica con una sola mano y adaptación compacta en modo horizontal.

import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'browser_screens_hub_sheet.dart';

class BrowserWindowBottomBar extends StatelessWidget {
  final bool canGoBack;
  final bool canGoForward;
  final bool isDesktopMode;
  final int tabCount;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onToggleDesktop;
  final VoidCallback onOpenZoomSheet;
  final VoidCallback onToggleTabs;
  final VoidCallback onOpenOptions;

  const BrowserWindowBottomBar({
    super.key,
    required this.canGoBack,
    required this.canGoForward,
    required this.isDesktopMode,
    required this.tabCount,
    required this.onBack,
    required this.onForward,
    required this.onToggleDesktop,
    required this.onOpenZoomSheet,
    required this.onToggleTabs,
    required this.onOpenOptions,
  });

  /// QUÉ: Botón táctil individual con háptica y badge opcional.
  /// CÓMO: Ajusta altura e icono según la orientación (vertical vs horizontal).
  /// POR QUÉ: Optimiza el espacio vertical en pantallas apaisadas sin perder usabilidad.
  Widget _buildButton({
    required IconData icon,
    required VoidCallback? onTap,
    required bool isLandscape,
    VoidCallback? onLongPress,
    bool isPrimary = false,
    Widget? badge,
  }) {
    final btnHeight = isLandscape ? 34.0 : 44.0;
    final iconSize = isLandscape ? 17.0 : 21.0;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap != null
              ? () {
                  HapticFeedback.lightImpact();
                  onTap();
                }
              : null,
          onLongPress: onLongPress != null
              ? () {
                  HapticFeedback.mediumImpact();
                  onLongPress();
                }
              : null,
          child: Container(
            height: btnHeight,
            alignment: Alignment.center,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  size: iconSize,
                  color: onTap == null
                      ? Colors.grey.withValues(alpha: 0.35)
                      : (isPrimary ? const Color(0xFF3B82F6) : null),
                ),
                if (badge != null)
                  Positioned(top: isLandscape ? -2 : -4, right: -8, child: badge),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final bg = isDark
        ? theme.colorScheme.surface.withValues(alpha: 0.85)
        : theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.88);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.35);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: isLandscape ? 36 : 48,
          decoration: BoxDecoration(
            color: bg,
            border: Border(top: BorderSide(color: border, width: 0.7)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildButton(
                icon: CupertinoIcons.chevron_left,
                onTap: canGoBack ? onBack : null,
                isLandscape: isLandscape,
              ),
              _buildButton(
                icon: CupertinoIcons.chevron_right,
                onTap: canGoForward ? onForward : null,
                isLandscape: isLandscape,
              ),
              _buildButton(
                icon: CupertinoIcons.square_grid_2x2_fill,
                isPrimary: true,
                onTap: () => BrowserScreensHubSheet.show(context),
                isLandscape: isLandscape,
              ),
              _buildButton(
                icon: isDesktopMode
                    ? CupertinoIcons.desktopcomputer
                    : CupertinoIcons.textformat_size,
                onTap: onOpenZoomSheet,
                onLongPress: onToggleDesktop,
                isLandscape: isLandscape,
              ),
              _buildButton(
                icon: CupertinoIcons.square_on_square,
                onTap: onToggleTabs,
                isLandscape: isLandscape,
                badge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$tabCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              _buildButton(
                icon: CupertinoIcons.ellipsis,
                onTap: onOpenOptions,
                isLandscape: isLandscape,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
