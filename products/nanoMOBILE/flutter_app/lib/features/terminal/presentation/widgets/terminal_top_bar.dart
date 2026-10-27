import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'terminal_session_item.dart';

/// Pestañas reales y acciones secundarias en un menú; sin botones de adorno.
class TerminalTopBar extends StatelessWidget {
  final List<TerminalSessionItem> sessions;
  final int activeIndex;
  final bool isSquareMode;
  final Color chromeColor;
  final Color fgColor;
  final bool isDark;
  final ValueChanged<int> onSelectTab;
  final ValueChanged<int> onCloseTab;
  final VoidCallback onAddTab;
  final VoidCallback onToggleSquare;

  const TerminalTopBar({
    super.key,
    required this.sessions,
    required this.activeIndex,
    required this.isSquareMode,
    required this.chromeColor,
    required this.fgColor,
    required this.isDark,
    required this.onSelectTab,
    required this.onCloseTab,
    required this.onAddTab,
    required this.onToggleSquare,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Atrás',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final tab = sessions[index];
                  final active = index == activeIndex;
                  return InkWell(
                    onTap: () => onSelectTab(index),
                    child: Container(
                      padding: const EdgeInsets.only(left: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: active ? scheme.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tab.name,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: active
                                      ? scheme.onSurface
                                      : scheme.onSurfaceVariant,
                                  fontWeight: active
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                          ),
                          if (sessions.length > 1)
                            IconButton(
                              tooltip: 'Cerrar ${tab.name}',
                              onPressed: () => onCloseTab(tab.id),
                              icon: const Icon(Icons.close_rounded, size: 18),
                            )
                          else
                            const SizedBox(width: 12),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            IconButton(
              tooltip: 'Nueva pestaña',
              onPressed: onAddTab,
              icon: const Icon(Icons.add_rounded),
            ),
            PopupMenuButton<String>(
              tooltip: 'Opciones de vista',
              onSelected: (value) {
                switch (value) {
                  case 'shape':
                    onToggleSquare();
                  case 'center':
                    context.go('/terminal');
                  case 'desktop':
                    context.push('/desktop');
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'shape',
                  child: Text(
                    isSquareMode ? 'Expandir salida' : 'Vista cuadrada',
                  ),
                ),
                const PopupMenuItem(
                  value: 'center',
                  child: Text('Centro de terminales'),
                ),
                const PopupMenuItem(
                  value: 'desktop',
                  child: Text('Visor Linux'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
