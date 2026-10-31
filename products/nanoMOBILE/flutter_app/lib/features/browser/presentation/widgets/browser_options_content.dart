// QUÉ: Contenido del menú de opciones de Nano Browser estilo iOS Safari nativo y limpio.
// CÓMO: Iconos monocromáticos limpios sin cajas de colores estridentes y tarjetas agrupadas.
// POR QUÉ: Brinda una estética sobria, profesional y coherente con las directrices de Apple (< 175 líneas).

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/browser_tab_model.dart';
import 'browser_options_items.dart';

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

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
          _quickActionsRow(pageGroup, isDark, primary),
          const SizedBox(height: 12),
          _sectionHeader('VISUALIZACIÓN', isDark),
          _group(isDark, primary, displayGroup),
          const SizedBox(height: 12),
          _sectionHeader('NAVEGACIÓN Y PRIVACIDAD', isDark),
          _group(isDark, primary, dataGroup),
        ],
      ),
    );
  }

  /// 4 acciones rápidas superiores estilo Safari iOS sin cajas de colores estridentes.
  Widget _quickActionsRow(List<BrowserOptionItemDef> items, bool isDark, Color primary) => Row(
    children: [
      for (int i = 0; i < items.length; i++) ...[
        Expanded(child: _quickPill(items[i], isDark, primary)),
        if (i < items.length - 1) const SizedBox(width: 8),
      ],
    ],
  );

  Widget _quickPill(BrowserOptionItemDef item, bool isDark, Color primary) {
    final shortLabel = switch (item.action) {
      'toggle_bookmark' => isBookmarked ? 'Guardado' : 'Favorito',
      'find_in_page' => 'Buscar',
      'copy_url' => 'Copiar',
      'show_ssl' => 'Seguridad',
      _ => item.title,
    };
    final iconColor = item.isHighlighted
        ? const Color(0xFFF59E0B)
        : (isDark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF334155));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onAction(item.action);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 21, color: iconColor),
              const SizedBox(height: 5),
              Text(
                shortLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
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

  Widget _group(bool isDark, Color primary, List<BrowserOptionItemDef> items) => Container(
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
          _row(items[i], isDark, primary),
          if (i < items.length - 1)
            Divider(
              height: 1,
              thickness: 0.7,
              indent: 44,
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
            ),
        ],
      ],
    ),
  );

  /// Fila de opción con icono limpio monocromático (sin caja coloreada estridente).
  Widget _row(BrowserOptionItemDef item, bool isDark, Color primary) {
    final iconColor = item.isHighlighted
        ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB))
        : (isDark ? Colors.white.withValues(alpha: 0.75) : const Color(0xFF475569));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onAction(item.action);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Center(
                  child: Icon(item.icon, size: 20, color: iconColor),
                ),
              ),
              const SizedBox(width: 12),
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
}
