import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/browser_tab_model.dart';
import 'browser_options_items.dart';

/// QUÉ HACE:
/// Contenido del menú de opciones del navegador agrupado al estilo iOS con tarjetas de cristal.
///
/// CÓMO FUNCIONA:
/// Renderiza secciones agrupadas con insignias de colores Apple, divisores finos y feedback háptico.
///
/// POR QUÉ:
/// Ofrece estética iOS premium fluida y sin desbordamientos (< 140 líneas).
class BrowserOptionsContent extends StatelessWidget {
  final BrowserTabModel tab;
  final bool isBookmarked, isDesktopMode, isDarkModeWeb;
  final String externalAppModeLabel;
  final ValueChanged<String> onAction;

  const BrowserOptionsContent({
    super.key,
    required this.tab,
    required this.isBookmarked,
    required this.isDesktopMode,
    required this.isDarkModeWeb,
    required this.externalAppModeLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pageGroup = BrowserOptionsCatalog.pageItems(
      isBookmarked: isBookmarked,
    );
    final displayGroup = BrowserOptionsCatalog.displayItems(
      tab: tab,
      isDesktopMode: isDesktopMode,
      isDarkModeWeb: isDarkModeWeb,
    );
    final dataGroup = BrowserOptionsCatalog.dataItems(
      externalAppModeLabel: externalAppModeLabel,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader('PÁGINA ACTUAL', isDark),
          _group(isDark, pageGroup),
          const SizedBox(height: 12),
          _sectionHeader('VISUALIZACIÓN', isDark),
          _group(isDark, displayGroup),
          const SizedBox(height: 12),
          _sectionHeader('NAVEGACIÓN Y DATOS', isDark),
          _group(isDark, dataGroup),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, bool isDark) => Padding(
    padding: const EdgeInsets.only(left: 8, bottom: 5, top: 2),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      ),
    ),
  );

  Widget _group(bool isDark, List<BrowserOptionItemDef> items) => Container(
    decoration: BoxDecoration(
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
      ),
    ),
    child: Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _row(items[i], isDark),
          if (i < items.length - 1)
            Divider(
              height: 1,
              thickness: 0.7,
              indent: 48,
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
            ),
        ],
      ],
    ),
  );

  Widget _row(BrowserOptionItemDef item, bool isDark) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onAction(item.action);
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9.5),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [item.color, item.color.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(7),
                boxShadow: [
                  BoxShadow(
                    color: item.color.withValues(alpha: 0.28),
                    blurRadius: 5,
                    offset: const Offset(0, 1.5),
                  ),
                ],
              ),
              child: Icon(item.icon, size: 15, color: Colors.white),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      item.subtitle!,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 13,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ],
        ),
      ),
    ),
  );
}
