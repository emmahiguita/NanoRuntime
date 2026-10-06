import 'package:flutter/material.dart';
import '../../domain/browser_tab_model.dart';
import 'browser_icon_button.dart';

/// Lista horizontal de pestañas: títulos acotados y selección visible.
/// El botón de añadir permanece accesible sin desplazar toda la lista.
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

  /// El teclado tiene prioridad; ocultar esta franja no destruye las WebViews.
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const SizedBox.shrink();
    }
    final colors = Theme.of(context).colorScheme;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return Material(
      color: colors.surface,
      child: SizedBox(
        height: 48 * scale.clamp(1, 2),
        child: Row(
          children: [
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: tabs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 4),
                itemBuilder: (context, index) {
                  final tab = tabs[index];
                  final selected = tab.id == activeTabId;
                  return SizedBox(
                    width: 196,
                    child: Semantics(
                      selected: selected,
                      child: Material(
                        color: selected
                            ? colors.secondaryContainer
                            : colors.surface,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => onSelectTab(tab.id),
                          child: Row(
                            children: [
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  tab.title.isEmpty
                                      ? 'Nueva pestaña'
                                      : tab.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              ),
                              if (tabs.length > 1)
                                BrowserIconButton(
                                  icon: Icons.close_rounded,
                                  label: 'Cerrar ${tab.title}',
                                  onPressed: () => onCloseTab(tab.id),
                                )
                              else
                                const SizedBox(width: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            BrowserIconButton(
              icon: Icons.add_rounded,
              label: 'Nueva pestaña',
              onPressed: onAddTab,
            ),
          ],
        ),
      ),
    );
  }
}
