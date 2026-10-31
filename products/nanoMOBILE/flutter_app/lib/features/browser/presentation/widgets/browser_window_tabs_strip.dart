import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/browser_tab_model.dart';
import 'browser_site_theme.dart';

/// QUÉ HACE:
/// Tira horizontal de pestañas estilo iOS Safari con pastillas translúcidas,
/// favicons reales y microinteracciones de selección y cierre.
///
/// CÓMO FUNCIONA:
/// Renderiza pastillas de cristal con bordes sutiles, favicon del sitio web
/// y botón de cierre táctil con respuesta háptica. Se oculta si el teclado emerge.
///
/// POR QUÉ:
/// Entrega la experiencia estética 100% iOS Safari sin saturar la pantalla (< 140 líneas).
class BrowserWindowTabsStrip extends StatelessWidget {
  final List<BrowserTabModel> tabs;
  final String activeTabId;
  final ValueChanged<String> onSelectTab, onCloseTab;
  final VoidCallback onAddTab;

  const BrowserWindowTabsStrip({
    super.key,
    required this.tabs,
    required this.activeTabId,
    required this.onSelectTab,
    required this.onCloseTab,
    required this.onAddTab,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xE60D131F) : const Color(0xF2F1F5F9),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
            width: 0.7,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: tabs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final tab = tabs[index];
                final isSelected = tab.id == activeTabId;
                return _buildTabPill(context, tab, isSelected, isDark);
              },
            ),
          ),
          const SizedBox(width: 6),
          _buildAddButton(isDark),
        ],
      ),
    );
  }

  Widget _buildTabPill(
    BuildContext context,
    BrowserTabModel tab,
    bool isSelected,
    bool isDark,
  ) {
    final title = tab.title.trim().isEmpty ? 'Nueva pestaña' : tab.title.trim();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      constraints: const BoxConstraints(minWidth: 110, maxWidth: 170),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? Colors.white.withValues(alpha: 0.14) : Colors.white)
            : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? (isDark ? const Color(0xFF38BDF8).withValues(alpha: 0.7) : const Color(0xFF007AFF).withValues(alpha: 0.4))
              : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
          width: isSelected ? 1.0 : 0.6,
        ),
        boxShadow: isSelected && !isDark
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1.5))]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.selectionClick();
            onSelectTab(tab.id);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                BrowserSiteTheme.buildFavicon(tab.url, size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? (isDark ? Colors.white : const Color(0xFF0F172A))
                          : (isDark ? Colors.white70 : const Color(0xFF475569)),
                    ),
                  ),
                ),
                if (tabs.length > 1) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onCloseTab(tab.id);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        CupertinoIcons.xmark,
                        size: 11,
                        color: isSelected
                            ? (isDark ? Colors.white70 : Colors.black54)
                            : (isDark ? Colors.white38 : Colors.black38),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton(bool isDark) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
          width: 0.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.lightImpact();
            onAddTab();
          },
          child: Icon(
            CupertinoIcons.plus,
            size: 16,
            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF007AFF),
          ),
        ),
      ),
    );
  }
}
