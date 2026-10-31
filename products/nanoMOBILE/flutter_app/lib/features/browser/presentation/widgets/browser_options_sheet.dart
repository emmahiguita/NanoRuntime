// QUÉ: Menú flotante estilo Apple iOS con 100% acabado frosted glass translúcido.
// CÓMO: Usa showGeneralDialog con filtro de desenfoque de 32px y composición modular.
// POR QUÉ: Otorga una estética de menú flotante iOS pura, translúcida y legible (< 150 líneas).

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/browser_tab_model.dart';
import 'browser_options_content.dart';
import 'browser_options_header.dart';

class BrowserOptionsSheet extends StatelessWidget {
  final BrowserTabModel tab;
  final bool isBookmarked, isDesktopMode, isDarkModeWeb;
  final String externalAppModeLabel;
  final ValueChanged<String> onAction;

  const BrowserOptionsSheet({
    super.key,
    required this.tab,
    required this.isBookmarked,
    required this.isDesktopMode,
    required this.isDarkModeWeb,
    required this.externalAppModeLabel,
    required this.onAction,
  });

  static Future<void> show({
    required BuildContext context,
    required BrowserTabModel tab,
    required bool isBookmarked,
    required bool isDesktopMode,
    required bool isDarkModeWeb,
    required String externalAppModeLabel,
    required ValueChanged<String> onAction,
  }) =>
      showGeneralDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: true,
        barrierLabel: 'Cerrar opciones',
        barrierColor: Colors.black.withValues(alpha: 0.45),
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, _, __) => Center(
          child: BrowserOptionsSheet(
            tab: tab,
            isBookmarked: isBookmarked,
            isDesktopMode: isDesktopMode,
            isDarkModeWeb: isDarkModeWeb,
            externalAppModeLabel: externalAppModeLabel,
            onAction: onAction,
          ),
        ),
        transitionBuilder: (context, anim, _, child) {
          final curved =
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.93, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      );

  void _trigger(BuildContext context, String action) {
    HapticFeedback.selectionClick();
    Navigator.of(context, rootNavigator: true).pop();
    onAction(action);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    final bg = isDark
        ? theme.colorScheme.surface.withValues(alpha: 0.88)
        : theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.92);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.40);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 365,
        constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
              blurRadius: 36,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: border, width: 0.85),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 14),
                  BrowserOptionsHeader(
                    domain: tab.displayHost.isEmpty
                        ? 'Página actual'
                        : tab.displayHost,
                    isSecure: tab.url.startsWith('https://'),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: BrowserOptionsContent(
                        tab: tab,
                        isBookmarked: isBookmarked,
                        isDesktopMode: isDesktopMode,
                        isDarkModeWeb: isDarkModeWeb,
                        externalAppModeLabel: externalAppModeLabel,
                        onAction: (action) => _trigger(context, action),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
