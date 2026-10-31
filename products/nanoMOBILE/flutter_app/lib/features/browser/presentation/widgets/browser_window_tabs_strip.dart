// QUÉ: Tira horizontal de pestañas estilo iOS Safari para Nano Browser.
// CÓMO: Coordina lista desplazable de BrowserWindowTabPill y botón de creación de pestañas.
// POR QUÉ: Permite alternar y cerrar pestañas con ergonomía y adaptación compacta en apaisado.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/browser_tab_model.dart';
import 'browser_window_tab_pill.dart';

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final bg = isDark
        ? theme.colorScheme.surface.withValues(alpha: 0.90)
        : theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.92);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.30);

    return Container(
      height: isLandscape ? 32 : 44,
      padding: EdgeInsets.symmetric(
        vertical: isLandscape ? 2 : 4,
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border, width: 0.7)),
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
                return BrowserWindowTabPill(
                  tab: tab,
                  isSelected: tab.id == activeTabId,
                  isDark: isDark,
                  isLandscape: isLandscape,
                  canClose: tabs.length > 1,
                  onSelectTab: onSelectTab,
                  onCloseTab: onCloseTab,
                );
              },
            ),
          ),
          const SizedBox(width: 6),
          _buildAddButton(isDark, isLandscape),
        ],
      ),
    );
  }

  /// QUÉ: Botón circular para añadir nueva pestaña.
  Widget _buildAddButton(bool isDark, bool isLandscape) {
    final size = isLandscape ? 26.0 : 32.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.06),
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
            size: isLandscape ? 13 : 16,
            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF007AFF),
          ),
        ),
      ),
    );
  }
}
