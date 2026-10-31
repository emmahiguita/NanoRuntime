// QUÉ: Barra de herramientas inferior estilo iOS Safari para Nano Browser.
// CÓMO: Incluye controles de historial, hub de pantallas Nano, escala/escritorio, pestañas y menú.
// POR QUÉ: Permite navegación ergonómica con una sola mano y salto directo a módulos Nano.

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

  Widget _buildButton({
    required IconData icon,
    required VoidCallback? onTap,
    VoidCallback? onLongPress,
    bool isPrimary = false,
    Widget? badge,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
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
            height: 44,
            alignment: Alignment.center,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: onTap == null
                      ? Colors.grey.withValues(alpha: 0.35)
                      : (isPrimary ? const Color(0xFF3B82F6) : null),
                ),
                if (badge != null)
                  Positioned(top: -4, right: -10, child: badge),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xCC0F172A) : const Color(0xCCF8FAFC);
    final border = isDark ? const Color(0x26FFFFFF) : const Color(0x1F000000);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 48,
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
              ),
              _buildButton(
                icon: CupertinoIcons.chevron_right,
                onTap: canGoForward ? onForward : null,
              ),
              _buildButton(
                icon: CupertinoIcons.square_grid_2x2_fill,
                isPrimary: true,
                onTap: () => BrowserScreensHubSheet.show(context),
              ),
              _buildButton(
                icon: isDesktopMode
                    ? CupertinoIcons.desktopcomputer
                    : CupertinoIcons.textformat_size,
                onTap: onOpenZoomSheet,
                onLongPress: onToggleDesktop,
              ),
              _buildButton(
                icon: CupertinoIcons.square_on_square,
                onTap: onToggleTabs,
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
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              _buildButton(
                icon: CupertinoIcons.ellipsis,
                onTap: onOpenOptions,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
