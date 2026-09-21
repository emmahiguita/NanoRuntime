import 'package:flutter/material.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_site_theme.dart';

/// Franja horizontal de pestañas abiertas con favicon y botón de cierre.
/// 
/// - ¿Qué hace?: Muestra la lista de pestañas abiertas en scroll horizontal, indicando la activa
///   con borde azul luminoso, e incluye el botón '+' para abrir nuevas pestañas.
/// - ¿Cómo funciona?: Renderiza un `ListView.separated` donde cada pestaña muestra su favicon
///   vectorial (`BrowserSiteTheme`), título recortado y botón '✕' si hay más de una pestaña.
/// - ¿Por qué?: Separa la gestión visual de pestañas del contenedor principal del navegador (SRP).
class BrowserWindowTabsStrip extends StatelessWidget {
  final List<BrowserTabModel> tabs;
  final String activeTabId;
  final ValueChanged<String> onSelectTab;
  final ValueChanged<String> onCloseTab;
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
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return Container(
      height: isLandscape ? 26 : 36,
      padding: EdgeInsets.symmetric(horizontal: isLandscape ? 6 : 8, vertical: isLandscape ? 1 : 3),
      decoration: const BoxDecoration(
        color: Color(0xFF08121E),
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 1.0)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: tabs.length + 1,
        separatorBuilder: (_, __) => SizedBox(width: isLandscape ? 5 : 8),
        itemBuilder: (context, index) {
          if (index == tabs.length) {
            return Center(
              child: InkWell(
                onTap: onAddTab,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: isLandscape ? 6 : 10, vertical: isLandscape ? 2 : 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Icon(Icons.add_rounded, color: const Color(0xFF94A3B8), size: isLandscape ? 13 : 16),
                ),
              ),
            );
          }

          final tab = tabs[index];
          final isActive = tab.id == activeTabId;

          return Center(
            child: InkWell(
              onTap: () => onSelectTab(tab.id),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(horizontal: isLandscape ? 6 : 10, vertical: isLandscape ? 2 : 5),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive ? const Color(0xFF38BDF8).withValues(alpha: 0.8) : const Color(0xFF334155).withValues(alpha: 0.4),
                    width: isActive ? 1.4 : 1.0,
                  ),
                  boxShadow: isActive
                      ? [BoxShadow(color: const Color(0xFF38BDF8).withValues(alpha: 0.2), blurRadius: 8, spreadRadius: -1)]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BrowserSiteTheme.buildFavicon(
                      tab.url,
                      size: isLandscape ? 14 : 18,
                      isLandscape: isLandscape,
                    ),
                    SizedBox(width: isLandscape ? 5 : 8),
                    Text(
                      tab.title.isNotEmpty ? tab.title : 'Pestaña',
                      style: TextStyle(
                        fontSize: isLandscape ? 10.5 : 12,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                        color: isActive ? Colors.white : const Color(0xFF94A3B8),
                      ),
                    ),
                    if (tabs.length > 1) ...[
                      SizedBox(width: isLandscape ? 4 : 6),
                      GestureDetector(
                        onTap: () => onCloseTab(tab.id),
                        child: Icon(Icons.close_rounded, size: isLandscape ? 11 : 14, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
