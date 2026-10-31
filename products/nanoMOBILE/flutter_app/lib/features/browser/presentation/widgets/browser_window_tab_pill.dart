// QUÉ: Pastilla de pestaña individual estilo iOS Safari para Nano Browser.
// CÓMO: Muestra favicon, título recortado y botón de cierre táctil con respuesta háptica.
// POR QUÉ: Extraído de tabs strip para respetar el límite de 200 líneas y Clean Architecture.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/browser_tab_model.dart';
import 'browser_site_theme.dart';

class BrowserWindowTabPill extends StatelessWidget {
  final BrowserTabModel tab;
  final bool isSelected;
  final bool isDark;
  final bool isLandscape;
  final bool canClose;
  final ValueChanged<String> onSelectTab;
  final ValueChanged<String> onCloseTab;

  const BrowserWindowTabPill({
    super.key,
    required this.tab,
    required this.isSelected,
    required this.isDark,
    required this.isLandscape,
    required this.canClose,
    required this.onSelectTab,
    required this.onCloseTab,
  });

  @override
  Widget build(BuildContext context) {
    final title = tab.title.trim().isEmpty ? 'Nueva pestaña' : tab.title.trim();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      constraints: BoxConstraints(
        minWidth: isLandscape ? 90 : 110,
        maxWidth: isLandscape ? 140 : 170,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? Colors.white.withValues(alpha: 0.14) : Colors.white)
            : (isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.03)),
        borderRadius: BorderRadius.circular(isLandscape ? 8 : 12),
        border: Border.all(
          color: isSelected
              ? (isDark
                  ? const Color(0xFF38BDF8).withValues(alpha: 0.7)
                  : const Color(0xFF007AFF).withValues(alpha: 0.4))
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04)),
          width: isSelected ? 1.0 : 0.6,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(isLandscape ? 8 : 12),
          onTap: () {
            HapticFeedback.selectionClick();
            onSelectTab(tab.id);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                BrowserSiteTheme.buildFavicon(
                  tab.url,
                  size: isLandscape ? 12 : 15,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isLandscape ? 11 : 12.5,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? (isDark ? Colors.white : const Color(0xFF0F172A))
                          : (isDark
                              ? Colors.white70
                              : const Color(0xFF475569)),
                    ),
                  ),
                ),
                if (canClose) ...[
                  const SizedBox(width: 3),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onCloseTab(tab.id);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Icon(
                        CupertinoIcons.xmark,
                        size: isLandscape ? 9 : 11,
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
}
