import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/browser_tab_model.dart';
import 'browser_options_content.dart';

/// Menú flotante estilo Apple iOS con 100% acabado frosted glass translúcido.
///
/// - QUÉ HACE: Despliega el menú de opciones del navegador como tarjeta flotante de cristal.
/// - CÓMO FUNCIONA: Usa [showGeneralDialog] con filtro de desenfoque de 32px y animación suave.
/// - POR QUÉ: Otorga una estética de menú flotante iOS pura, translúcida y legible (<200 líneas).
class BrowserOptionsSheet extends StatelessWidget {
  final BrowserTabModel tab;
  final bool isBookmarked, isDesktopMode, isDarkModeWeb;
  final ValueChanged<String> onAction;

  const BrowserOptionsSheet({
    super.key,
    required this.tab,
    required this.isBookmarked,
    required this.isDesktopMode,
    required this.isDarkModeWeb,
    required this.onAction,
  });

  static Future<void> show({
    required BuildContext context,
    required BrowserTabModel tab,
    required bool isBookmarked,
    required bool isDesktopMode,
    required bool isDarkModeWeb,
    required ValueChanged<String> onAction,
  }) => showGeneralDialog<void>(
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
        onAction: onAction,
      ),
    ),
    transitionBuilder: (context, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 365,
        constraints: BoxConstraints(maxHeight: screenHeight * 0.74),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
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
                color: isDark ? const Color(0x940D1424) : const Color(0xCCFFFFFF),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.9),
                  width: 1.0,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 14),
                  _buildHeader(context, isDark),
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

  Widget _buildHeader(BuildContext context, bool isDark) {
    final domain = tab.displayHost.isEmpty ? 'Página actual' : tab.displayHost;
    final isSecure = tab.url.startsWith('https://');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF2563EB).withValues(alpha: 0.4), const Color(0xFF38BDF8).withValues(alpha: 0.2)]
                    : [const Color(0xFFDBEAFE), const Color(0xFFEFF6FF)],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF38BDF8).withValues(alpha: 0.4) : const Color(0xFF93C5FD),
              ),
            ),
            child: Icon(
              isSecure ? CupertinoIcons.lock_shield_fill : CupertinoIcons.globe,
              size: 18,
              color: isSecure ? const Color(0xFF38BDF8) : (isDark ? Colors.white70 : Colors.black54),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Opciones del navegador',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  domain,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context, rootNavigator: true).pop();
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.xmark,
                  size: 13,
                  color: isDark ? Colors.white : Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
